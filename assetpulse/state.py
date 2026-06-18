"""處理狀態：記住已成功匯入的交易，避免下個月重複匯入。

把已寫入 Notion 的交易識別碼（預設用來源 Gmail message id）存成本地
JSON 檔。檔案放在 data/ 之下，已被 .gitignore 排除，不會進版控。

只有「真正成功寫進 Notion」之後才呼叫 mark + save，所以純預覽
（不加 --notion）的執行不會把交易標成已處理，下次仍看得到。
"""

from __future__ import annotations

import json
from pathlib import Path

from .models import Transaction


def dedup_key(tx: Transaction) -> str:
    """交易的去重鍵：優先用來源 Gmail id，沒有就退回 日期|金額|商家。"""
    return tx.source_id or tx.key()


class ProcessedStore:
    def __init__(self, path: str | Path = "data/processed.json"):
        self.path = Path(path)
        self._seen: set[str] = set()
        self._load()

    def _load(self) -> None:
        if self.path.exists():
            data = json.loads(self.path.read_text(encoding="utf-8"))
            self._seen = set(data.get("processed", []))

    def is_seen(self, tx: Transaction) -> bool:
        return dedup_key(tx) in self._seen

    def mark(self, tx: Transaction) -> None:
        self._seen.add(dedup_key(tx))

    def filter_new(self, transactions: list[Transaction]) -> list[Transaction]:
        """回傳尚未處理過的交易。"""
        return [tx for tx in transactions if not self.is_seen(tx)]

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps({"processed": sorted(self._seen)}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
