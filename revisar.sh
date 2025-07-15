#!/usr/bin/env bash
# Script para listar todos los archivos Python y Terraform en el proyecto

OUTPUT="recursos_consolidados.txt"
echo "Listado de recursos del proyecto" > "$OUTPUT"
echo "Fecha de generación: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "== Archivos Python ==" >> "$OUTPUT"
find . -type f -name "*.py" | sort >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "== Archivos Terraform ==" >> "$OUTPUT"
find . -type f -name "*.tf" | sort >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "== Módulos Terraform ==" >> "$OUTPUT"
find . -type d -name "modules" | while read dir; do
  echo "Módulo: $dir" >> "$OUTPUT"
  find "$dir" -type f -name "*.tf" | sort >> "$OUTPUT"
  echo "" >> "$OUTPUT"
done

echo "" >> "$OUTPUT"
echo "== Archivos README y documentación ==" >> "$OUTPUT"
find . -type f \( -iname "readme.md" -o -iname "*.md" \) | sort >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "== Estructura de carpetas del proyecto ==" >> "$OUTPUT"
tree -d -L 3 >> "$OUTPUT" 2>/dev/null || find . -type d | sort >> "$OUTPUT"

echo "Archivo generado: $OUTPUT"
