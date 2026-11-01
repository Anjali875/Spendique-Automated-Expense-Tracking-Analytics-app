import re
from datetime import date

from pydantic import ValidationError

from app.importers.base import (
    BaseImporter, ParseResult, extract_merchant, parse_amount, parse_date,
)
from app.schemas.transaction import TransactionCreate

AMOUNT_RE = re.compile(r"(?:\brs\.?|\binr|₹)\s*([\d,]+(?:\.\d{1,2})?)", re.I)
DATE_RE = re.compile(r"\b(\d{1,2}[-/ ](?:\d{1,2}|[A-Za-z]{3,9})[-/ ]\d{2,4})\b")
DEBIT_WORDS = ("debited", "spent", "paid", "withdrawn", "purchase", "sent")
CREDIT_WORDS = ("credited", "received", "deposited")

_STOP = r"(?=\s+(?:on|via|ref|upi|using|avl|bal|towards|dated|\d)|[.,(]|$)"
_NOT = r"(?!(?:a/c|ac|account|card|your|vpa)\b)"
_NAME = r"([A-Za-z][\w &.'\-]{1,40}?)"
HANDLE_RE = re.compile(r"\b(?:VPA|from|to)\s+([\w.\-]+)@\w+", re.I)
DEBIT_RES = [re.compile(rf"\b(?:at|to)\s+{_NOT}{_NAME}{_STOP}", re.I)]
CREDIT_RES = [
    re.compile(rf"\bfrom\s+{_NOT}{_NAME}{_STOP}", re.I),
    re.compile(rf"\bby\s+{_NOT}{_NAME}{_STOP}", re.I),
]


def _first(text: str, words) -> int | None:
    hits = [i for w in words if (i := text.find(w)) != -1]
    return min(hits) if hits else None


class SmsParser(BaseImporter):
    def parse(self, content: str) -> ParseResult:
        content = content.strip()
        blocks = re.split(r"\n\s*\n", content)
        if len(blocks) == 1:  # no blank lines: treat each line as one SMS
            blocks = content.splitlines()
        result = ParseResult()
        for block in blocks:
            sms = " ".join(block.split())
            if not sms:
                continue
            txn = self._parse_one(sms)
            if txn:
                result.transactions.append(txn)
            else:
                result.skipped += 1
        return result

    def _parse_one(self, sms: str) -> TransactionCreate | None:
        m = AMOUNT_RE.search(sms)
        if not m:
            return None
        amount = parse_amount(m.group(1))
        low = sms.lower()
        d_idx, c_idx = _first(low, DEBIT_WORDS), _first(low, CREDIT_WORDS)
        if not amount or (d_idx is None and c_idx is None):
            return None  # OTPs, promos, balance alerts
        is_debit = c_idx is None or (d_idx is not None and d_idx < c_idx)

        merchant = None
        h = HANDLE_RE.search(sms)
        if h:
            merchant = h.group(1)
        else:
            for rx in (DEBIT_RES if is_debit else CREDIT_RES):
                mm = rx.search(sms)
                if mm:
                    merchant = mm.group(1)
                    break
        dm = DATE_RE.search(sms)
        txn_date = (parse_date(dm.group(1)) if dm else None) or date.today()
        try:
            return TransactionCreate(
                amount=amount,
                type="debit" if is_debit else "credit",
                merchant=extract_merchant(merchant) if merchant else "Unknown",
                description=sms[:500],
                txn_date=txn_date,
            )
        except ValidationError:
            return None