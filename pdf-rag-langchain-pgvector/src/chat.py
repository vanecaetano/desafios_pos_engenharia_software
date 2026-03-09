import logging

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage

from src.config import settings
from src.search import retrieve_context

logger = logging.getLogger(__name__)

_PROMPT_TEMPLATE = """\
CONTEXTO:
{context}

REGRAS:
- Responda somente com base no CONTEXTO.
- Se a informação não estiver explicitamente no CONTEXTO, responda:
  "Não tenho informações necessárias para responder sua pergunta."
- Nunca invente ou use conhecimento externo.
- Nunca produza opiniões ou interpretações além do que está escrito.

EXEMPLOS DE PERGUNTAS FORA DO CONTEXTO:
Pergunta: "Qual é a capital da França?"
Resposta: "Não tenho informações necessárias para responder sua pergunta."

Pergunta: "Quantos clientes temos em 2024?"
Resposta: "Não tenho informações necessárias para responder sua pergunta."

Pergunta: "Você acha isso bom ou ruim?"
Resposta: "Não tenho informações necessárias para responder sua pergunta."

PERGUNTA DO USUÁRIO:
{question}

RESPONDA A "PERGUNTA DO USUÁRIO"\
"""


def build_prompt(context: str, question: str) -> str:
    return _PROMPT_TEMPLATE.format(context=context, question=question)


def run_chat() -> None:
    if not settings.GOOGLE_API_KEY:
        raise ValueError("GOOGLE_API_KEY não está configurada")

    llm = ChatGoogleGenerativeAI(
        model=settings.LLM_MODEL,
        google_api_key=settings.GOOGLE_API_KEY,
    )

    print("Chat iniciado. Pressione Ctrl+C para sair.\n")

    while True:
        try:
            question = input("PERGUNTA: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nEncerrando chat.")
            break

        if not question:
            continue

        try:
            context = retrieve_context(question)
            prompt = build_prompt(context=context, question=question)
            response = llm.invoke([HumanMessage(content=prompt)])
            print(f"RESPOSTA: {response.content}\n")
        except Exception as e:
            logger.error(f"Erro ao processar pergunta: {e}")
            print("Erro ao processar pergunta. Tente novamente.\n")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run_chat()
