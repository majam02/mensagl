#!/bin/bash
#
# Mario Aja Moral
# Plantilla script para configurar el servidor CMS Wordpress


set -e
export DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
export DUCKDNS_SUBDOMAIN2="${DUCKDNS_SUBDOMAIN2}"
export EMAIL="${EMAIL}"
export RDS_ENDPOINT="${RDS_ENDPOINT}"
export wDBName="${wDBName}"
export DB_USERNAME="${DB_USERNAME}"
export DB_PASSWORD="${DB_PASSWORD}"


# Install LAMP
sudo apt update
sudo apt install -y apache2 mysql-client mysql-server php php-mysql

# Install WP CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Permissions for WordPress
sudo rm -rf /var/www/html/*
sudo chmod -R 755 /var/www/html
sudo chown -R www-data:www-data /var/www/html

# Download WordPress
sudo -u www-data -k -- wp core download --path=/var/www/html

# Check if RDS Works...
sleep 240
for i in {1..10}; do
  if sudo mysql -h "$RDS_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" &>/dev/null; then
    echo "MySQL is available!"
    break
  fi
  echo "Waiting for MySQL to be available... Attempt $i"
  sleep 10
done

# Config after WordPress Installation (RDS MySQL user and Database)
sudo mysql -h "${RDS_ENDPOINT}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${wDBName};"
sudo mysql -h "${RDS_ENDPOINT}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';"
sudo mysql -h "${RDS_ENDPOINT}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${wDBName}.* TO '${DB_USERNAME}'@'%';"
sudo mysql -h "${RDS_ENDPOINT}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "FLUSH PRIVILEGES;"

sudo rm -rf /var/www/html/wp-config.php

# Configure WordPress automatic
sleep 120
sudo -u www-data -k -- wp core config --dbname="${wDBName}" --dbuser="${DB_USERNAME}" --dbpass="${DB_PASSWORD}" --dbhost="${RDS_ENDPOINT}" --dbprefix=wp_ --path=/var/www/html
sudo -u www-data -k -- wp core install --url="${DUCKDNS_SUBDOMAIN2}.duckdns.org" --title="MensAGL" --admin_user="${DB_USERNAME}" --admin_password="${DB_PASSWORD}" --admin_email="${EMAIL}" --path=/var/www/html
sudo -u www-data -k -- wp option update home https://${DUCKDNS_SUBDOMAIN2} --path=/var/www/html
sudo -u www-data -k -- wp option update siteurl https://${DUCKDNS_SUBDOMAIN2} --path=/var/www/html

# Install WordPress Plugins
# "wps-hide-login"
PLUGINS=("supportcandy" "updraftplus" "user-registration" "wp-mail-smtp")
for PLUGIN in "${PLUGINS[@]}"; do
  sudo -u www-data -k -- wp plugin install "$PLUGIN" --activate --path=/var/www/html
done

# wp-config.php to fix redirection nginx (experimental)
cat <<WP_CONFIG >> /var/www/html/wp-config.php
if(isset(\$_SERVER['HTTP_X_FORWARDED_FOR'])) {
    \$list = explode(',', \$_SERVER['HTTP_X_FORWARDED_FOR']);
    \$_SERVER['REMOTE_ADDR'] = \$list[0];
}
\$_SERVER['HTTP_HOST'] = '${DUCKDNS_SUBDOMAIN2}.duckdns.org';
\$_SERVER['REMOTE_ADDR'] = '${DUCKDNS_SUBDOMAIN2}.duckdns.org';
\$_SERVER['SERVER_ADDR'] = '${DUCKDNS_SUBDOMAIN2}.duckdns.org';
WP_CONFIG

sed -i "s/\${DUCKDNS_SUBDOMAIN2}/${DUCKDNS_SUBDOMAIN2}/g" /var/www/html/wp-config.php

# Modules for WordPress SSL
sudo a2enmod ssl headers rewrite
sudo a2ensite default-ssl
sudo a2dissite 000-default
sudo systemctl restart apache2

echo "WordPress setup completed successfully!"