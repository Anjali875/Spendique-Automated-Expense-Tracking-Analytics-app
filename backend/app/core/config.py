from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./expense_tracker.db"
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    cors_origins: str = "*"

    model_config = SettingsConfigDict(env_file=".env")

    @field_validator("database_url")
    @classmethod
    def use_psycopg_driver(cls, v: str) -> str:
        for prefix in ("postgres://", "postgresql://"):
            if v.startswith(prefix):
                return "postgresql+psycopg://" + v[len(prefix):]
        return v


settings = Settings()