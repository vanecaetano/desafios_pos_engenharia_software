import pytest
from langchain_core.documents import Document


@pytest.fixture
def fake_documents():
    return [
        Document(page_content="O faturamento da SuperTechIABrazil foi de 10 milhões de reais.", metadata={"page": 0}),
        Document(page_content="A empresa foi fundada em 2020 em São Paulo.", metadata={"page": 1}),
    ]


@pytest.fixture
def fake_chunks(fake_documents):
    return fake_documents


@pytest.fixture
def env_vars(monkeypatch):
    monkeypatch.setenv("GOOGLE_API_KEY", "test-api-key")
    monkeypatch.setenv("POSTGRES_HOST", "localhost")
    monkeypatch.setenv("POSTGRES_PORT", "5432")
    monkeypatch.setenv("POSTGRES_DB", "testdb")
    monkeypatch.setenv("POSTGRES_USER", "testuser")
    monkeypatch.setenv("POSTGRES_PASSWORD", "testpass")

    from src.config import settings
    monkeypatch.setattr(settings, "GOOGLE_API_KEY", "test-api-key")
