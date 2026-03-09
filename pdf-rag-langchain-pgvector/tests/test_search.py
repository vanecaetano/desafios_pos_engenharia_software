import pytest
from langchain_core.documents import Document


def test_retrieve_context_raises_on_empty_query(env_vars, mocker):
    mocker.patch("src.search._build_vector_store")

    from src.search import retrieve_context

    with pytest.raises(ValueError, match="vazia"):
        retrieve_context("")

    with pytest.raises(ValueError, match="vazia"):
        retrieve_context("   ")


def test_retrieve_context_concatenates_results(env_vars, mocker):
    doc1 = Document(page_content="Faturamento de 10 milhões.")
    doc2 = Document(page_content="Empresa fundada em 2020.")
    mock_store = mocker.MagicMock()
    mock_store.similarity_search_with_score.return_value = [(doc1, 0.9), (doc2, 0.7)]
    mocker.patch("src.search._build_vector_store", return_value=mock_store)

    from src.search import retrieve_context

    result = retrieve_context("Qual o faturamento?")

    assert "Faturamento de 10 milhões." in result
    assert "Empresa fundada em 2020." in result
    mock_store.similarity_search_with_score.assert_called_once_with("Qual o faturamento?", k=10)


def test_retrieve_context_returns_empty_string_when_no_results(env_vars, mocker):
    mock_store = mocker.MagicMock()
    mock_store.similarity_search_with_score.return_value = []
    mocker.patch("src.search._build_vector_store", return_value=mock_store)

    from src.search import retrieve_context

    result = retrieve_context("Pergunta sem resultados")

    assert result == ""


def test_retrieve_context_separates_chunks_with_double_newline(env_vars, mocker):
    doc1 = Document(page_content="Parte A.")
    doc2 = Document(page_content="Parte B.")
    mock_store = mocker.MagicMock()
    mock_store.similarity_search_with_score.return_value = [(doc1, 0.95), (doc2, 0.80)]
    mocker.patch("src.search._build_vector_store", return_value=mock_store)

    from src.search import retrieve_context

    result = retrieve_context("qualquer coisa")

    assert result == "Parte A.\n\nParte B."
