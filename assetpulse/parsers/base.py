"""解析器共用工具與 PDF 文字抽取。"""

from __future__ import annotations

import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

# 金額：優先抓「消費/金額/NT$」等關鍵字後面的數字，避免把卡號末四碼、
# 日期等其他數字誤認成金額；找不到關鍵字才退回抓第一個數字。
_NUM = r"([0-9][0-9,]*(?:\.[0-9]+)?)"
_AMOUNT_KEYWORD_RE = re.compile(
    rf"(?:消費金額|消費|金額|總計|合計|NT\$|TWD)[:：]?\s*(?:NT\$|\$)?\s*{_NUM}"
)
_AMOUNT_FALLBACK_RE = re.compile(rf"(?:NT\$|\$)?\s*{_NUM}")

# 日期：支援 2026/06/18、2026-06-18、2026.06.18、115/06/18（民國年）
_DATE_RE = re.compile(r"(\d{2,4})[/\-.](\d{1,2})[/\-.](\d{1,2})")


def parse_amount(text: str) -> Decimal | None:
    m = _AMOUNT_KEYWORD_RE.search(text) or _AMOUNT_FALLBACK_RE.search(text)
    if not m:
        return None
    try:
        return Decimal(m.group(1).replace(",", ""))
    except InvalidOperation:
        return None


def parse_date(text: str) -> date | None:
    m = _DATE_RE.search(text)
    if not m:
        return None
    year, month, day = (int(g) for g in m.groups())
    if year < 1911:  # 民國年轉西元
        year += 1911
    try:
        return datetime(year, month, day).date()
    except ValueError:
        return None


def extract_pdf_text(pdf_bytes: bytes) -> str:
    """抽取 PDF 文字；沒裝 pdfplumber 就回空字串，不讓整個流程崩潰。"""
    try:
        import io

        import pdfplumber
    except ImportError:
        return ""

    chunks: list[str] = []
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            chunks.append(page.extract_text() or "")
    return "\n".join(chunks)
