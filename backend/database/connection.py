from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# -------------------------------------------------------------------------
# Database Configuration
# -------------------------------------------------------------------------
# We use SQLite for a serverless, self-contained database engine.
# check_same_thread=False is required for SQLite interactions within FastAPI.

SQLITE_URL = "sqlite:///./aynovax.db"

engine = create_engine(
    SQLITE_URL, connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """
    Dependency generator for database sessions.
    Ensures the connection is closed after each request.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()