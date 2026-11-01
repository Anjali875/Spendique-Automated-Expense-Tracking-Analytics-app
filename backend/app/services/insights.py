from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Transaction


def _month_key(d: date) -> str:
    return f"{d.year}-{d.month:02d}"


def _shift_months(d: date, n: int) -> date:
    """First day of the month that is n months before d's month."""
    idx = d.year * 12 + (d.month - 1) - n
    return date(idx // 12, idx % 12 + 1, 1)


def build_insights(db: Session, user_id: int, months: int = 6, today: date | None = None) -> dict:
    today = today or date.today()
    window_start = today - timedelta(days=29)
    since = min(_shift_months(today, months - 1), window_start)

    rows = db.execute(
        select(
            Transaction.txn_date, Transaction.amount, Transaction.type,
            Transaction.category, Transaction.merchant,
        ).where(
            Transaction.user_id == user_id,
            Transaction.txn_date >= since,
            Transaction.txn_date <= today,
        )
    ).all()

    # Oldest -> newest, including months with no activity
    monthly = {
        _month_key(_shift_months(today, months - 1 - i)): {"income": Decimal(0), "expense": Decimal(0)}
        for i in range(months)
    }
    cats, merchants = defaultdict(Decimal), defaultdict(Decimal)
    income_30 = expense_30 = Decimal(0)

    for d, amount, type_, category, merchant in rows:
        amount = Decimal(str(amount))
        key = _month_key(d)
        if key in monthly:
            monthly[key]["expense" if type_ == "debit" else "income"] += amount
        if d >= window_start:
            if type_ == "debit":
                expense_30 += amount
                cats[category] += amount
                merchants[merchant] += amount
            else:
                income_30 += amount

    def top(totals: dict, n: int):
        ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)[:n]
        return [{"label": k, "total": float(v)} for k, v in ranked]

    return {
        "income_30d": float(income_30),
        "expense_30d": float(expense_30),
        "by_category": top(cats, 8),
        "top_merchants": top(merchants, 5),
        "monthly": [
            {"month": k, "income": float(v["income"]), "expense": float(v["expense"])}
            for k, v in monthly.items()
        ],
    }