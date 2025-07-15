#!/usr/bin/env bash
# NO activar set -euo pipefail para poder depurar
IFS=$'\n\t'

ROOT_DIR="."
TMPDIR="$(mktemp -d)"
ORPHANED_REPORT="$(pwd)/orphaned_resources.txt"

echo "[DEBUG] TMPDIR creado: $TMPDIR"
echo "[DEBUG] ORPHANED_REPORT será: $ORPHANED_REPORT"

touch "$TMPDIR/all_vpc_ids.txt" \
      "$TMPDIR/all_sg_ids.txt" \
      "$TMPDIR/all_bucket_names.txt" \
      "$TMPDIR/all_alb_names.txt" \
      "$TMPDIR/all_zone_names.txt" \
      "$TMPDIR/all_eks_names.txt"

echo "[DEBUG] Archivos de recursos vacíos inicializados en $TMPDIR"
echo "[DEBUG] Buscando archivos .tfstate en todo el árbol de carpetas..."

FOUND=0

while IFS= read -r STATE_FILE; do
  echo "[DEBUG] Recorriendo archivo: $STATE_FILE"
  if [ ! -f "$STATE_FILE" ]; then 
    echo "[DEBUG] No es un archivo: $STATE_FILE"
    continue
  fi
  FOUND=1
  PARENT_DIR=$(dirname "$STATE_FILE")
  echo "[DEBUG] Revisando carpeta: $PARENT_DIR"
  echo "[DEBUG]   Procesando archivo: $STATE_FILE"

  # Detectar si es state local o referencia S3
  if jq -e '.backend.type=="s3" or .backend.type=="remote"' "$STATE_FILE" > /dev/null 2>&1; then
    echo "[DEBUG]   Es backend S3/remoto"
    BUCKET=$(jq -r '.backend.config.bucket // empty' "$STATE_FILE")
    KEY=$(jq -r '.backend.config.key // empty' "$STATE_FILE")
    echo "[DEBUG]   Bucket extraído: $BUCKET"
    echo "[DEBUG]   Key extraído: $KEY"
    if [[ -n "$BUCKET" && -n "$KEY" ]]; then
      TMP_STATE_FILE="$TMPDIR/tmp_state_$(basename "$STATE_FILE")"
      echo "[DEBUG]   Intentando descargar S3 state real: s3://$BUCKET/$KEY"
      if aws s3 cp "s3://$BUCKET/$KEY" "$TMP_STATE_FILE" --quiet 2>/dev/null; then
        echo "[DEBUG]   Descarga OK: $TMP_STATE_FILE"
        STATE_TO_PROCESS="$TMP_STATE_FILE"
      else
        echo "[DEBUG]   Falló la descarga S3: s3://$BUCKET/$KEY, se omite"
        continue
      fi
    else
      echo "[DEBUG]   No se pudo extraer bucket/key, se omite"
      continue
    fi
  else
    echo "[DEBUG]   Es state local"
    STATE_TO_PROCESS="$STATE_FILE"
  fi

  # VPCs
  echo "[DEBUG]   Extrayendo VPCs"
  jq -r '
    if .resources then .resources[] | select(.type == "aws_vpc") | .instances[]? | .attributes.id
    else empty end' "$STATE_TO_PROCESS" >> "$TMPDIR/all_vpc_ids.txt" || true
  # Security Groups
  echo "[DEBUG]   Extrayendo Security Groups"
  jq -r '
    if .resources then .resources[] | select(.type == "aws_security_group") | .instances[]? | .attributes.id
    else empty end' "$STATE_TO_PROCESS" >> "$TMPDIR/all_sg_ids.txt" || true
  # S3 Buckets
  echo "[DEBUG]   Extrayendo S3 Buckets"
  jq -r '
    if .resources then .resources[] | select(.type == "aws_s3_bucket") | .instances[]? | .attributes.bucket
    else empty end' "$STATE_TO_PROCESS" >> "$TMPDIR/all_bucket_names.txt" || true
  # ALB
  echo "[DEBUG]   Extrayendo ALBs"
  jq -r '
    if .resources then .resources[] | select(.type == "aws_lb") | .instances[]? | .attributes.name
    else empty end' "$STATE_TO_PROCESS" >> "$TMPDIR/all_alb_names.txt" || true
  # Route53 Zones
  echo "[DEBUG]   Extrayendo Route53 Zones"
  jq -r '
    if .resources then .resources[] | select(.type == "aws_route53_zone") | .instances[]? | .attributes.name
    else empty end' "$STATE_TO_PROCESS" >> "$TMPDIR/all_zone_names.txt" || true
  # EKS Clusters
  echo "[DEBUG]   Extrayendo EKS Clusters"
  jq -r '
    if .resources then .resources[] | select(.type == "aws_eks_cluster") | .instances[]? | .attributes.name
    else empty end' "$STATE_TO_PROCESS" >> "$TMPDIR/all_eks_names.txt" || true

  [[ "$STATE_TO_PROCESS" != "$STATE_FILE" ]] && rm -f "$STATE_TO_PROCESS"

done < <(find "$ROOT_DIR" -type f -name "*.tfstate")

if [ "$FOUND" -eq 0 ]; then
  echo "[DEBUG] No se encontraron archivos *.tfstate en ninguna subcarpeta de $ROOT_DIR."
  rm -rf "$TMPDIR"
  exit 1
fi

echo "[DEBUG] Limpiando duplicados y líneas vacías en los recursos extraídos..."
for f in "$TMPDIR"/*; do
  grep -v '^$' "$f" | sort -u > "${f}.clean"
  mv "${f}.clean" "$f"
done

echo "[DEBUG] Archivo de reporte limpiado: $ORPHANED_REPORT"
> "$ORPHANED_REPORT"
echo "[DEBUG] Comparando con recursos existentes en AWS..."

# VPCs
echo "[DEBUG] Buscando VPCs huérfanas"
echo "--- VPCs huérfanas ---" >> "$ORPHANED_REPORT"
ALL_VPCS=$(aws ec2 describe-vpcs --query "Vpcs[].VpcId" --output text 2>&1)
if [ $? -ne 0 ]; then
  echo "[ERROR] Falló el comando AWS para VPCs: $ALL_VPCS"
else
  echo "$ALL_VPCS" | tr '\t' '\n' | while read -r VPC; do
    if [ -n "$VPC" ] && ! grep -Fxq "$VPC" "$TMPDIR/all_vpc_ids.txt"; then
      echo "$VPC" >> "$ORPHANED_REPORT"
    fi
  done
fi
echo "[DEBUG] VPC block terminado"

# Security Groups
echo "[DEBUG] Security Groups en AWS:"
ALL_SGS=$(aws ec2 describe-security-groups --query "SecurityGroups[].GroupId" --output text 2>&1)
echo "$ALL_SGS" | tr '\t' '\n'
echo "[DEBUG] Security Groups gestionados por Terraform:"
cat "$TMPDIR/all_sg_ids.txt"

echo "[DEBUG] Buscando Security Groups huérfanos"
echo "--- Security Groups huérfanos ---" >> "$ORPHANED_REPORT"
if [ $? -ne 0 ]; then
  echo "[ERROR] Falló el comando AWS para SGs: $ALL_SGS"
else
  echo "$ALL_SGS" | tr '\t' '\n' | while read -r SG; do
    if [ -n "$SG" ] && ! grep -Fxq "$SG" "$TMPDIR/all_sg_ids.txt"; then
      echo "$SG" >> "$ORPHANED_REPORT"
    fi
  done
fi
echo "[DEBUG] SG block terminado"

# S3 Buckets
echo "[DEBUG] Buscando S3 buckets huérfanos"
echo "--- S3 buckets huérfanos ---" >> "$ORPHANED_REPORT"
ALL_BUCKETS=$(aws s3api list-buckets --query "Buckets[].Name" --output text 2>&1)
if [ $? -ne 0 ]; then
  echo "[ERROR] Falló el comando AWS para Buckets: $ALL_BUCKETS"
else
  echo "$ALL_BUCKETS" | tr '\t' '\n' | while read -r BUCKET; do
    if [ -n "$BUCKET" ] && ! grep -Fxq "$BUCKET" "$TMPDIR/all_bucket_names.txt"; then
      echo "$BUCKET" >> "$ORPHANED_REPORT"
    fi
  done
fi
echo "[DEBUG] S3 block terminado"

# ALBs
echo "[DEBUG] Buscando ALBs huérfanos"
echo "--- ALBs huérfanos ---" >> "$ORPHANED_REPORT"
ALL_ALBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerName" --output text 2>&1)
if [ $? -ne 0 ]; then
  echo "[ERROR] Falló el comando AWS para ALBs: $ALL_ALBS"
else
  echo "$ALL_ALBS" | tr '\t' '\n' | while read -r ALB; do
    if [ -n "$ALB" ] && ! grep -Fxq "$ALB" "$TMPDIR/all_alb_names.txt"; then
      echo "$ALB" >> "$ORPHANED_REPORT"
    fi
  done
fi
echo "[DEBUG] ALB block terminado"

# Route53 Hosted Zones
echo "[DEBUG] Buscando Route53 zones huérfanas"
echo "--- Route53 zones huérfanas ---" >> "$ORPHANED_REPORT"
ALL_ZONES=$(aws route53 list-hosted-zones --query "HostedZones[].Name" --output text 2>&1)
if [ $? -ne 0 ]; then
  echo "[ERROR] Falló el comando AWS para Zones: $ALL_ZONES"
else
  echo "$ALL_ZONES" | tr '\t' '\n' | while read -r ZONE; do
    CLEANED_ZONE="${ZONE%.}"
    if [ -n "$CLEANED_ZONE" ] && ! grep -Fxq "$CLEANED_ZONE" "$TMPDIR/all_zone_names.txt"; then
      echo "$CLEANED_ZONE" >> "$ORPHANED_REPORT"
    fi
  done
fi
echo "[DEBUG] Route53 block terminado"

# EKS Clusters
echo "[DEBUG] Buscando EKS clusters huérfanos"
echo "--- EKS clusters huérfanos ---" >> "$ORPHANED_REPORT"
ALL_EKS=$(aws eks list-clusters --query "clusters[]" --output text 2>&1)
if [ $? -ne 0 ]; then
  echo "[ERROR] Falló el comando AWS para EKS: $ALL_EKS"
else
  echo "$ALL_EKS" | tr '\t' '\n' | while read -r EKS; do
    if [ -n "$EKS" ] && ! grep -Fxq "$EKS" "$TMPDIR/all_eks_names.txt"; then
      echo "$EKS" >> "$ORPHANED_REPORT"
    fi
  done
fi
echo "[DEBUG] EKS block terminado"

echo "[DEBUG] Reporte final generado: $ORPHANED_REPORT"
ls -lh "$ORPHANED_REPORT"
cat "$ORPHANED_REPORT"
echo "[DEBUG] FIN DEL SCRIPT"
rm -rf "$TMPDIR"
