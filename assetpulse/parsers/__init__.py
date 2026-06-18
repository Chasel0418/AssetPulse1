"""解析器：把一封 email 轉成 Transaction 或 Invoice。

各家銀行／電商的信件格式都不同，所以解析器設計成可插拔。
內建一組以台灣常見刷卡通知／電子發票為對象的通用正則解析器，
你可以照著 base.py 的介面，為你的銀行新增專屬解析器再註冊到 registry。
"""

from .registry import get_invoice_parser, get_statement_parser, register

__all__ = ["get_invoice_parser", "get_statement_parser", "register"]
