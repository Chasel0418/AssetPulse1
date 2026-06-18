"""核銷引擎：把信用卡交易和發票配對。

配對邏輯（信用卡入帳日 ≠ 發票開立日，所以用區間 + 模糊比對）：
  1. 金額必須在容許誤差內（預設完全相同）。
  2. 日期差距在 date_window_days 天內（預設 ±5 天）。
  3. 商家／賣方名稱相似度當作排序分數。

只用標準函式庫，不依賴外部套件，方便在任何環境直接測試。
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal
from difflib import SequenceMatcher

from .models import Invoice, MatchResult, Transaction


@dataclass
class ReconcileConfig:
    date_window_days: int = 5
    amount_tolerance: Decimal = Decimal("0")
    # 商家相似度高於此值才視為唯一相符，否則標為 ambiguous 交人工確認
    merchant_match_threshold: float = 0.6


def _normalize(name: str) -> str:
    """正規化商家名稱：去空白、轉小寫、移除常見公司後綴雜訊。"""
    noise = ("股份有限公司", "有限公司", "company", "co.", "ltd", "inc", "co", "股份")
    s = name.lower().strip()
    for token in noise:
        s = s.replace(token, "")
    return "".join(s.split())


def merchant_similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, _normalize(a), _normalize(b)).ratio()


def _amount_matches(tx_amount: Decimal, inv_amount: Decimal, tol: Decimal) -> bool:
    return abs(tx_amount - inv_amount) <= tol


def reconcile(
    transactions: list[Transaction],
    invoices: list[Invoice],
    config: ReconcileConfig | None = None,
) -> list[MatchResult]:
    """回傳每筆交易的核銷結果。每張發票最多被配對一次。"""
    cfg = config or ReconcileConfig()
    results: list[MatchResult] = []
    used: set[int] = set()  # 已被配走的發票 index

    for tx in transactions:
        candidates: list[tuple[float, int, Invoice]] = []
        for idx, inv in enumerate(invoices):
            if idx in used:
                continue
            if not _amount_matches(tx.amount, inv.amount, cfg.amount_tolerance):
                continue
            if abs((tx.date - inv.date).days) > cfg.date_window_days:
                continue
            score = merchant_similarity(tx.merchant, inv.seller)
            candidates.append((score, idx, inv))

        candidates.sort(key=lambda c: c[0], reverse=True)
        result = _resolve(tx, candidates, cfg)
        if result.status == "matched":
            # 找出剛被配走的發票 index 並標記為已用
            best_idx = candidates[0][1]
            used.add(best_idx)
        results.append(result)

    return results


def _resolve(
    tx: Transaction,
    candidates: list[tuple[float, int, Invoice]],
    cfg: ReconcileConfig,
) -> MatchResult:
    if not candidates:
        return MatchResult(transaction=tx, status="unmatched")

    best_score, _, best_inv = candidates[0]
    candidate_invoices = [c[2] for c in candidates]

    # 唯一一張候選且相似度夠 → matched
    strong = best_score >= cfg.merchant_match_threshold
    if len(candidates) == 1 and strong:
        return MatchResult(tx, best_inv, best_score, "matched", candidate_invoices)

    # 多張候選，但最佳明顯勝出（第二名差距 > 0.15）→ matched
    if strong and (len(candidates) == 1 or best_score - candidates[1][0] > 0.15):
        return MatchResult(tx, best_inv, best_score, "matched", candidate_invoices)

    return MatchResult(tx, None, best_score, "ambiguous", candidate_invoices)


def summarize(results: list[MatchResult]) -> dict[str, object]:
    """產生月結摘要：總筆數、總金額、各狀態統計。"""
    total_amount = sum((r.transaction.amount for r in results), Decimal("0"))
    by_status: dict[str, int] = {}
    for r in results:
        by_status[r.status] = by_status.get(r.status, 0) + 1
    matched_amount = sum(
        (r.transaction.amount for r in results if r.status == "matched"),
        Decimal("0"),
    )
    return {
        "transactions": len(results),
        "total_amount": total_amount,
        "matched_amount": matched_amount,
        "unmatched_amount": total_amount - matched_amount,
        "by_status": by_status,
    }
