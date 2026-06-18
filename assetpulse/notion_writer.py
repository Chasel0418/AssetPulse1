"""把核銷結果寫進 Notion Database。

Database 需要先在 Notion 建好，並把你的 integration 分享給該 Database。
建議的 Database 欄位（屬性）：
    日期      Date
    商家      Title
    金額      Number
    末四碼    Rich text
    狀態      Select（matched / ambiguous / unmatched）
    發票號碼  Rich text
    發票賣方  Rich text
"""

from __future__ import annotations

from .models import MatchResult


class NotionWriter:
    def __init__(self, token: str, database_id: str):
        from notion_client import Client

        self.client = Client(auth=token)
        self.database_id = database_id

    def write(self, result: MatchResult) -> None:
        self.client.pages.create(
            parent={"database_id": self.database_id},
            properties=self._to_properties(result),
        )

    def write_all(self, results: list[MatchResult]) -> int:
        for r in results:
            self.write(r)
        return len(results)

    def _to_properties(self, r: MatchResult) -> dict:
        tx = r.transaction
        inv = r.invoice
        return {
            "商家": {"title": [{"text": {"content": tx.merchant}}]},
            "日期": {"date": {"start": tx.date.isoformat()}},
            "金額": {"number": float(tx.amount)},
            "末四碼": _rich(tx.card_last4 or ""),
            "狀態": {"select": {"name": r.status}},
            "發票號碼": _rich(inv.invoice_number if inv and inv.invoice_number else ""),
            "發票賣方": _rich(inv.seller if inv else ""),
        }


def _rich(text: str) -> dict:
    return {"rich_text": [{"text": {"content": text}}] if text else []}
