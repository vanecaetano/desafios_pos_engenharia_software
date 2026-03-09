#!/usr/bin/env bash
# Inicializa o ambiente completo do projeto e executa o chat.
# Compatível com Linux e macOS.
set -euo pipefail

VENV_DIR="venv"
PYTHON_EXE="$VENV_DIR/bin/python"
PIP_EXE="$VENV_DIR/bin/pip"

GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"

step()  { echo -e "${CYAN}==> $*${RESET}"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[AVISO]${RESET} $*"; }
fail()  { echo -e "${RED}[ERRO]${RESET} $*"; exit 1; }

# 1. Pré-requisitos
step "Verificando pré-requisitos..."

PYTHON_BIN=""
for candidate in python3 python; do
    if command -v "$candidate" &>/dev/null && "$candidate" --version 2>&1 | grep -q "Python 3"; then
        PYTHON_BIN="$candidate"; break
    fi
done
[[ -z "$PYTHON_BIN" ]] && fail "Python 3 não encontrado. Instale em https://python.org"
ok "Python: $($PYTHON_BIN --version)"

command -v docker &>/dev/null || fail "Docker não encontrado. Instale em https://docs.docker.com/get-docker/"
ok "Docker: $(docker --version)"

# 2. Virtual environment
step "Configurando virtual environment..."
if [[ ! -f "$PYTHON_EXE" ]]; then
    warn "venv não encontrado. Criando..."
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    ok "venv criado em ./$VENV_DIR"
else
    ok "venv já existe."
fi

# 3. Dependências
step "Instalando/verificando dependências..."
"$PIP_EXE" install --quiet --upgrade pip
"$PIP_EXE" install --quiet -r requirements.txt
ok "Dependências instaladas."

# 4. .env
step "Verificando configuração do ambiente (.env)..."
if [[ ! -f ".env" ]]; then
    [[ ! -f ".env.example" ]] && fail ".env.example não encontrado."
    cp .env.example .env
    warn ".env criado a partir de .env.example"
    read -rp "  Digite sua GOOGLE_API_KEY (ou Enter para preencher depois): " API_KEY
    if [[ -n "$API_KEY" ]]; then
        sed -i.bak "s/your_google_api_key_here/$API_KEY/" .env && rm -f .env.bak
        ok "GOOGLE_API_KEY salva no .env"
    else
        warn "Preencha GOOGLE_API_KEY no .env antes de continuar."
        read -rp "Pressione Enter quando estiver configurado..."
    fi
else
    if grep -q "your_google_api_key_here" .env; then
        warn "GOOGLE_API_KEY ainda contém o valor padrão. Edite o .env."
        read -rp "Pressione Enter quando estiver configurado..."
    else
        ok ".env configurado."
    fi
fi

# 5. Docker Compose
step "Subindo banco de dados (PostgreSQL + pgVector)..."
docker compose up -d

# 6. Aguardar banco
step "Aguardando PostgreSQL ficar pronto..."
MAX=30; i=0; READY=0
while [[ $i -lt $MAX ]]; do
    i=$((i+1))
    STATUS=$(docker inspect --format "{{.State.Health.Status}}" pgvector_db 2>/dev/null || echo "unknown")
    [[ "$STATUS" == "healthy" ]] && { READY=1; break; }
    echo "  Tentativa $i/$MAX - status: $STATUS"
    sleep 2
done
[[ $READY -eq 0 ]] && fail "Banco não ficou saudável. Verifique: docker compose logs postgres"
ok "PostgreSQL pronto."

# 7. Ingestão
step "Executando ingestão do PDF..."
[[ ! -f "document.pdf" ]] && fail "document.pdf não encontrado na raiz do projeto."
"$PYTHON_EXE" -m src.ingest
ok "Ingestao concluida."

# 8. Chat
echo ""
echo -e "${GREEN}Ambiente pronto!${RESET} Iniciando chat..."
echo "(Pressione Ctrl+C para encerrar)"
echo ""
"$PYTHON_EXE" -m src.chat
