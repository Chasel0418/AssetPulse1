"""解析器註冊表：用名稱取得對應的解析函式。

新增銀行專屬解析器時，寫好函式後在這裡 register() 即可，
config.yaml 的 source.parser 就能指到它。
"""

from __future__ import annotations

from collections.abc import Callable

from ..gmail_client import EmailMessage
from ..models import Invoice, Transaction
from . import generic

StatementParser = Callable[[EmailMessage], list[Transaction]]
InvoiceParser = Callable[[EmailMessage], list[Invoice]]

_STATEMENT_PARSERS: dict[str, StatementParser] = {
    "generic": generic.parse_statement,
}
_INVOICE_PARSERS: dict[str, InvoiceParser] = {
    "generic": generic.parse_invoice,
}


def register(name: str, *, statement: StatementParser | None = None,
             invoice: InvoiceParser | None = None) -> None:
    if statement:
        _STATEMENT_PARSERS[name] = statement
    if invoice:
        _INVOICE_PARSERS[name] = invoice


def get_statement_parser(name: str) -> StatementParser:
    return _STATEMENT_PARSERS.get(name, generic.parse_statement)


def get_invoice_parser(name: str) -> InvoiceParser:
    return _INVOICE_PARSERS.get(name, generic.parse_invoice)
