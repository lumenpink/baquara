#!/bin/bash
# Baquara Installer V23 (The Wiper)
# Features: Full System Wipe/Reset Capability, Auto-Config, Safety Checks

# --- Configurações ---
APP_NAME="Baquara"
GIT_REPO="https://tildegit.org/lumen/baquara.git"
BASE_DIR="/data"
CREDENTIALS_FILE="/root/baquara_credentials.txt"
SECRETS_FILE="$BASE_DIR/.system_secrets"
CONFIG_FILE="$BASE_DIR/.baquara.conf"
SILENT_MODE=false
WIPE_MODE=false

# Cores
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# Logs
log() { echo -e "${BLUE}[$APP_NAME]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCESSO]${NC} $1"; }
error() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# Verifica Root
if [ "$EUID" -ne 0 ]; then error "Execute como root (sudo)."; fi

# Identifica o Usuário 1000
HUMAN_USER=$(id -nu 1000 2>/dev/null)
if [ -z "$HUMAN_USER" ]; then HUMAN_USER="lumen"; fi 
HUMAN_HOME=$(eval echo "~$HUMAN_USER")

# --- TRATAMENTO DE ARGUMENTOS ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --name) APP_NAME="$2"; shift ;;
        --silent) SILENT_MODE=true ;;
        --wipe) WIPE_MODE=true ;; 
        *) echo "Parametro desconhecido: $1"; exit 1 ;;
    esac
    shift
done

# ==============================================================================
# FUNÇÃO DE WIPE (EXORCISMO COMPLETO)
# ==============================================================================
if [ "$WIPE_MODE" = true ]; then
    clear
    echo -e "${RED}======================================================${NC}"
    echo -e "${RED}   PERIGO: MODO DE LIMPEZA TOTAL (WIPE) ATIVADO   ${NC}"
    echo -e "${RED}======================================================${NC}"
    echo -e "Isso irá DELETAR PERMANENTEMENTE:"
    echo -e "1. Todos os dados em $BASE_DIR"
    echo -e "2. Todos os containers, volumes e redes do Docker"
    echo -e "3. O cofre de senhas em $CREDENTIALS_FILE"
    echo -e "4. Instalações do Zotero/Obsidian"
    echo -e "5. Configurações salvas"
    echo ""
    echo -n "Digite 'SIM' para confirmar a destruição: "
    read CONFIRM
    
    if [ "$CONFIRM" != "SIM" ]; then
        error "Cancelado. Nada foi apagado."
    fi

    log "Iniciando protocolo de destruição..."

    # 1. Docker Kill
    log "Parando e removendo containers..."
    if [ -n "$(docker ps -aq)" ]; then
        docker stop $(docker ps -aq) 2>/dev/null
        docker rm $(docker ps -aq) 2>/dev/null
    fi
    
    log "Limpando volumes e redes..."
    docker network prune -f >/dev/null 2>&1
    docker volume prune -f >/dev/null 2>&1
    # Opcional: docker system prune -a -f (Isso apaga imagens também, demora pra baixar de novo)

    # 2. Arquivos de Sistema
    log "Removendo arquivos de dados e configurações..."
    rm -rf "$BASE_DIR"
    rm -f "$CREDENTIALS_FILE"
    
    # 3. Apps e Links
    log "Removendo aplicações..."
    rm -rf /opt/zotero
    rm -f /usr/bin/zotero
    rm -f /usr/share/applications/zotero.desktop
    
    # 4. Repositórios Apt (Opcional, mas deixa limpo)
    log "Limpando fontes do Apt..."
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.gpg
    rm -f /etc/apt/sources.list.d/vscode.list
    rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
    rm -f /etc/apt/sources.list.d/zotero.list
    
    # 5. SSH Keys (Opcional - Pergunta?)
    # Por segurança, NÃO apago chaves SSH globais para não bloquear seu acesso ao servidor se estiver remoto.
    
    success "Sistema limpo! Pronto para uma instalação 'fresh'."
    exit 0
fi

# ==============================================================================
# INÍCIO DA INSTALAÇÃO NORMAL
# ==============================================================================

# --- 0. PREPARAÇÃO DO SISTEMA ---
# Garante que não temos lixo de tentativas anteriores (Mini-Wipe seguro)
rm -f /etc/apt/sources.list.d/{docker.list,vscode.list,nvidia-container-toolkit.list,zotero.list} 2>/dev/null

# Reset Sources se necessário
if ! grep -q "non-free-firmware" /etc/apt/sources.list; then
    log "Configurando repositórios Debian..."
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
    apt-get update -qq
fi

# Instalação Base
log "Instalando dependências..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl wget gnupg ca-certificates lsb-release \
    apt-transport-https git jq micro htop rsync whiptail openssh-client \
    linux-headers-amd64 build-essential firmware-linux python3 python3-bcrypt >/dev/null

# --- 1. CONFIGURAÇÃO ---
if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi

save_config() {
    echo "APP_NAME=\"$APP_NAME\"" > "$CONFIG_FILE"
    echo "DOMAIN=\"$DOMAIN\"" >> "$CONFIG_FILE"
    echo "EMAIL_ADMIN=\"$EMAIL_ADMIN\"" >> "$CONFIG_FILE"
    echo "EMAIL_GIT=\"$EMAIL_GIT\"" >> "$CONFIG_FILE"
    echo "GIT_NAME=\"$GIT_NAME\"" >> "$CONFIG_FILE"
    echo "CF_TOKEN=\"$CF_TOKEN\"" >> "$CONFIG_FILE"
    echo "CHOICES=\"$CHOICES\"" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

if [ "$SILENT_MODE" = false ]; then
    [ -z "$APP_NAME" ] && APP_NAME="Baquara"
    NEW_NAME=$(whiptail --inputbox "Host Name:" 10 60 "$APP_NAME" 3>&1 1>&2 2>&3)
    [ ! -z "$NEW_NAME" ] && APP_NAME="$NEW_NAME"
    [ -z "$GIT_NAME" ] && GIT_NAME=$(whiptail --inputbox "Git Name:" 10 60 "Admin User" 3>&1 1>&2 2>&3)
    [ -z "$EMAIL_GIT" ] && EMAIL_GIT=$(whiptail --inputbox "Git Email:" 10 60 "git@example.com" 3>&1 1>&2 2>&3)
    [ -z "$EMAIL_ADMIN" ] && EMAIL_ADMIN=$(whiptail --inputbox "Admin Email:" 10 60 "$EMAIL_GIT" 3>&1 1>&2 2>&3)
    [ -z "$DOMAIN" ] && DOMAIN=$(whiptail --inputbox "Domínio:" 10 60 "lohn.in" 3>&1 1>&2 2>&3)

    if [ -z "$CHOICES" ]; then
        CHOICES=$(whiptail --title "Instalação" --checklist "Módulos:" 20 78 10 \
        "CORE" "Base (Docker/Nvidia)" ON "HOMELAB" "Servidor" ON "UNIV" "Apps Univ" ON "REMOTE" "Acesso Remoto" ON "DEV" "Dev Tools" ON 3>&1 1>&2 2>&3)
        CHOICES=$(echo $CHOICES | sed 's/"//g')
    fi
    
    if [[ "$CHOICES" == *"HOMELAB"* ]] && [ -z "$CF_TOKEN" ]; then
        CF_TOKEN=$(whiptail --passwordbox "Cloudflare Token:" 10 60 3>&1 1>&2 2>&3)
    fi
    save_config
else
    if [ -z "$EMAIL_GIT" ]; then error "Faltam variáveis para silent mode."; fi
fi

# --- 2. SEGREDOS ---
mkdir -p "$BASE_DIR"
LDAP_BASE_DN="dc=$(echo $DOMAIN | sed 's/\./,dc=/g')"

if [ ! -f "$CREDENTIALS_FILE" ]; then
    PASS_PORTAINER=$(openssl rand -base64 16)
    PASS_LLDAP=$(openssl rand -base64 16)
    PASS_MYSQL=$(openssl rand -hex 16)
    HASH_PORTAINER=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$PASS_PORTAINER', bcrypt.gensalt()).decode())")
    
    cat <<EOF > "$CREDENTIALS_FILE"
==================================================
   COFRE DE SENHAS (Salvo em $(date))
==================================================
[PORTAINER] admin / $PASS_PORTAINER
[LLDAP]     admin / $PASS_LLDAP
[DATABASE]  root  / $PASS_MYSQL
==================================================
EOF
    chmod 600 "$CREDENTIALS_FILE"
else
    HASH_PORTAINER=$(grep "Hash:" "$CREDENTIALS_FILE" | cut -d' ' -f2 2>/dev/null)
    if [ -z "$HASH_PORTAINER" ]; then 
        PASS_PORTAINER=$(openssl rand -base64 16)
        HASH_PORTAINER=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$PASS_PORTAINER', bcrypt.gensalt()).decode())")
    fi
    PASS_LLDAP=$(grep -A 3 "\[LLDAP\]" "$CREDENTIALS_FILE" | grep "Pass:" | awk '{print $2}' | tr -d ' ')
    PASS_MYSQL=$(grep -A 2 "\[DATABASE\]" "$CREDENTIALS_FILE" | grep "Root Pass:" | awk '{print $3}' | tr -d ' ')
fi

if [ ! -f "$SECRETS_FILE" ]; then
    JWT_SECRET=$(openssl rand -base64 32)
    HA_API_KEY=$(openssl rand -hex 32)
    SESSION_SECRET=$(openssl rand -hex 32)
    WEBDAV_USER="baquara"
    WEBDAV_PASS=$(openssl rand -hex 12)
    
    cat <<EOF > "$SECRETS_FILE"
JWT_SECRET="$JWT_SECRET"
HA_API_KEY="$HA_API_KEY"
MYSQL_ROOT_PASS="$PASS_MYSQL"
SESSION_SECRET="$SESSION_SECRET"
WEBDAV_USER="$WEBDAV_USER"
WEBDAV_PASS="$WEBDAV_PASS"
EOF
else
    source "$SECRETS_FILE"
fi

# --- 3. GIT & SSH ---
GIT_FULL_NAME="$GIT_NAME ($APP_NAME)"
setup_git_user() {
    local T_USER=$1; local T_HOME=$2
    sudo -u $T_USER git config --global user.name "$GIT_FULL_NAME"
    sudo -u $T_USER git config --global user.email "$EMAIL_GIT"
    sudo -u $T_USER git config --global gpg.format ssh
    sudo -u $T_USER git config --global commit.gpgsign true
    sudo -u $T_USER git config --global init.defaultBranch main
    local K="$T_HOME/.ssh/id_ed25519"
    if [ ! -f "$K" ]; then
        sudo -u $T_USER mkdir -p "$T_HOME/.ssh"
        sudo -u $T_USER chmod 700 "$T_HOME/.ssh"
        sudo -u $T_USER ssh-keygen -t ed25519 -C "$EMAIL_GIT" -f "$K" -N "" -q
    fi
    sudo -u $T_USER git config --global user.signingkey "$K.pub"
}
setup_git_user "root" "/root"
setup_git_user "$HUMAN_USER" "$HUMAN_HOME"

if [ ! -f "$BASE_DIR/.ssh_viewed" ] || [ "$SILENT_MODE" = false ]; then
    clear
    echo -e "${YELLOW}--- CHAVES SSH (Adicione no Git Server) ---${NC}"
    echo -e "${CYAN}Root:${NC}"; cat /root/.ssh/id_ed25519.pub
    echo -e "\n${CYAN}User ($HUMAN_USER):${NC}"; cat $HUMAN_HOME/.ssh/id_ed25519.pub
    echo -e "${YELLOW}-------------------------------------------${NC}"
    if [ "$SILENT_MODE" = false ]; then read -p "Enter para continuar..."; fi
    touch "$BASE_DIR/.ssh_viewed"
fi

# --- 4. CORE ---
if [[ $CHOICES == *"CORE"* ]]; then
    if ! command -v docker &> /dev/null; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    usermod -aG docker "$HUMAN_USER"
    
    if ! dpkg -s nvidia-container-toolkit &> /dev/null; then
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg --yes
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        apt-get update && apt-get install -y nvidia-container-toolkit
        nvidia-ctk runtime configure --runtime=docker || true
        systemctl restart docker || true
    fi
fi

# --- 5. HOMELAB ---
if [[ $CHOICES == *"HOMELAB"* ]]; then
    log "Configurando Homelab..."
    git config --global --add safe.directory "$BASE_DIR"
    
    if [ ! -d "$BASE_DIR/.git" ]; then
        git clone "$GIT_REPO" "$BASE_DIR" 2>/dev/null || {
            cd "$BASE_DIR"; git init; git remote add origin "$GIT_REPO"; git fetch --all; git reset --hard origin/main; git branch --set-upstream-to=origin/main main
        }
    else
        cd "$BASE_DIR"; git fetch --all; git reset --hard origin/main
    fi

    mkdir -p "$BASE_DIR"/{dockge,homepage_config,authelia_config,npm_data,stacks}

    # Auto-Generators
    cat <<EOF > "$BASE_DIR/homepage_config/services.yaml"
---
- Infraestrutura:
    - Portainer: { icon: portainer.png, href: http://portainer:9000, description: Manager }
    - Dockge: { icon: dockge.png, href: http://dockge:5001, description: Stacks }
    - Proxy: { icon: nginx-proxy-manager.png, href: http://proxy:81, description: NPM }
- Apps:
    - Webmail: { icon: roundcube.png, href: https://mail.$DOMAIN }
    - Zotero: { icon: nextcloud.png, href: https://dav.$DOMAIN }
EOF

    if [ ! -f "$BASE_DIR/authelia_config/configuration.yml" ]; then
        cat <<EOF > "$BASE_DIR/authelia_config/configuration.yml"
---
server: { host: 0.0.0.0, port: 9091 }
log: { level: info }
jwt: { secret: '$JWT_SECRET' }
session: { secret: '$SESSION_SECRET', domain: '$DOMAIN' }
storage: { local: { path: /config/db.sqlite3 } }
authentication_backend:
  ldap:
    url: ldap://ldap
    base_dn: $LDAP_BASE_DN
    user: uid=admin,ou=people,$LDAP_BASE_DN
    password: '$PASS_LLDAP'
access_control:
  default_policy: deny
  rules: [{ domain: "*.$DOMAIN", policy: one_factor }]
EOF
    fi

    find "$BASE_DIR/stacks" -mindepth 1 -maxdepth 1 -type d | while read stack; do
        cat <<EOF > "$stack/.env"
APP_NAME=$APP_NAME
DOMAIN=$DOMAIN
EMAIL=$EMAIL_ADMIN
CF_TOKEN=$CF_TOKEN
JWT_SECRET=$JWT_SECRET
HA_API_KEY=$HA_API_KEY
MYSQL_ROOT_PASS=$PASS_MYSQL
LLDAP_ADMIN_PASSWORD=$PASS_LLDAP
LDAP_BASE_DN=$LDAP_BASE_DN
SESSION_SECRET=$SESSION_SECRET
WEBDAV_USER=$WEBDAV_USER
WEBDAV_PASS=$WEBDAV_PASS
CONFIG_DIR=$BASE_DIR
EOF
    done

    docker network create public_net >/dev/null 2>&1 || true
    docker network create --internal tunnel_conn >/dev/null 2>&1 || true
    docker network create --internal internal_net >/dev/null 2>&1 || true

    if ! docker ps | grep -q portainer; then
        docker run -d -p 9000:9000 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
        portainer/portainer-ce:latest --admin-password "$HASH_PORTAINER"
    fi
    if ! docker ps | grep -q dockge; then
        docker run -d -p 5001:5001 --name dockge --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock -v "$BASE_DIR/dockge":/app/data \
        -v "$BASE_DIR/stacks":/data/stacks -e DOCKGE_STACKS_DIR=/data/stacks \
        louislam/dockge:latest
    fi

    log "Iniciando Stacks..."
    find "$BASE_DIR/stacks" -mindepth 1 -maxdepth 1 -type d | while read stack; do
        if [ -f "$stack/compose.yml" ]; then
            log " -> $(basename "$stack")..."
            (cd "$stack" && docker compose up -d)
        fi
    done
    
    sleep 10
    docker exec -d ollama ollama pull llama3 2>/dev/null || true
    chown -R "$HUMAN_USER":"$HUMAN_USER" "$BASE_DIR"
fi

# --- 6. APPS ---
if [[ $CHOICES == *"UNIV"* ]]; then
    if [ ! -f /usr/bin/zotero ]; then
        log "Instalando Zotero..."
        wget -qO /tmp/zotero.tar.bz2 "https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64&mode=tarball"
        rm -rf /opt/zotero; tar -xjf /tmp/zotero.tar.bz2 -C /opt/
        mv /opt/Zotero_linux-x86_64 /opt/zotero 2>/dev/null || true
        /opt/zotero/set_launcher_icon
        ln -sf /opt/zotero/zotero.desktop /usr/share/applications/zotero.desktop
        ln -sf /opt/zotero/zotero /usr/bin/zotero
    fi
    if ! dpkg -s obsidian &> /dev/null; then
        OBS_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r '.assets[] | select(.name | endswith("_amd64.deb")) | .browser_download_url')
        wget -qO /tmp/obsidian.deb "$OBS_URL" && apt-get install -y /tmp/obsidian.deb && rm /tmp/obsidian.deb
    fi
fi

if [[ $CHOICES == *"DEV"* ]]; then
    if ! command -v code &> /dev/null; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
        rm -f packages.microsoft.gpg
        apt-get update && apt-get install -y code fonts-firacode
    fi
fi

if [[ $CHOICES == *"REMOTE"* ]]; then
    if ! dpkg -s chrome-remote-desktop &> /dev/null; then
        log "Instalando Remote Access..."
        wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && apt-get install -y /tmp/chrome.deb && rm /tmp/chrome.deb
        wget -O /tmp/crd.deb https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
        apt-get install -y /tmp/crd.deb || apt-get install -f -y
        rm /tmp/crd.deb
    fi
    if ! dpkg -s sunshine &> /dev/null; then
        SUN_URL=$(curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest | jq -r '.assets[] | select(.name | endswith("debian-bookworm_amd64.deb")) | .browser_download_url')
        wget -O /tmp/sun.deb "$SUN_URL" && apt-get install -y /tmp/sun.deb && rm /tmp/sun.deb
        echo 'KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"' > /etc/udev/rules.d/85-sunshine-input.rules
        udevadm control --reload-rules && udevadm trigger
    fi
fi

# Updater Script
cat << EOF > /usr/local/bin/baquara-updater.sh
#!/bin/bash
pgrep -x "sunshine" && exit 0; pgrep -x "obsidian" && exit 0; pgrep -x "code" && exit 0 
apt-get update && apt-get dist-upgrade -y && apt-get autoremove -y
date +%s > /var/log/baquara_last_run
EOF
chmod +x /usr/local/bin/baquara-updater.sh
(crontab -l 2>/dev/null | grep -v "baquara-updater"; echo "0 * * * * /usr/local/bin/baquara-updater.sh") | crontab -

success "Operação Concluída!"
echo -e "${CYAN}---------------------------------------------${NC}"
echo -e "WebDAV: $WEBDAV_USER / $WEBDAV_PASS"
echo -e "Senhas: $CREDENTIALS_FILE"
echo -e "${RED}REINICIE A SESSÃO PARA O DOCKER FUNCIONAR SEM SUDO!${NC}"
echo -e "${CYAN}---------------------------------------------${NC}"bvvvvvv