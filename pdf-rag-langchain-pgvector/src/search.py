from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_postgres import PGVector

from src.config import settings


def _build_vector_store() -> PGVector:
    embeddings = GoogleGenerativeAIEmbeddings(
        model=settings.EMBEDDING_MODEL,
        google_api_key=settings.GOOGLE_API_KEY,
    )
    return PGVector(
        embeddings=embeddings,
        connection=settings.postgres_connection_string,
        collection_name=settings.COLLECTION_NAME,
    )


def retrieve_context(query: str) -> str:
    store = _build_vector_store()
    results = store.similarity_search_with_score(query, k=settings.SEARCH_K)

    if not results:
        return ""

    return "\n\n".join(doc.page_content for doc, _score in results)
