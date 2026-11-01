from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, imports, insights, transactions
from app.core.config import settings
from app.db.base import Base
from app.db.session import engine
from app.models import Transaction, User  # noqa: F401  (registers tables)

Base.metadata.create_all(bind=engine)  # temporary, replaced by Alembic later

app = FastAPI(title="Expense Tracker API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)
app.include_router(transactions.router)
app.include_router(imports.router)
app.include_router(insights.router)


@app.get("/health")
def health():
    return {"status": "ok"}