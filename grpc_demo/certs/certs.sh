#!/usr/bin/env bash
set -euo pipefail

# Desactiva la conversión automática de rutas en Git Bash
export MSYS_NO_PATHCONV=1

OUTPUT_DIR="."
KEY_FILE="${OUTPUT_DIR}/server.key"
CERT_FILE="${OUTPUT_DIR}/server.crt"
DAYS_VALID=365

# Usamos comillas simples, el orden -subj antes de -newkey
SUBJ='/C=PE/ST=Lima/L=Lima/O=MiEmpresa/OU=IT/CN=grpc.local'

echo "✅ Generando clave privada y certificado auto-firmado…"
openssl req -new -x509 \
  -days "${DAYS_VALID}" \
  -sha256 \
  -subj "${SUBJ}" \
  -newkey rsa:2048 \
  -nodes \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}"

echo "🎉 Hecho!"
echo "  • server.key → ${KEY_FILE}"
echo "  • server.crt → ${CERT_FILE}"
