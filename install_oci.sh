#!/bin/bash

# 1. Criar Swap de 2GB (Essencial para não travar com 512MB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 2. Limpeza profunda (Remover Snaps e serviços pesados)
sudo apt purge snapd -y
sudo apt autoremove --purge -y
sudo apt update && sudo apt upgrade -y

# 3. Instalar Dependências e HAProxy
sudo apt install -y curl wget apt-transport-https haproxy

# 4. Instalar Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 5.  Ativar IP Forwarding para Tailscale
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# 6. Corrigir UDP para Tailscale (Importante para conexões estáveis)
printf '#!/bin/sh\n\nethtool -K $(ip -o route get 8.8.8.8 | cut -f 5 -d " ") rx-udp-gro-forwarding on rx-gro-list off\n' | sudo tee /etc/network/if-up.d/50-tailscale
sudo chmod 755 /etc/network/if-up.d/50-tailscale
sudo /etc/network/if-up.d/50-tailscale
# Verifica se rx-udp-gro-forwarding está ativado
iface=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
sudo ethtool -k "$iface" | grep -q 'rx-udp-gro-forwarding: on'
if [ $? -eq 0 ]; then
	echo '✅ rx-udp-gro-forwarding ativado com sucesso.'
else
	echo '❌ Falha ao ativar rx-udp-gro-forwarding.'
fi


echo "------------------------------------------------"
echo "✅ Instalação concluída!"
echo "Tailscale: Rode 'sudo tailscale up' para logar."
echo "HAProxy: Configurações em /etc/haproxy/haproxy.cfg"
echo "------------------------------------------------"