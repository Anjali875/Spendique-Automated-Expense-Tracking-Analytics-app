import re
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

from app.schemas.transaction import TransactionCreate


@dataclass
class ParseResult:
    transactions: list[TransactionCreate] = field(default_factory=list)
    skipped: int = 0


class BaseImporter(ABC):
    @abstractmethod
    def parse(self, content: bytes | str) -> ParseResult: ...


_DATE_FORMATS = (
    "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d/%m/%y", "%d-%m-%y",
    "%d %b %Y", "%d-%b-%Y", "%d-%b-%y", "%d %b %y", "%d %B %Y",
)
_TIME_TAIL = re.compile(r"[\sT]+\d{1,2}:\d{2}(:\d{2})?(\s*[AaPp][Mm])?$")


def parse_date(value: str) -> date | None:
    s = _TIME_TAIL.sub("", (value or "").strip())
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


def parse_amount(value: str) -> Decimal | None:
    s = re.sub(r"[^\d.\-]", "", value or "")
    if s in ("", "-", "."):
        return None
    try:
        return Decimal(s).quantize(Decimal("0.01"))
    except InvalidOperation:
        return None


_NOISE_LEAD = re.compile(
    r"^(?:(?:pos|atm|neft|imps|rtgs|ach|ecs|nach|to|by|transfer|debit|credit)[\s\-/*:]*)+",
    re.I,
)
_UPI_SKIP = {"payment", "payment from phone", "upi", "debit", "credit", "paytm", "ref"}


def extract_merchant(desc: str) -> str:
    text = " ".join((desc or "").split())
    if not text:
        return "Unknown"
    if text.upper().startswith("UPI"):
        for tok in re.split(r"[/\-]", text)[1:]:
            tok = tok.strip()
            if (
                len(tok) >= 2
                and re.search(r"[A-Za-z]", tok)
                and "@" not in tok
                and not tok.isdigit()
                and tok.lower() not in _UPI_SKIP
            ):
                return tok[:60].title()
    text = _NOISE_LEAD.sub("", text)
    text = re.sub(r"\b\w*\d{4,}\w*\b", "", text)  # drop ref numbers / masked cards
    text = " ".join(text.split())[:60].title()
    return text or "Unknown"