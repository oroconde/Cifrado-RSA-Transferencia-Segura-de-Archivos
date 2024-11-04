# Nombre de las imágenes y contenedores
IMAGE_SEND = mi-proyecto/contenedor-send:local
IMAGE_RECEPTION = mi-proyecto/servidor-sftp:local
CONTAINER_SEND = contenedor_send
CONTAINER_RECEPTION = servidor_sftp
VAULT_CONTAINER = vault

# Comandos para Docker Compose
DOCKER_COMPOSE = docker-compose

# Construir los contenedores
build:
	$(DOCKER_COMPOSE) build

# Iniciar los contenedores
up:
	$(DOCKER_COMPOSE) up -d

# Iniciar los contenedores y mostrar logs
up-logs:
	$(DOCKER_COMPOSE) up --build

# Ver logs del contenedor de envío
logs-send:
	docker logs $(CONTAINER_SEND)

# Ver logs del contenedor de recepción
logs-reception:
	docker logs $(CONTAINER_RECEPTION)

# Ver logs del contenedor Vault
logs-vault:
	docker logs $(VAULT_CONTAINER)

# Detener y eliminar los contenedores, redes y volúmenes
down:
	$(DOCKER_COMPOSE) down

# Limpiar imágenes y contenedores
clean:
	$(DOCKER_COMPOSE) down --rmi all --volumes --remove-orphans

# Reconstruir imágenes y reiniciar el entorno
rebuild: clean build up

# Ejecutar un shell interactivo en el contenedor de recepción
shell-reception:
	docker exec -it $(CONTAINER_RECEPTION) /bin/bash

# Ejecutar un shell interactivo en el contenedor Vault
shell-vault:
	docker exec -it $(VAULT_CONTAINER) /bin/sh

# Logs del contenedor de envío
logs-send:
	docker logs $(CONTAINER_SEND)

# Logs del contenedor de recepción
logs-reception:
	docker logs $(CONTAINER_RECEPTION)

# Explicación de las tareas del Makefile:
# build: Construye las imágenes de los contenedores definidos en el docker-compose.yml.
# up: Inicia los contenedores en segundo plano.
# up-logs: Inicia los contenedores y muestra los logs en tiempo real.
# logs-send: Muestra los logs del contenedor de envío.
# logs-reception: Muestra los logs del contenedor de recepción.
# logs-vault: Muestra los logs del contenedor de Vault.
# down: Detiene y elimina los contenedores, redes y volúmenes creados por Docker Compose.
# clean: Limpia los contenedores e imágenes, eliminando todo lo que se haya creado.
# ps: Muestra el estado actual de los contenedores.
# rebuild: Limpia el entorno y reconstruye todas las imágenes, reiniciando los contenedores.
# shell-reception, shell-vault: Abren un shell interactivo dentro de los contenedores correspondientes para fines de depuración.