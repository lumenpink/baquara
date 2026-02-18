#!/bin/bash

# --- Configurações de Pastas ---
# Definindo os caminhos que você pediu
STACKS_DIR="/data/stacks"
DOCKGE_DATA="/data/dockge"

echo "🚀 Iniciando setup do Homelab para a Lumen..."

# 1. Criar os diretórios na raiz /data
# Nota: Como /data fica na raiz, vamos precisar de permissão de superusuário (sudo)
echo "📂 Criando pastas em /data..."
sudo mkdir -p "$STACKS_DIR"
sudo mkdir -p "$DOCKGE_DATA"

# Ajustar permissões para garantir que o Docker consiga escrever lá
# (Assume que o usuário atual deve ser o dono. Se preferir root, pode remover essas linhas)
sudo chown -R $USER:$USER /data/stacks
sudo chown -R $USER:$USER /data/dockge

# 2. Verificar e criar volume de dados do Portainer (Banco de dados interno)
if [ "$(docker volume ls -q -f name=portainer_data)" ]; then
    echo "✅ Volume 'portainer_data' já existe."
else
    echo "📦 Criando volume 'portainer_data'..."
    docker volume create portainer_data
fi

# 3. Subir o Portainer
# - Apenas porta 9000 (HTTP)
# - Sem porta 8000 (Tunnel)
# - Sem porta 9443 (HTTPS)
echo "🚢 Subindo Portainer (HTTP puro na porta 9000)..."
docker run -d \
  -p 9000:9000 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# 4. Subir o Dockge
# - Mapeando seus stacks para /data/stacks
# - Dados persistentes em /data/dockge
echo "🛠️ Subindo Dockge (Porta 5001)..."
docker run -d \
  -p 5001:5001 \
  --name dockge \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$DOCKGE_DATA":/app/data \
  -v "$STACKS_DIR":/data/stacks \
  -e DOCKGE_STACKS_DIR=/data/stacks \
  louislam/dockge:latest

echo "---"
echo "✨ Instalação concluída!"
echo "📂 Stacks: $STACKS_DIR"
echo "🌐 Portainer: http://localhost:9000"
echo "🌐 Dockge:    http://localhost:5001"
