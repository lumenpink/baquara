# Redes nodelo simples 
docker network create public_net
docker network create --internal tunnel_conn
docker network create --internal internal_net

exit





# Redes de Interface (Onde o Proxy alcança os Apps)
docker network create proxy_auth
docker network create proxy_ai
docker network create proxy_mail
docker network create proxy_storage
docker network create proxy_apps

# Túneis de Identidade (Bunker)
docker network create --internal net_auth_backend

# Túneis de Inteligência (Cérebro - Hub and Spoke)
docker network create --internal net_ui_ollama
docker network create --internal net_ui_ears
docker network create --internal net_ui_voice

# Túneis de Dados (Storage)
docker network create --internal net_photos_db
docker network create --internal net_photos_cache
docker network create --internal net_cloud_db
