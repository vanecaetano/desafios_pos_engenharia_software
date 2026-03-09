import sys

from langchain_community.document_loaders import PyPDFLoader
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_postgres import PGVector
from langchain_text_splitters import RecursiveCharacterTextSplitter

from src.config import settings


def ingest_pdf(pdf_path: str) -> int:
    loader = PyPDFLoader(pdf_path)
    documents = loader.load()

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=settings.CHUNK_SIZE,
        chunk_overlap=settings.CHUNK_OVERLAP,
    )
    chunks = splitter.split_documents(documents)

    embeddings = GoogleGenerativeAIEmbeddings(
        model=settings.EMBEDDING_MODEL,
        google_api_key=settings.GOOGLE_API_KEY,
    )

    PGVector.from_documents(
        documents=chunks,
        embedding=embeddings,
        connection=settings.postgres_connection_string,
        collection_name=settings.COLLECTION_NAME,
        pre_delete_collection=True,
    )

    return len(chunks)


if __name__ == "__main__":
    pdf_path = sys.argv[1] if len(sys.argv) > 1 else "document.pdf"
    total = ingest_pdf(pdf_path)
    print(f"{total} chunks ingeridos com sucesso.")
