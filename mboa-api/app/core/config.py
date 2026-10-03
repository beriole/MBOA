from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration de l'application, surchargeable par .env ou variables d'environnement."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "MBOA API"
    environment: str = "local"
    debug: bool = True

    # Base de donnees
    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_user: str = "mboa"
    db_password: str = "mboa"
    db_name: str = "mboa_dev"

    # Securite
    jwt_secret: str = "dev-secret-a-remplacer-en-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 30

    # Regles pedagogiques (cf. livrable D)
    checkpoint_pass_ratio: float = 0.8
    daily_goal_default_xp: int = 20
    xp_per_correct_answer: int = 2
    xp_per_lesson_completed: int = 10
    review_queue_size: int = 10

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

    @property
    def sync_database_url(self) -> str:
        """URL synchrone, utilisee par Alembic."""
        return (
            f"postgresql+psycopg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
