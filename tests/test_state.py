from datetime import date
from decimal import Decimal

from assetpulse.models import Transaction
from assetpulse.state import ProcessedStore, dedup_key


def tx(source_id="", merchant="星巴克"):
    return Transaction(
        date=date(2026, 6, 3),
        amount=Decimal("1280"),
        merchant=merchant,
        source_id=source_id,
    )


def test_dedup_key_prefers_source_id():
    assert dedup_key(tx(source_id="msg_a1")) == "msg_a1"


def test_dedup_key_falls_back_to_composite():
    key = dedup_key(tx(source_id=""))
    assert key == "2026-06-03|1280|星巴克"


def test_filter_new_excludes_seen(tmp_path):
    store = ProcessedStore(tmp_path / "processed.json")
    t1, t2 = tx("msg_a1"), tx("msg_a2", merchant="Netflix")
    store.mark(t1)
    new = store.filter_new([t1, t2])
    assert new == [t2]


def test_state_persists_across_instances(tmp_path):
    path = tmp_path / "processed.json"
    store = ProcessedStore(path)
    store.mark(tx("msg_a1"))
    store.save()

    reloaded = ProcessedStore(path)
    assert reloaded.is_seen(tx("msg_a1"))
    assert not reloaded.is_seen(tx("msg_a2", merchant="Netflix"))
