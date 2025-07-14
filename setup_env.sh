#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------
# Verificar privilegios de administrador
# ----------------------------------------
if [[ "$OSTYPE" =~ (msys|cygwin) ]]; then
  if ! net session >/dev/null 2>&1; then
    echo "[ERROR] Debes ejecutar este script con permisos de Administrador."
    echo "Abre Git Bash como Administrador (clic derecho → 'Ejecutar como administrador')."
    exit 1
  fi
elif [[ "$OSTYPE" =~ (linux-gnu|linux-musl) ]]; then
  if [[ "$EUID" -ne 0 ]]; then
    echo "[ERROR] Debes ejecutar como root o con sudo."
    exit 1
  fi
else
  echo "[ERROR] Sistema operativo no soportado."
  exit 1
fi

# Logs
log_ok()   { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
log_err()  { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

log_ok "Privilegios de administrador verificados."

# Detectar SO
case "$(uname -s)" in
  *MINGW*|*MSYS*|*CYGWIN*) OS="windows" ;; 
  *) OS="linux" ;; 
esac
log_ok "SO detectado: $OS"

# ----------------------------------------
# Función de instalación con reintentos y validación por versión
# ----------------------------------------
ensure_cmd() {
  local cmd="$1"; shift
  local install_linux="$1"; shift
  local install_windows="$1"; shift
  local version_flag="--version"

  # Validar existencia por --version
  if $cmd $version_flag >/dev/null 2>&1; then
    local ver=$($cmd $version_flag 2>&1 | head -n1)
    log_ok "$cmd detectado: $ver"
    return
  fi

  # Intentar instalación
  for i in 1 2; do
    if [[ "$OS" == "linux" ]]; then
      log_ok "Instalando $cmd (intento $i)..."
      eval "$install_linux"
    else
      log_ok "Instalando $cmd (intento $i)..."
      eval "$install_windows"
      command -v refreshenv >/dev/null 2>&1 && refreshenv
    fi
    if $cmd $version_flag >/dev/null 2>&1; then
      local ver=$($cmd $version_flag 2>&1 | head -n1)
      log_ok "$cmd instalado: $ver"
      return
    fi
  done

  log_warn "No se pudo instalar $cmd tras dos intentos"
}

# ----------------------------------------
# Instalar gestor de paquetes (Chocolatey) en Windows siempre
# ----------------------------------------
if [[ "$OS" == "windows" ]]; then
  log_ok "Instalando gestor de paquetes [1;36mChocolatey[0m..."
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
    "Set-ExecutionPolicy Bypass -Scope Process -Force; \
     [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; \
     iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
fi

# ----------------------------------------
# Instalar herramientas clave
# ----------------------------------------
# ----------------------------------------
if [[ "$OS" == "windows" ]]; then
  ensure_cmd "choco" "" "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"Set-ExecutionPolicy Bypass -Scope Process -Force; [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))\""
fi

# ----------------------------------------
# Instalar herramientas clave
# ----------------------------------------
# 1) jq (JSON parser)
ensure_cmd "jq" "apt-get update && apt-get install -y jq" "choco install jq -y"

# 2) AWS CLI v2
ensure_cmd "aws" \
  "apt-get install -y unzip curl && curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o awscliv2.zip && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws" \
  "choco install awscli -y"

# 3) Terraform
ensure_cmd "terraform" \
  "apt-get update && apt-get install -y terraform" \
  "choco install terraform -y"

# 4) Python & pip
if [[ "$OS" == "windows" ]]; then
  # Windows: buscar py o python
  if command -v py >/dev/null 2>&1; then
    log_ok "py detectado: $(py --version 2>&1)"
    PY_CMD=py
  elif command -v python >/dev/null 2>&1; then
    log_ok "python detectado: $(python --version 2>&1)"
    PY_CMD=python
  else
    log_warn "No se encontró Python; instalando via choco"
    choco install python -y
    command -v refreshenv >/dev/null 2>&1 && refreshenv
    PY_CMD=python
    log_ok "python instalado: $(python --version 2>&1)"
  fi
else
  # Linux: python3 preferido
  if command -v python3 >/dev/null 2>&1; then
    log_ok "python3 detectado: $(python3 --version 2>&1)"
    PY_CMD=python3
  else
    log_warn "python3 no encontrado; instalando python3..."
    apt-get update && apt-get install -y python3 python3-venv python3-pip
    if command -v python3 >/dev/null 2>&1; then
      log_ok "python3 instalado: $(python3 --version 2>&1)"
      PY_CMD=python3
    else
      log_err "No se pudo instalar python3"
      PY_CMD=""
    fi
  fi
fi

# 5) virtualenvwrapper (opcional) (opcional)
if [[ -n "$PY_CMD" ]]; then
  if $PY_CMD -m pip install --user virtualenv virtualenvwrapper >/dev/null 2>&1; then
    log_ok "virtualenvwrapper listo"
  else
    log_warn "Fallo instalación de virtualenvwrapper"
  fi
else
  log_warn "Omitiendo virtualenvwrapper; intérprete no disponible"
fi

log_ok "¡Entorno configurado con éxito!"
