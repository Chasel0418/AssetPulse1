"""把各環節串起來：抓信 → 解析 → 核銷。"""

from __future__ import annotations

from .config import AppConfig
from .gmail_client import GmailClient
from .models import Invoice, MatchResult, Transaction
from .parsers import get_invoice_parser, get_statement_parser
from .reconciler import ReconcileConfig, reconcile


def collect(config: AppConfig, gmail: GmailClient) -> tuple[list[Transaction], list[Invoice]]:
    """依設定的來源規則抓信並解析成交易與發票。"""
    transactions: list[Transaction] = []
    invoices: list[Invoice] = []

    for rule in config.sources:
        messages = gmail.search(rule.query)
        if rule.type == "statement":
            parser = get_statement_parser(rule.parser)
            for msg in messages:
                transactions.extend(parser(msg))
        elif rule.type == "invoice":
            parser = get_invoice_parser(rule.parser)
            for msg in messages:
                invoices.extend(parser(msg))

    return transactions, invoices


def run_reconcile(
    config: AppConfig,
    transactions: list[Transaction],
    invoices: list[Invoice],
) -> list[MatchResult]:
    rc = ReconcileConfig(
        date_window_days=config.date_window_days,
        amount_tolerance=config.amount_tolerance,
        merchant_match_threshold=config.merchant_match_threshold,
    )
    return reconcile(transactions, invoices, rc)
