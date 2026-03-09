#Requires -Version 5.1
<#
.SYNOPSIS
    Inicializa o ambiente completo do projeto e executa o chat.
.DESCRIPTION
    1. Verifica pre-requisitos (Python, Docker)
    2. Cria o virtual environment se necessario
    3. Instala dependencias
    4. Cria .env a partir de .env.example se necessario
    5. Sobe o banco de dados via Docker Compose
    6. Aguarda o banco ficar saudavel
    7. Executa a ingestao do PDF
    8. Inicia o chat interativo
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# Habilita sequ??ncias ANSI/VT no console do Windows
$null = [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ConsoleHelper {
    [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint mode);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint mode);
    [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
}
"@ -ErrorAction SilentlyContinue
try {
    $handle = [ConsoleHelper]::GetStdHandle(-11)
    $mode   = 0
    [void][ConsoleHelper]::GetConsoleMode($handle, [ref]$mode)
    [void][ConsoleHelper]::SetConsoleMode($handle, $mode -bor 4)
} catch {}

$VENV_DIR   = "venv"
$PYTHON_EXE = "$VENV_DIR\Scripts\python.exe"
$PIP_EXE    = "$VENV_DIR\Scripts\pip.exe"
$RESET      = [char]27 + "[0m"
$GREEN      = [char]27 + "[32m"
$YELLOW     = [char]27 + "[33m"
$RED        = [char]27 + "[31m"
$CYAN       = [char]27 + "[36m"

function Write-Step  { param($msg) Write-Host "${CYAN}==>${RESET} $msg" }
function Write-Ok    { param($msg) Write-Host "${GREEN}[OK]${RESET} $msg" }
function Write-Warn  { param($msg) Write-Host "${YELLOW}[AVISO]${RESET} $msg" }
function Write-Fail  { param($msg) Write-Host "${RED}[ERRO]${RESET} $msg"; exit 1 }

# ---------------------------------------------------------------------------
# 1. Pr??-requisitos
# ---------------------------------------------------------------------------
Write-Step "Verificando pre-requisitos..."

# Atualiza PATH da sessao para incluir instalacoes feitas pelo winget/instalador
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

$pythonExe = $null
foreach ($candidate in @("python", "python3")) {
    try {
        $ver = & $candidate --version 2>&1
        if ("$ver" -match "Python 3\.") { $pythonExe = $candidate; break }
    } catch { }
}
if (-not $pythonExe) { Write-Fail "Python 3 nao encontrado. Instale em https://python.org" }
Write-Ok "Python encontrado: $(& $pythonExe --version 2>&1)"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Fail "Docker nao encontrado. Instale em https://docs.docker.com/get-docker/"
}
Write-Ok "Docker encontrado: $(docker --version)"

# Verifica se o daemon Docker esta acessivel; se nao, tenta iniciar o Docker Desktop
$dockerRunning = $false
$dockerInfo = docker info 2>$null
if ($LASTEXITCODE -eq 0) {
    $dockerRunning = $true
} else {
    Write-Warn "Docker Desktop nao esta rodando. Tentando iniciar..."
    $dockerDesktopPaths = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    )
    $started = $false
    foreach ($path in $dockerDesktopPaths) {
        if (Test-Path $path) {
            Start-Process $path
            $started = $true
            break
        }
    }
    if (-not $started) {
        Write-Fail "Docker Desktop nao encontrado. Inicie-o manualmente e tente novamente."
    }
    Write-Host "  Aguardando Docker Desktop inicializar (ate 60s)..."
    $timeout = 30
    for ($i = 0; $i -lt $timeout; $i++) {
        Start-Sleep -Seconds 2
        $null = docker info 2>$null
        if ($LASTEXITCODE -eq 0) { $dockerRunning = $true; break }
        Write-Host "  [$($i*2+2)s] Aguardando daemon..."
    }
    if (-not $dockerRunning) {
        Write-Fail "Docker nao ficou disponivel. Inicie o Docker Desktop manualmente e execute o script novamente."
    }
}
Write-Ok "Docker daemon acessivel."

# ---------------------------------------------------------------------------
# 2. Virtual environment
# ---------------------------------------------------------------------------
Write-Step "Configurando virtual environment..."

if (-not (Test-Path $PYTHON_EXE)) {
    Write-Warn "venv nao encontrado. Criando..."
    & $pythonExe -m venv $VENV_DIR
    Write-Ok "venv criado em ./$VENV_DIR"
} else {
    Write-Ok "venv ja existe."
}

# ---------------------------------------------------------------------------
# 3. Dependencias
# ---------------------------------------------------------------------------
Write-Step "Instalando/verificando dependencias..."
& $PIP_EXE install --quiet --upgrade pip 2>$null | Out-Null
& $PIP_EXE install --quiet -r requirements.txt 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Falha ao instalar dependencias. Execute manualmente: $PIP_EXE install -r requirements.txt"
}
Write-Ok "Dependencias instaladas."

# ---------------------------------------------------------------------------
# 4. Arquivo .env
# ---------------------------------------------------------------------------
Write-Step "Verificando configuracao do ambiente (.env)..."

if (-not (Test-Path ".env")) {
    if (-not (Test-Path ".env.example")) { Write-Fail ".env.example nao encontrado." }
    Copy-Item ".env.example" ".env"
    Write-Warn ".env criado a partir de .env.example"

    $apiKey = Read-Host "  Digite sua GOOGLE_API_KEY (ou Enter para preencher manualmente depois)"
    if ($apiKey.Trim() -ne "") {
        (Get-Content ".env") -replace "your_google_api_key_here", $apiKey.Trim() |
            Set-Content ".env"
        Write-Ok "GOOGLE_API_KEY salva no .env"
    } else {
        Write-Warn "Lembre-se de preencher GOOGLE_API_KEY no arquivo .env antes de continuar."
        Read-Host "Pressione Enter quando o .env estiver configurado"
    }
} else {
    $envContent = Get-Content ".env" -Raw
    if ($envContent -match "your_google_api_key_here") {
        Write-Warn "GOOGLE_API_KEY ainda contem o valor padrao no .env. Edite o arquivo .env."
        Read-Host "Pressione Enter quando estiver configurado"
    } else {
        Write-Ok ".env configurado."
    }
}

# ---------------------------------------------------------------------------
# 5. Docker Compose
# ---------------------------------------------------------------------------
Write-Step "Subindo banco de dados (PostgreSQL + pgVector)..."

docker compose up -d
if ($LASTEXITCODE -ne 0) { Write-Fail "Falha ao subir os conteineres." }

# ---------------------------------------------------------------------------
# 6. Aguardar banco ficar saudavel
# ---------------------------------------------------------------------------
Write-Step "Aguardando PostgreSQL ficar pronto..."

$maxAttempts = 30
$attempt     = 0
$ready       = $false

while ($attempt -lt $maxAttempts) {
    $attempt++
    $status = docker inspect --format "{{.State.Health.Status}}" pgvector_db 2>$null
    if ($status -eq "healthy") { $ready = $true; break }
    Write-Host "  Tentativa $attempt/$maxAttempts - status: $status"
    Start-Sleep -Seconds 2
}

if (-not $ready) { Write-Fail "Banco nao ficou saudavel apos $($maxAttempts * 2)s. Verifique: docker compose logs postgres" }
Write-Ok "PostgreSQL pronto."

# ---------------------------------------------------------------------------
# 7. Ingestao do PDF
# ---------------------------------------------------------------------------
Write-Step "Executando ingestao do PDF..."

if (-not (Test-Path "document.pdf")) {
    Write-Fail "document.pdf nao encontrado na raiz do projeto."
}

& $PYTHON_EXE -m src.ingest
if ($LASTEXITCODE -ne 0) { Write-Fail "Falha na ingestao do PDF." }
Write-Ok "Ingestao concluida."

# ---------------------------------------------------------------------------
# 8. Iniciar chat
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "${GREEN}Ambiente pronto!${RESET} Iniciando chat..."
Write-Host "(Pressione Ctrl+C para encerrar o chat)"
Write-Host ""

& $PYTHON_EXE -m src.chat





