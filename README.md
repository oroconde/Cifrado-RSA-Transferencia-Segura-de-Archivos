# Proyecto de Cifrado y Transferencia Segura de Archivos

Este proyecto implementa un sistema de cifrado asimétrico para la transferencia segura de archivos entre dos contenedores Docker (uno de envío y otro de recepción), utilizando el algoritmo RSA. La clave privada se almacena de forma segura en un tercer contenedor que ejecuta HashiCorp Vault. El contenedor de envío cifra los archivos usando la clave pública, y el contenedor de recepción descifra los archivos utilizando la clave privada almacenada en Vault.

## Requisitos Previos

- [Docker](https://www.docker.com/) instalado en el sistema.
- [Docker Compose](https://docs.docker.com/compose/) instalado.
- Conexión a internet para descargar las imágenes necesarias.

## Descripción del Proyecto

### Contenedores involucrados:

1. **Vault**: Contenedor que almacena la clave privada de forma segura.
2. **Contenedor de Envío**: Este contenedor cifra los archivos utilizando una clave pública y los envía a través de SFTP.
3. **Contenedor de Recepción**: Este contenedor descifra los archivos utilizando la clave privada recuperada desde Vault.

## Estructura del Proyecto

```bash
├── Dockerfile-send            # Dockerfile para el contenedor de envío
├── Dockerfile-reception       # Dockerfile para el contenedor de recepción
├── docker-compose.yml         # Archivo de configuración para Docker Compose
├── Makefile                   # (Opcional) Automación de comandos
├── script-envio.sh            # Script que cifra y envía los archivos
├── script-recepcion.sh        # Script que recibe y descifra los archivos
├── documentos-electronicos-a-enviar
│   ├── FE-Consecutivo-2024.11.05.txt   # Archivo a cifrar y enviar
│   ├── NOM-Consecutivo-2024.11.05.txt  # Archivo a cifrar y enviar
└── README.md                         # Instrucciones y detalles del proyecto
```

## Configuración y Puesta en Marcha

1. Crear una Red en docker llamada red-archivos para que todos los contenedores puedan comunicarse.

```bash
docker network create red-archivos
```

2. Inicia el contenedor de Vault de `HashiCorp`, que estará conectado a la red red-archivos y expuesto en el puerto 1234.

```bash
docker run --cap-add=IPC_LOCK --network=red-archivos --name vault -p 1234:1234 -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:1234' hashicorp/vault
```

3. Verificar que Vault está Funcionando
Puedes verificar que Vault esté correctamente iniciado de dos maneras:
- A través de la interfaz web:
Ir a http://localhost:1234/.
- Usando curl desde la terminal:

```bash  
curl http://127.0.0.1:1234/v1/sys/health
```

La respuesta debe ser un JSON similar a este:

```JSON
	{
	  "initialized": true,
	  "sealed": false,
	  "standby": false,
	  "performance_standby": false,
	  "replication_performance_mode": "disabled",
	  "replication_dr_mode": "disabled",
	  "server_time_utc": 1697498239,
	  "version": "1.13.2",
	  "cluster_name": "vault-cluster-1234abcd",
	  "cluster_id": "abcd1234-5678-90ef-ghij-1234567890ab"
	}
```

4. Generar y Guardar las Claves en Vault
Genera las claves en tu entorno local y almacena la clave privada en Vault.
    
```bash
export VAULT_ADDR='http://127.0.0.1:1234'
export VAULT_TOKEN='myroot'

openssl genrsa -out proveedor_private_key.pem 2048
openssl rsa -pubout -in proveedor_private_key.pem -out proveedor_public_key.pem

# Leer la clave privada y guardarla en Vault
jq -n --arg value "$(cat proveedor_private_key.pem)" '{"data": {"value": $value}}' | \
curl --header "X-Vault-Token: $VAULT_TOKEN" \
     --header "Content-Type: application/json" \
     --request POST \
     --data @- \
     $VAULT_ADDR/v1/secret/data/proveedor_private_key
```

5. Verificar que la Clave Privada está Guardada en Vault

```bash
curl --header "X-Vault-Token: $VAULT_TOKEN" \
     $VAULT_ADDR/v1/secret/data/proveedor_private_key
```

6. **Iniciar los Contenedores de Envío y Recepción**: Inicia los contenedores usando docker-compose que deben estar conectados a la red red-archivos:

```bash
docker-compose up build
```

### Verificar la Transferencia de Archivos en el Contenedor de Recepción
1. Acceder al contenedores receptor:

```bash
docker exec -it servidor_sftp bash
```

2. Recuperar y Usar la Clave Privada en el Contenedor de Recepción

```bash
curl --header "X-Vault-Token: myroot" \
     --request GET \
     $VAULT_ADDR/v1/secret/data/proveedor_private_key | jq -r '.data.data.value' > /home/sftp-user/proveedor_private_key.pem
```

Nota: Instalar herramientas necesarias `apt-get update && apt-get install -y curl jq`

3. Extraer clave publica:

```bash
openssl pkey -in /home/sftp-user/proveedor_private_key.pem -out /home/sftp-user/proveedor_private_key_rsa.pem
openssl rsa -pubout -in /home/sftp-user/proveedor_private_key.pem -out /home/sftp-user/proveedor_public_key.pem
```

4. Descomprimir el archivo .ZIP que contiene los archivos cifrados.

```bash
unzip resultado_comprimido.zip
```

5. Descifrado de cada archivo .enc y restaurar la versión codificada en Unicode64.

```bash
openssl pkeyutl -decrypt -inkey /home/sftp-user/proveedor_private_key.pem -in FE-Consecutivo-2024.11.05.txt.enc -out FE-Consecutivo-2024.11.05.txt.unicode64 -pkeyopt rsa_padding_mode:pkcs1
openssl pkeyutl -decrypt -inkey /home/sftp-user/proveedor_private_key.pem -in NOM-Consecutivo-2024.11.05.txt.enc -out NOM-Consecutivo-2024.11.05.txt.unicode64 -pkeyopt rsa_padding_mode:pkcs1
```

6. Decodificar los Archivos de Unicode64 a UTF-8, usando `base64` y `iconv`

```bash
base64 -d FE-Consecutivo-2024.11.05.txt.unicode64 | iconv -f UTF-16 -t UTF-8 > FE-Consecutivo-2024.11.05.txt
base64 -d NOM-Consecutivo-2024.11.05.txt.unicode64 | iconv -f UTF-16 -t UTF-8 > NOM-Consecutivo-2024.11.05.txt
```
7. Verificación del Contenido de los Archivos.

```bash
cat FE-Consecutivo-2024.11.05.txt
cat NOM-Consecutivo-2024.11.05.txt
```

### Verificar la integridad de los archivos descifrados
Después de descifrar los archivos, se puede usar `sha256sum` para recalcular el hash del archivo descifrado y compararlo con el valor del archivo `.hash` que fue enviado.

```
sha256sum -c FE-Consecutivo-2024.11.05.txt.hash
sha256sum -c NOM-Consecutivo-2024.11.05.txt.hash
```

### Verificar la firma en el receptor
El receptor necesita la clave pública del remitente para verificar que la firma es válida. Usa el siguiente comando

Ejemplo
```
openssl dgst -sha256 -verify public_key.pem -signature archivo_firmado.sig archivo_original.txt
```

```
openssl dgst -sha256 -verify remitente_public_key.pem -signature FE-Consecutivo-2024.11.05.txt.sig FE-Consecutivo-2024.11.05.txt
openssl dgst -sha256 -verify remitente_public_key.pem -signature NOM-Consecutivo-2024.11.05.txt.sig NOM-Consecutivo-2024.11.05.txt
```

