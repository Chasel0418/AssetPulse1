from decimal import Decimal

from assetpulse.gmail_client import EmailMessage
from assetpulse.parsers.base import parse_amount, parse_date
from assetpulse.parsers.generic import parse_invoice, parse_statement


def test_amount_prefers_keyword_over_first_number():
    # 回歸：末四碼出現在金額前面時，不能把末四碼當成金額
    text = "您的信用卡(末四碼1234)於 2026/07/05 消費 NT$ 2,350，商店：家樂福"
    assert parse_amount(text) == Decimal("2350")


def test_amount_keyword_variants():
    assert parse_amount("金額 2,350 元") == Decimal("2350")
    assert parse_amount("消費金額：599") == Decimal("599")
    assert parse_amount("總計 NT$ 1,280") == Decimal("1280")


def test_amount_fallback_without_keyword():
    assert parse_amount("NT$ 88") == Decimal("88")


def test_parse_date_western_and_roc():
    assert str(parse_date("2026/07/05")) == "2026-07-05"
    assert str(parse_date("115/07/05")) == "2026-07-05"  # 民國年


def test_parse_statement_full_email():
    msg = EmailMessage(
        id="m1",
        subject="信用卡消費彙總通知",
        sender="ecard@cathaybk.com.tw",
        body_text="您的信用卡(末四碼1234)於 2026/07/05 消費 NT$ 2,350，商店：家樂福 敬請核對。",
    )
    txs = parse_statement(msg)
    assert len(txs) == 1
    t = txs[0]
    assert t.amount == Decimal("2350")
    assert t.card_last4 == "1234"
    assert t.merchant == "家樂福"
    assert str(t.date) == "2026-07-05"


def test_parse_invoice_full_email():
    msg = EmailMessage(
        id="m2",
        subject="電子發票開立通知",
        sender="invoice@books.com.tw",
        body_text="發票號碼：AB12345678 開立日期：2026/07/05 金額 2,350 元 賣方：家福股份有限公司",
    )
    invs = parse_invoice(msg)
    assert len(invs) == 1
    i = invs[0]
    assert i.amount == Decimal("2350")
    assert i.invoice_number == "AB12345678"
    assert "家福" in i.seller
    assert str(i.date) == "2026-07-05"
