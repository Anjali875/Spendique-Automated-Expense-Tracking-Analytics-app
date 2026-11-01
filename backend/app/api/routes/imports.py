from collections import Counter
from decimal import Decimal

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.importers.base import ParseResult
from app.importers.csv_importer import CsvImporter
from app.importers.sms_parser import SmsParser
from app.models import Transaction, User
from app.schemas.transaction import ImportResult, SmsImportRequest
from app.services.categorizer import Categorizer

router = APIRouter(prefix="/import", tags=["import"])

MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_ROWS = 2000


def _key(d, amount, type_, merchant):
    return (d, Decimal(amount).quantize(Decimal("0.01")), type_, merchant.lower())


def save_parsed(result: ParseResult, db: Session, user: User) -> ImportResult:
    txns = result.transactions[:MAX_ROWS]
    skipped = result.skipped + max(0, len(result.transactions) - MAX_ROWS)
    if not txns:
        return ImportResult(imported=0, duplicates=0, skipped=skipped)

    history = db.execute(
        select(Transaction.merchant, Transaction.category).where(Transaction.user_id == user.id)
    ).all()
    categorizer = Categorizer([(m, c) for m, c in history])

    lo, hi = min(t.txn_date for t in txns), max(t.txn_date for t in txns)
    existing = db.execute(
        select(Transaction.txn_date, Transaction.amount, Transaction.type, Transaction.merchant)
        .where(Transaction.user_id == user.id, Transaction.txn_date.between(lo, hi))
    ).all()
    seen = Counter(_key(*row) for row in existing)

    imported = duplicates = 0
    for t in txns:
        k = _key(t.txn_date, t.amount, t.type, t.merchant)
        if seen[k] > 0:  # already in DB (counts handle genuine same-day repeats)
            seen[k] -= 1
            duplicates += 1
            continue
        category = categorizer.categorize(t.merchant, t.description, t.type)
        db.add(Transaction(**{**t.model_dump(), "category": category}, user_id=user.id))
        imported += 1
    db.commit()
    return ImportResult(imported=imported, duplicates=duplicates, skipped=skipped)


@router.post("/csv", response_model=ImportResult)
def import_csv(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    content = file.file.read(MAX_FILE_BYTES + 1)
    if len(content) > MAX_FILE_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 2 MB)")
    try:
        result = CsvImporter().parse(content)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return save_parsed(result, db, user)


@router.post("/sms", response_model=ImportResult)
def import_sms(
    data: SmsImportRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return save_parsed(SmsParser().parse(data.text), db, user)