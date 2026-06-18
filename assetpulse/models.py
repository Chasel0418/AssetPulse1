"""核心資料模型：信用卡交易、發票、核銷結果。

金額一律用 Decimal 保存，避免浮點誤差影響金額比對。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal


@dataclass
class Transaction:
    """一筆信用卡消費。"""

    date: date
    amount: Decimal
    merchant: str
    card_last4: str | None = None
    currency: str = "TWD"
    source_id: str = ""  # 來源 Gmail message id，方便回溯
    raw: str = ""

    def key(self) -> str:
        return f"{self.date.isoformat()}|{self.amount}|{self.merchant}"


@dataclass
class Invoice:
    """一張發票（電子發票或 email 帳單）。"""

    date: date
    amount: Decimal
    seller: str
    invoice_number: str | None = None
    currency: str = "TWD"
    source_id: str = ""
    raw: str = ""


@dataclass
class MatchResult:
    """一筆交易的核銷結果。

    status:
        matched    — 找到唯一相符的發票
        ambiguous  — 有多張候選發票，需人工確認
        unmatched  — 找不到對應發票
    """

    transaction: Transaction
    invoice: Invoice | None = None
    score: float = 0.0
    status: str = "unmatched"
    candidates: list[Invoice] = field(default_factory=list)
