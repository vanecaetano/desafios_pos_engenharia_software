from src.config import Settings


def test_settings_reads_env_vars(env_vars):
    s = Settings()
    assert s.GOOGLE_API_KEY == "test-api-key"
    assert s.POSTGRES_HOST == "localhost"
    assert s.POSTGRES_PORT == 5432
    assert s.POSTGRES_DB == "testdb"
    assert s.POSTGRES_USER == "testuser"
    assert s.POSTGRES_PASSWORD == "testpass"


def test_settings_default_constants(env_vars):
    s = Settings()
    assert s.CHUNK_SIZE == 1000
    assert s.CHUNK_OVERLAP == 150
    assert s.SEARCH_K == 10
    assert s.EMBEDDING_MODEL == "models/gemini-embedding-001"
    assert s.LLM_MODEL == "gemini-2.5-flash-lite"
    assert s.COLLECTION_NAME == "pdf_documents"


def test_postgres_connection_string_format(env_vars):
    s = Settings()
    expected = "postgresql+psycopg://testuser:testpass@localhost:5432/testdb"
    assert s.postgres_connection_string == expected
