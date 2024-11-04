#!/bin/bash

# Configuración
PRIVATE_KEY="/home/sftp-user/private_key.pem"   # Clave privada del proveedor para descifrar
PUBLIC_KEY_ORG="/home/sftp-user/public_key_org.pem"   # Clave pública de la organización para verificar la firma
archivos=("FE-Consecutivo-2024.11.05.txt" "NOM-Consecutivo-2024.11.05.txt")

# Descomprimir los archivos
echo "$(date) Descomprimiendo el archivo ZIP..."
unzip resultado_comprimido.zip

for archivo in "${archivos[@]}"; do
  # Descifrar el archivo con la clave privada del proveedor
  echo "$(date) Descifrando el archivo ${archivo}.enc..."
  openssl pkeyutl -decrypt -inkey "$PRIVATE_KEY" -in "${archivo}.enc" -out "${archivo}.unicode64"

  if [ $? -eq 0 ]; then
    echo "$(date) Archivo descifrado: ${archivo}.unicode64"
  else
    echo "$(date) Error al descifrar el archivo $archivo"
    exit 1
  fi

  # Decodificar el archivo de Unicode64 a UTF-8
  echo "$(date) Decodificando el archivo $archivo de Unicode64 a UTF-8..."
  base64 -d "${archivo}.unicode64" | iconv -f UTF-16 -t UTF-8 > "$archivo"

  # Verificar la firma digital con la clave pública de la organización
  echo "$(date) Verificando la firma digital del archivo $archivo..."
  openssl dgst -sha256 -verify "$PUBLIC_KEY_ORG" -signature "${archivo}.sig" "$archivo"

  if [ $? -eq 0 ]; then
    echo "$(date) La firma digital es válida para $archivo"
  else
    echo "$(date) La firma digital no es válida para $archivo"
    exit 1
  fi
done