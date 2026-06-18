"""通用解析器：以台灣常見「刷卡通知」與「電子發票」信件為對象。

這是「能跑起來的起點」，不是萬靈丹。各家銀行格式不同，
真實使用時請拿你自己的信件樣本，調整下面的正則或新增專屬解析器。
"""

from __future__ import annotations

import re

from ..gmail_client import EmailMessage
from ..models import Invoice, Transaction
from .base import extract_pdf_text, parse_amount, parse_date

# 刷卡通知常見句型，例如：「您的信用卡(末四碼1234)於 2026/06/18 消費 1,280 元，商店：星巴克」
_LAST4_RE = re.compile(r"末四碼[:：]?\s*(\d{4})|\*{2,}(\d{4})")
_MERCHANT_RE = re.compile(r"(?:商店|商家|特店|消費地點)[:：]?\s*(.+?)(?:\s|，|,|。|$)")
_SELLER_RE = re.compile(r"(?:賣方|開立單位|商店名稱|店家)[:：]?\s*(.+?)(?:\s|，|,|。|$)")
_INVOICE_NO_RE = re.compile(r"發票號碼[:：]?\s*([A-Z]{2}\d{8})")


def _full_text(msg: EmailMessage) -> str:
    parts = [msg.subject, msg.body_text]
    for pdf in msg.pdf_attachments:
        parts.append(extract_pdf_text(pdf))
    return "\n".join(p for p in parts if p)


def parse_statement(msg: EmailMessage) -> list[Transaction]:
    text = _full_text(msg)
    d = parse_date(text)
    amount = parse_amount(text)
    if d is None or amount is None:
        return []

    last4 = None
    m = _LAST4_RE.search(text)
    if m:
        last4 = m.group(1) or m.group(2)

    merchant = "(未知商家)"
    mm = _MERCHANT_RE.search(text)
    if mm:
        merchant = mm.group(1).strip()

    return [
        Transaction(
            date=d,
            amount=amount,
            merchant=merchant,
            card_last4=last4,
            source_id=msg.id,
            raw=text[:500],
        )
    ]


def parse_invoice(msg: EmailMessage) -> list[Invoice]:
    text = _full_text(msg)
    d = parse_date(text)
    amount = parse_amount(text)
    if d is None or amount is None:
        return []

    seller = "(未知賣方)"
    sm = _SELLER_RE.search(text)
    if sm:
        seller = sm.group(1).strip()
    elif msg.sender:
        seller = msg.sender

    invoice_no = None
    nm = _INVOICE_NO_RE.search(text)
    if nm:
        invoice_no = nm.group(1)

    return [
        Invoice(
            date=d,
            amount=amount,
            seller=seller,
            invoice_number=invoice_no,
            source_id=msg.id,
            raw=text[:500],
        )
    ]
