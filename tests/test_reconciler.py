from datetime import date
from decimal import Decimal

from assetpulse.models import Invoice, Transaction
from assetpulse.reconciler import (
    ReconcileConfig,
    merchant_similarity,
    reconcile,
    summarize,
)


def tx(d, amt, m, last4="1234"):
    return Transaction(date=date.fromisoformat(d), amount=Decimal(str(amt)), merchant=m, card_last4=last4)


def inv(d, amt, s, no="AB00000000"):
    return Invoice(date=date.fromisoformat(d), amount=Decimal(str(amt)), seller=s, invoice_number=no)


def test_exact_match_same_day():
    txs = [tx("2026-06-03", 1280, "星巴克")]
    invs = [inv("2026-06-03", 1280, "統一星巴克股份有限公司")]
    results = reconcile(txs, invs)
    assert results[0].status == "matched"
    assert results[0].invoice is invs[0]


def test_match_within_date_window():
    txs = [tx("2026-06-15", 88, "7-ELEVEN")]
    invs = [inv("2026-06-16", 88, "7-ELEVEN")]
    results = reconcile(txs, invs)
    assert results[0].status == "matched"


def test_unmatched_when_no_invoice():
    txs = [tx("2026-06-18", 12000, "蝦皮購物")]
    results = reconcile(txs, [])
    assert results[0].status == "unmatched"
    assert results[0].invoice is None


def test_date_outside_window_is_unmatched():
    txs = [tx("2026-06-01", 500, "店家")]
    invs = [inv("2026-06-20", 500, "店家")]
    results = reconcile(txs, invs, ReconcileConfig(date_window_days=5))
    assert results[0].status == "unmatched"


def test_amount_must_match():
    txs = [tx("2026-06-03", 1280, "星巴克")]
    invs = [inv("2026-06-03", 1281, "星巴克")]
    results = reconcile(txs, invs)
    assert results[0].status == "unmatched"


def test_amount_tolerance():
    txs = [tx("2026-06-03", 1280, "星巴克")]
    invs = [inv("2026-06-03", 1281, "星巴克")]
    results = reconcile(txs, invs, ReconcileConfig(amount_tolerance=Decimal("1")))
    assert results[0].status == "matched"


def test_each_invoice_used_once():
    txs = [tx("2026-06-03", 100, "A 店"), tx("2026-06-03", 100, "A 店")]
    invs = [inv("2026-06-03", 100, "A 店")]
    results = reconcile(txs, invs)
    statuses = sorted(r.status for r in results)
    assert statuses == ["matched", "unmatched"]


def test_summary():
    txs = [tx("2026-06-03", 1280, "星巴克"), tx("2026-06-18", 12000, "蝦皮")]
    invs = [inv("2026-06-03", 1280, "統一星巴克股份有限公司")]
    results = reconcile(txs, invs)
    s = summarize(results)
    assert s["transactions"] == 2
    assert s["total_amount"] == Decimal("13280")
    assert s["matched_amount"] == Decimal("1280")


def test_merchant_similarity_ignores_company_suffix():
    assert merchant_similarity("星巴克", "星巴克股份有限公司") > 0.6
