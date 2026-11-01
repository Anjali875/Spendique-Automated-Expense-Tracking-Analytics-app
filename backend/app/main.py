from fastapi import FastAPI

from app.api.routes import auth, transactions
from app.db.base import Base
from app.db.session import engine
from app.models import Transaction, User  # noqa: F401  (registers tables)

Base.metadata.create_all(bind=engine)  # temporary, replaced by Alembic later

app = FastAPI(title="Expense Tracker API")
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)
app.include_router(auth.router)
app.include_router(transactions.router)


@app.get("/health")
def health():
    return {"status": "ok"}