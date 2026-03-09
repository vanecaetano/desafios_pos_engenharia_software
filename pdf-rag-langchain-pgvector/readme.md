# Ingestão e Busca Semântica com LangChain e Postgres

Sistema CLI que lê um PDF, armazena chunks como vetores no PostgreSQL via pgVector e responde perguntas com base exclusivamente no conteúdo do documento usando o modelo Gemini da Google.

O documento de exemplo incluído é o **Guia de Duplicata Escritural** — material oficial sobre a digitalização das duplicatas regulamentado pelo Banco Central do Brasil (Lei 13.775/2018 e Resolução BCB 597/2024).

---

## Arquitetura

```
document.pdf
     │
     ▼
 ingest.py  ──►  PyPDFLoader  ──►  RecursiveCharacterTextSplitter (1000/150)
                                          │
                                          ▼
                              GoogleGenerativeAIEmbeddings (gemini-embedding-001)
                                          │
                                          ▼
                              PGVector (PostgreSQL 17 + pgVector)
                                          │
                    ┌─────────────────────┘
                    │
                    ▼
 chat.py  ──►  search.py (similarity_search_with_score, k=10)
                    │
                    ▼
            build_prompt (CONTEXTO + REGRAS + PERGUNTA)
                    │
                    ▼
        ChatGoogleGenerativeAI (gemini-2.5-flash-lite)
                    │
                    ▼
              RESPOSTA no terminal
```

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| Python | 3.13 |
| Docker + Docker Compose | v2 |
| Chave de API Google (Gemini) | [Obter aqui](https://aistudio.google.com/apikey) |

---

## Início rápido (recomendado)

Os scripts de inicialização fazem **tudo automaticamente**: criam o venv, instalam dependências, configuram o `.env`, sobem o banco, aguardam o healthcheck, executam a ingestão e iniciam o chat.

**Windows (PowerShell):**
```powershell
.\start.ps1
```

**Linux / macOS:**
```bash
chmod +x start.sh
./start.sh
```

> Na primeira execução, o script solicitará a `GOOGLE_API_KEY` caso o `.env` ainda não esteja configurado.

---

## Setup manual (alternativa)

```bash
# 1. Clone e entre no diretório
git clone <repo-url>
cd desafio1

# 2. Crie e ative o virtual environment
python -m venv venv
# Windows
.\venv\Scripts\Activate.ps1
# Linux / macOS
source venv/bin/activate

# 3. Instale as dependências
pip install -r requirements.txt

# 4. Configure as variáveis de ambiente
cp .env.example .env
# Edite .env e preencha GOOGLE_API_KEY com sua chave da Google AI
```

## Execução manual passo a passo

```bash
# 1. Suba o banco de dados
docker compose up -d

# 2. Execute a ingestão do PDF
python -m src.ingest

# 3. Inicie o chat
python -m src.chat
```

---

## Exemplo de interação

O documento incluído (`document.pdf`) é o Guia de Duplicata Escritural do BACEN. Exemplos reais de perguntas e respostas:

```
Chat iniciado. Pressione Ctrl+C para sair.

PERGUNTA: O que é a Duplicata Escritural?
RESPOSTA: A Duplicata Escritural é um título representado exclusivamente por
lançamentos eletrônicos, sem existência em papel. Ao contrário da duplicata
cartular (física), ela é criada e registrada digitalmente em sistemas
autorizados e supervisionados pelo Banco Central do Brasil.

PERGUNTA: Qual lei regulamenta a Duplicata Escritural?
RESPOSTA: A Duplicata Escritural é regulamentada pela Lei 13.775/2018 e pela
Resolução BCB 597/2024 do Banco Central do Brasil.

PERGUNTA: Qual é o papel das escrituradoras?
RESPOSTA: As escrituradoras são centrais autorizadas e supervisionadas pelo
Banco Central que garantem que cada duplicata escritural seja única, rastreável
e segura, criando uma única "fonte da verdade" confiável, acessível e
interoperável. Isso reduz fraude, evita duplicidade de recebíveis e destrava
crédito com mais velocidade e melhores taxas.

PERGUNTA: Qual a capital da França?
RESPOSTA: Não tenho informações necessárias para responder sua pergunta.
```

---

## Como rodar os testes

```bash
# Dentro do venv ativado
pytest tests/ -v
```

14 testes unitários cobrindo `config`, `ingest`, `search` e `chat`. Nenhuma dependência externa (banco ou API) é necessária — tudo é mockado.

---

## Estrutura do projeto

```
├── start.ps1                 # Script de inicialização (Windows / PowerShell)
├── start.sh                  # Script de inicialização (Linux / macOS)
├── docker-compose.yml        # PostgreSQL 17 + pgVector
├── init.sql                  # Habilita extensão vector no banco
├── requirements.txt          # Dependências com versões fixas
├── .env.example              # Template das variáveis de ambiente
├── document.pdf              # Guia de Duplicata Escritural (BACEN)
├── src/
│   ├── config.py             # Settings via pydantic-settings
│   ├── ingest.py             # Carrega PDF, chunking e indexação vetorial
│   ├── search.py             # Busca semântica no pgVector
│   └── chat.py               # CLI de chat com a LLM
└── tests/
    ├── conftest.py
    ├── test_config.py
    ├── test_ingest.py
    ├── test_search.py
    └── test_chat.py
```

---

## Bibliotecas e versões

| Biblioteca | Versão | Finalidade |
|---|---|---|
| `langchain` | 1.2.10 | Orquestração de pipelines LLM |
| `langchain-community` | 0.4.1 | `PyPDFLoader` e integrações da comunidade |
| `langchain-text-splitters` | 1.1.1 | `RecursiveCharacterTextSplitter` |
| `langchain-google-genai` | 4.2.1 | Embeddings e chat com Gemini |
| `langchain-postgres` | 0.0.17 | `PGVector` — store vetorial no PostgreSQL |
| `langchain-core` | 1.2.17 | Interfaces base do LangChain |
| `psycopg[binary]` | 3.3.3 | Driver PostgreSQL para Python |
| `pypdf` | 6.7.5 | Leitura de arquivos PDF |
| `pydantic-settings` | 2.13.1 | Gerenciamento de configuração via `.env` |
| `python-dotenv` | 1.2.2 | Carregamento do arquivo `.env` |
| `pytest` | 9.0.2 | Framework de testes |
| `pytest-mock` | 3.15.1 | Mocking integrado ao pytest |
| `SQLAlchemy` | 2.0.48 | ORM utilizado internamente pelo langchain-postgres |

> Versões completas de todas as dependências transitivas estão disponíveis via `pip freeze`.

---

## Decisões de projeto

- **`pydantic-settings`** centraliza todas as configurações — sem `os.getenv()` espalhado pelo código.
- **`src/search.py` desacoplado de `src/chat.py`** — `retrieve_context` é testável e reutilizável independentemente.
- **`pre_delete_collection=True`** no ingest — re-execuções do script sempre partem de um estado limpo, evitando duplicatas.
- **Prompt estrito** — a LLM só responde com base no contexto recuperado; nunca usa conhecimento externo.


