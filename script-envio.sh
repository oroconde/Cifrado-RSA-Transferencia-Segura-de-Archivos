#!/bin/bash

# Configuración
REMETENTE_PRIVATE_KEY="/home/sftp-user/remitente_private_key.pem"  # Clave privada del remitente para firmar
REMETENTE_PUBLIC_KEY="/remitente_public_key.pem"    # Clave pública del remitente (se generará si no existe)
PROVEEDOR_PUBLIC_KEY="/home/sftp-user/proveedor_public_key.pem"    # Clave pública del proveedor para cifrar
servidor_sftp="servidor_sftp"  # Define el servidor SFTP de destino
archivos=("FE-Consecutivo-2024.11.05.txt" "NOM-Consecutivo-2024.11.05.txt")

# Verificar si las claves del remitente ya existen, si no, generarlas
if [ ! -f "$REMETENTE_PRIVATE_KEY" ]; then
    echo "$(date) Generando clave privada del remitente..."
    openssl genpkey -algorithm RSA -out "$REMETENTE_PRIVATE_KEY" -pkeyopt rsa_keygen_bits:2048
    echo "$(date) Clave privada generada: $REMETENTE_PRIVATE_KEY"
fi

if [ ! -f "$REMETENTE_PUBLIC_KEY" ]; then
    echo "$(date) Generando clave pública del remitente..."
    openssl rsa -pubout -in "$REMETENTE_PRIVATE_KEY" -out "$REMETENTE_PUBLIC_KEY"
    echo "$(date) Clave pública generada: $REMETENTE_PUBLIC_KEY"
fi

# Verificar si el host ya está en la lista de known_hosts
if ! grep -q "$servidor_sftp" ~/.ssh/known_hosts; then
    echo "$(date) Añadiendo $servidor_sftp a la lista de hosts conocidos..."
    mkdir -p ~/.ssh
    touch ~/.ssh/known_hosts
    ssh-keyscan -H "$servidor_sftp" >> ~/.ssh/known_hosts
fi

# Procesar cada archivo
for archivo in "${archivos[@]}"; do
  if [ -f "$archivo" ]; then
    # Firmar el archivo con la clave privada del remitente
    echo "$(date) Firmando el archivo $archivo con la clave privada del remitente..."
    openssl dgst -sha256 -sign "$REMETENTE_PRIVATE_KEY" -out "${archivo}.sig" "$archivo"
    echo "$(date) Firma digital generada: ${archivo}.sig"

    # Generar hash SHA-256 del archivo original
    echo "$(date) Generando hash SHA-256 del archivo $archivo..."
    sha256sum "$archivo" > "${archivo}.hash"
    echo "$(date) Hash generado: ${archivo}.hash"

    # Codificar el archivo en Unicode64
    echo "$(date) Codificando en Unicode64 el archivo $archivo..."
    iconv -f UTF-8 -t UTF-16 "$archivo" | base64 > "${archivo}.unicode64"
    echo "$(date) Codificación completada: ${archivo}.unicode64"

    # Cifrar el archivo con RSA usando la clave pública del proveedor
    echo "$(date) Cifrando el archivo $archivo con la clave pública del proveedor..."
    openssl pkeyutl -encrypt -inkey "$PROVEEDOR_PUBLIC_KEY" -pubin -in "${archivo}.unicode64" -out "${archivo}.enc"
    
    if [ $? -eq 0 ]; then
      echo "$(date) Archivo cifrado: ${archivo}.enc"
      rm -f "${archivo}.unicode64"  # Eliminar archivo intermedio
    else
      echo "$(date) Error al cifrar el archivo $archivo"
      exit 1
    fi
  else
    echo "$(date) Error: El archivo $archivo no existe."
    exit 1
  fi
done

# Comprimir los archivos cifrados, firmas, hashes y la clave pública del remitente
echo "$(date) Creando archivo ZIP con archivos cifrados, firmas, hashes y la clave pública del remitente..."
zip resultado_comprimido.zip *.enc *.hash *.sig "$REMETENTE_PUBLIC_KEY"

if [ $? -eq 0 ]; then
  echo "$(date) Archivo comprimido: resultado_comprimido.zip"
else
  echo "$(date) Error al crear el archivo ZIP."
  exit 1
fi

# Usar SFTP para enviar el archivo ZIP al servidor de recepción
echo "$(date) Enviando archivo a $servidor_sftp vía SFTP..."
sshpass -p 'centos' sftp -o StrictHostKeyChecking=no sftp-user@$servidor_sftp <<EOF
put resultado_comprimido.zip /home/sftp-user/
EOF

if [ $? -ne 0 ]; then
  echo "$(date) Error al enviar el archivo a $servidor_sftp"
else
  echo "$(date) Archivo enviado exitosamente a $servidor_sftp"
fi
