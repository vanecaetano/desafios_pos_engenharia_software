from langchain_core.messages import AIMessage


def test_build_prompt_contains_context_and_question(env_vars):
    from src.chat import build_prompt

    context = "O faturamento foi de 10 milhões."
    question = "Qual o faturamento?"

    prompt = build_prompt(context=context, question=question)

    assert "O faturamento foi de 10 milhões." in prompt
    assert "Qual o faturamento?" in prompt


def test_build_prompt_contains_rules_section(env_vars):
    from src.chat import build_prompt

    prompt = build_prompt(context="ctx", question="q")

    assert "REGRAS:" in prompt
    assert "Responda somente com base no CONTEXTO" in prompt
    assert "Não tenho informações necessárias para responder sua pergunta." in prompt


def test_build_prompt_contains_pergunta_do_usuario_section(env_vars):
    from src.chat import build_prompt

    prompt = build_prompt(context="ctx", question="minha pergunta")

    assert "PERGUNTA DO USUÁRIO:" in prompt
    assert "minha pergunta" in prompt


def test_run_chat_prints_llm_response(env_vars, mocker, capsys):
    mocker.patch("src.chat.retrieve_context", return_value="Contexto relevante.")
    mock_llm = mocker.MagicMock()
    mock_llm.invoke.return_value = AIMessage(content="Resposta da LLM.")
    mocker.patch("src.chat.ChatGoogleGenerativeAI", return_value=mock_llm)
    mocker.patch("builtins.input", side_effect=["Qual o faturamento?", KeyboardInterrupt])

    from src.chat import run_chat

    run_chat()

    captured = capsys.readouterr()
    assert "RESPOSTA: Resposta da LLM." in captured.out


def test_run_chat_skips_empty_input(env_vars, mocker, capsys):
    mocker.patch("src.chat.retrieve_context", return_value="ctx")
    mock_llm = mocker.MagicMock()
    mock_llm.invoke.return_value = AIMessage(content="Resposta.")
    mocker.patch("src.chat.ChatGoogleGenerativeAI", return_value=mock_llm)
    mocker.patch("builtins.input", side_effect=["", "Pergunta válida", KeyboardInterrupt])

    from src.chat import run_chat

    run_chat()

    assert mock_llm.invoke.call_count == 1
