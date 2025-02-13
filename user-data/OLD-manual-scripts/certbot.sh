#!/bin/bash
#
# Mario Aja Moral
#
# OLD SCRIPT
#
# Este script es una version antigua para la creacion de los certificados
# Aun sigue funcionando, pero esta en deshuso

printf "%s" "Insert Domain Name: "
read domain
printf "%s" "Insert Email: "
read email


# Update package list and install Certbot
sudo apt update -y
sudo apt install -y certbot

# Obtain SSL certificate in standalone mode (non-interactive)
sudo certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email "${email}" \
  -d "${domain}"


sudo chmod 755 /etc/letsencrypt/archive/
sudo chmod 755 /etc/letsencrypt/archive/${domain}/
sudo chmod 755 /etc/letsencrypt/live/
sudo chmod 755 /etc/letsencrypt/live/${domain}/
