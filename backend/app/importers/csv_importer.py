import csv
import io
import re

from pydantic import ValidationError

from app.importers.base import (
    BaseImporter, ParseResult, extract_merchant, parse_amount, parse_date,
)
from app.schemas.transaction import TransactionCreate

ALIASES = {
    "date": {"date", "txn date", "transaction date", "tran date", "value date", "posting date"},
    "desc": {"description", "narration", "particulars", "details", "transaction remarks",
             "remarks", "transaction details"},
    "debit": {"debit", "withdrawal", "withdrawal amt", "debit amount", "withdrawals", "dr"},
    "credit": {"credit", "deposit", "deposit amt", "credit amount", "deposits", "cr"},
    "amount": {"amount", "transaction amount", "amt"},
    "type": {"type", "dr/cr", "cr/dr", "transaction type"},
}


def _norm(h: str) -> str:
    return re.sub(r"\s+", " ", h.replace(".", "").strip().lower())


def _find_header(rows):
    for i, row in enumerate(rows[:30]):  # many banks put junk above the header
        cols = {}
        for j, cell in enumerate(row):
            for key, names in ALIASES.items():
                if _norm(cell) in names and key not in cols:
                    cols[key] = j
        if "date" in cols and "desc" in cols and ({"amount", "debit", "credit"} & cols.keys()):
            return i, cols
    raise ValueError(
        "Couldn't find a header row. Need columns for date, description/narration, and amount or debit/credit."
    )


def _get(row, cols, key):
    i = cols.get(key)
    return row[i].strip() if i is not None and i < len(row) else ""


def _row_to_txn(row, cols):
    d = parse_date(_get(row, cols, "date"))
    if not d:
        return None
    debit = parse_amount(_get(row, cols, "debit")) if "debit" in cols else None
    credit = parse_amount(_get(row, cols, "credit")) if "credit" in cols else None
    amount = type_ = None
    if debit and debit > 0:
        amount, type_ = debit, "debit"
    elif credit and credit > 0:
        amount, type_ = credit, "credit"
    elif "amount" in cols:
        amt = parse_amount(_get(row, cols, "amount"))
        if amt:
            kind = _get(row, cols, "type").lower()
            if kind.startswith(("d", "w")):
                type_ = "debit"
            elif kind.startswith("c"):
                type_ = "credit"
            else:  # no type column: negative = money out
                type_ = "debit" if amt < 0 else "credit"
            amount = abs(amt)
    if not amount:
        return None
    desc = _get(row, cols, "desc")
    try:
        return TransactionCreate(
            amount=amount,
            type=type_,
            merchant=extract_merchant(desc),
            description=desc[:500] or None,
            txn_date=d,
        )
    except ValidationError:
        return None


class CsvImporter(BaseImporter):
    def parse(self, content: bytes) -> ParseResult:
        text = content.decode("utf-8-sig", errors="replace")
        rows = list(csv.reader(io.StringIO(text)))
        header_idx, cols = _find_header(rows)
        result = ParseResult()
        for row in rows[header_idx + 1:]:
            if not any(c.strip() for c in row):
                continue
            txn = _row_to_txn(row, cols)
            if txn:
                result.transactions.append(txn)
            else:
                result.skipped += 1
        return result