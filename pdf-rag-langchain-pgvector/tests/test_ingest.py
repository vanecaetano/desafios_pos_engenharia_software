from unittest.mock import MagicMock, patch

import pytest
from langchain_core.documents import Document


@pytest.fixture
def pdf_path(tmp_path):
    p = tmp_path / "test.pdf"
    p.write_bytes(b"%PDF-1.4 fake")
    return str(p)


def _patch_ingest_dependencies(mocker, fake_chunks):
    mocker.patch("src.ingest.PyPDFLoader.load", return_value=fake_chunks)
    mocker.patch(
        "src.ingest.RecursiveCharacterTextSplitter.split_documents",
        return_value=fake_chunks,
    )
    mocker.patch("src.ingest.GoogleGenerativeAIEmbeddings")
    return mocker.patch("src.ingest.PGVector.from_documents")


def test_ingest_pdf_returns_chunk_count(pdf_path, fake_chunks, env_vars, mocker):
    mock_from_docs = _patch_ingest_dependencies(mocker, fake_chunks)

    from src.ingest import ingest_pdf

    result = ingest_pdf(pdf_path)

    assert result == len(fake_chunks)
    mock_from_docs.assert_called_once()


def test_ingest_pdf_calls_splitter_with_correct_params(pdf_path, fake_chunks, env_vars, mocker):
    mocker.patch("src.ingest.PyPDFLoader.load", return_value=fake_chunks)
    mock_splitter_instance = MagicMock()
    mock_splitter_instance.split_documents.return_value = fake_chunks
    mock_splitter_cls = mocker.patch(
        "src.ingest.RecursiveCharacterTextSplitter",
        return_value=mock_splitter_instance,
    )
    mocker.patch("src.ingest.GoogleGenerativeAIEmbeddings")
    mocker.patch("src.ingest.PGVector.from_documents")

    from src.ingest import ingest_pdf

    ingest_pdf(pdf_path)

    mock_splitter_cls.assert_called_once_with(chunk_size=1000, chunk_overlap=150)


def test_ingest_pdf_passes_pre_delete_collection(pdf_path, fake_chunks, env_vars, mocker):
    mock_from_docs = _patch_ingest_dependencies(mocker, fake_chunks)

    from src.ingest import ingest_pdf

    ingest_pdf(pdf_path)

    _args, kwargs = mock_from_docs.call_args
    assert kwargs.get("pre_delete_collection") is True
