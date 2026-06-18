"""命令列入口。

用法：
    python -m assetpulse auth                授權 Gmail（第一次使用）
    python -m assetpulse run                 抓信 → 核銷 → 印出結果（不寫 Notion）
    python -m assetpulse run --notion        同上，並寫進 Notion
    python -m assetpulse run --sample        用 samples/ 假資料跑通整條流程（免憑證）
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from decimal import Decimal
from pathlib import Path

from .config import AppConfig
from .models import Invoice, MatchResult, Transaction
from .pipeline import collect, run_reconcile
from .reconciler import summarize


def _load_sample() -> tuple[list[Transaction], list[Invoice]]:
    base = Path(__file__).resolve().parent.parent / "samples" / "fixtures"
    txs = [
        Transaction(
            date=date.fromisoformat(t["date"]),
            amount=Decimal(str(t["amount"])),
            merchant=t["merchant"],
            card_last4=t.get("card_last4"),
            source_id=t.get("source_id", ""),
        )
        for t in json.loads((base / "transactions.json").read_text("utf-8"))
    ]
    invs = [
        Invoice(
            date=date.fromisoformat(i["date"]),
            amount=Decimal(str(i["amount"])),
            seller=i["seller"],
            invoice_number=i.get("invoice_number"),
            source_id=i.get("source_id", ""),
        )
        for i in json.loads((base / "invoices.json").read_text("utf-8"))
    ]
    return txs, invs


def _print_results(results: list[MatchResult]) -> None:
    icon = {"matched": "✅", "ambiguous": "⚠️ ", "unmatched": "❌"}
    print(f"\n{'狀態':<6}{'日期':<12}{'金額':>10}  商家 → 發票")
    print("-" * 64)
    for r in results:
        tx = r.transaction
        inv = f"{r.invoice.seller}" if r.invoice else "—"
        print(
            f"{icon.get(r.status, '?')}  {tx.date.isoformat():<12}"
            f"{str(tx.amount):>10}  {tx.merchant} → {inv}"
        )

    s = summarize(results)
    print("-" * 64)
    print(
        f"共 {s['transactions']} 筆，總額 {s['total_amount']}，"
        f"已核銷 {s['matched_amount']}，未核銷 {s['unmatched_amount']}"
    )
    print(f"狀態統計：{s['by_status']}")


def cmd_auth(config: AppConfig) -> int:
    from .gmail_client import GmailClient

    gmail = GmailClient(config.gmail_credentials_path, config.gmail_token_path)
    gmail.authorize()
    print("✅ Gmail 授權完成，token 已存檔。")
    return 0


def cmd_run(config: AppConfig, args: argparse.Namespace) -> int:
    from .state import ProcessedStore

    if args.sample:
        transactions, invoices = _load_sample()
    else:
        from .gmail_client import GmailClient

        gmail = GmailClient(config.gmail_credentials_path, config.gmail_token_path)
        transactions, invoices = collect(config, gmail)

    print(f"抓到 {len(transactions)} 筆交易、{len(invoices)} 張發票。")

    store = ProcessedStore(config.state_path)
    if not args.ignore_state:
        before = len(transactions)
        transactions = store.filter_new(transactions)
        skipped = before - len(transactions)
        if skipped:
            print(f"跳過 {skipped} 筆先前已匯入的交易（防重複）。")

    if not transactions:
        print("沒有新的交易需要處理。")
        return 0

    results = run_reconcile(config, transactions, invoices)
    _print_results(results)

    if args.notion:
        if not (config.notion_token and config.notion_database_id):
            print("\n⚠️  未設定 NOTION_TOKEN / NOTION_DATABASE_ID，略過寫入 Notion。")
            return 1
        from .notion_writer import NotionWriter

        writer = NotionWriter(config.notion_token, config.notion_database_id)
        count = writer.write_all(results)
        for r in results:
            store.mark(r.transaction)
        store.save()
        print(f"\n✅ 已寫入 Notion {count} 筆，並記錄為已處理。")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="assetpulse", description="信用卡花費整理與發票核銷")
    parser.add_argument("--config", default="config.yaml", help="設定檔路徑")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("auth", help="授權 Gmail")

    run_p = sub.add_parser("run", help="抓信、核銷、輸出")
    run_p.add_argument("--sample", action="store_true", help="用假資料跑（免憑證）")
    run_p.add_argument("--notion", action="store_true", help="把結果寫進 Notion")
    run_p.add_argument(
        "--ignore-state", action="store_true", help="忽略防重複紀錄，重新處理所有交易"
    )

    args = parser.parse_args(argv)
    config = AppConfig.load(args.config)

    if args.command == "auth":
        return cmd_auth(config)
    if args.command == "run":
        return cmd_run(config, args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
