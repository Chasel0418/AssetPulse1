"""解析器共用工具與 PDF 文字抽取。"""

from __future__ import annotations

import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

# 金額：抓 1,234 或 1234.56，允許 NT$ / $ 前綴
_AMOUNT_RE = re.compile(r"(?:NT\$|\$)?\s*([0-9][0-9,]*(?:\.[0-9]+)?)")

# 日期：支援 2026/06/18、2026-06-18、2026.06.18、115/06/18（民國年）
_DATE_RE = re.compile(r"(\d{2,4})[/\-.](\d{1,2})[/\-.](\d{1,2})")


def parse_amount(text: str) -> Decimal | None:
    m = _AMOUNT_RE.search(text)
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
