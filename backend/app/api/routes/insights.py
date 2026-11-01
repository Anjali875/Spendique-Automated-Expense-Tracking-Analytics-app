from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import User
from app.schemas.transaction import InsightsOut
from app.services.insights import build_insights

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("", response_model=InsightsOut)
def get_insights(
    months: int = Query(6, ge=1, le=12),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return build_insights(db, user.id, months)