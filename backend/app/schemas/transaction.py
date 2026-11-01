from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class TransactionCreate(BaseModel):
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    type: Literal["debit", "credit"]
    merchant: str = Field(min_length=1, max_length=255)
    category: str = Field(default="Uncategorized", max_length=50)
    description: str | None = Field(default=None, max_length=500)
    txn_date: date


class TransactionUpdate(BaseModel):
    amount: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    type: Literal["debit", "credit"] | None = None
    merchant: str | None = Field(default=None, min_length=1, max_length=255)
    category: str | None = Field(default=None, max_length=50)
    description: str | None = Field(default=None, max_length=500)
    txn_date: date | None = None


class TransactionOut(TransactionCreate):
    model_config = ConfigDict(from_attributes=True)

    id: int

class SmsImportRequest(BaseModel):
    text: str = Field(min_length=1, max_length=50_000)


class ImportResult(BaseModel):
    imported: int
    duplicates: int
    skipped: int

class LabelTotal(BaseModel):
    label: str
    total: float


class MonthTotal(BaseModel):
    month: str  # "2026-11"
    income: float
    expense: float


class InsightsOut(BaseModel):
    income_30d: float
    expense_30d: float
    by_category: list[LabelTotal]
    top_merchants: list[LabelTotal]
    monthly: list[MonthTotal]