"""設定載入：合併 YAML 設定檔與環境變數（.env）。

機密資訊（Notion token 等）走環境變數；非機密的查詢規則走 YAML。
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from decimal import Decimal
from pathlib import Path

import yaml


@dataclass
class SourceRule:
    """一條 Gmail 抓取規則。

    name:  好記的名稱（例如「國泰世華刷卡通知」）。
    query: Gmail 搜尋語法，例如 'from:ecard@cathaybk.com.tw newer_than:35d'。
    type:  statement（信用卡交易）或 invoice（發票）。
    parser: 對應的解析器名稱（見 parsers/registry）。
    """

    name: str
    query: str
    type: str
    parser: str = "generic"


@dataclass
class AppConfig:
    sources: list[SourceRule] = field(default_factory=list)
    date_window_days: int = 5
    amount_tolerance: Decimal = Decimal("0")
    merchant_match_threshold: float = 0.6
    notion_database_id: str = ""
    notion_token: str = ""
    gmail_credentials_path: str = "credentials.json"
    gmail_token_path: str = "token.json"

    @classmethod
    def load(cls, path: str | Path = "config.yaml") -> "AppConfig":
        from dotenv import load_dotenv

        load_dotenv()

        data: dict = {}
        p = Path(path)
        if p.exists():
            data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}

        sources = [SourceRule(**s) for s in data.get("sources", [])]
        rc = data.get("reconcile", {})

        return cls(
            sources=sources,
            date_window_days=int(rc.get("date_window_days", 5)),
            amount_tolerance=Decimal(str(rc.get("amount_tolerance", "0"))),
            merchant_match_threshold=float(rc.get("merchant_match_threshold", 0.6)),
            notion_database_id=os.getenv("NOTION_DATABASE_ID", data.get("notion_database_id", "")),
            notion_token=os.getenv("NOTION_TOKEN", ""),
            gmail_credentials_path=data.get("gmail_credentials_path", "credentials.json"),
            gmail_token_path=data.get("gmail_token_path", "token.json"),
        )
