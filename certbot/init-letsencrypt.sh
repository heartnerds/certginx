#!/bin/bash

# EMAIL: Adding a valid address is strongly recommended
# STAGING: Set to 1 if you're testing your setup to avoid hitting request limits

DOMAINS=("domain.com" "subdomain.domain.com")
EMAIL=""
STAGING=0
RSA_KEY_SIZE=4096

# DO NOT CHANGE
DATA_PATH="$( cd "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

function check_docker_compose () {
  [ -x "$(command -v docker-compose)" ] || { echo 'Error: docker-compose is not installed.' >&2; exit 1; }
}

function check_confirmation () {
  read -p "Data will be erased for $DOMAINS. Continue? (y/N) " decision
  [ "$decision" != "Y" ] && [ "$decision" != "y" ] && exit
}

function create_tls_parameters () {
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$DATA_PATH/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$DATA_PATH/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$DATA_PATH/conf/ssl-dhparams.pem"
  echo
}

function create_dummy_certificates () {
  echo "### Creating dummy certificate for $DOMAINS ..."
  path="/etc/letsencrypt/live/$DOMAINS"
  mkdir -p "$DATA_PATH/conf/live/$DOMAINS"
  docker-compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1\
      -keyout '$path/privkey.pem' \
      -out '$path/fullchain.pem' \
      -subj '/CN=localhost'" certbot
  echo
}

function start_nginx () {
  echo "### Starting nginx ..."
  docker-compose up --force-recreate -d nginx
  echo
}

function remove_dummy_certificates () {
  echo "### Deleting dummy certificate for $DOMAINS ..."
  docker-compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/$DOMAINS && \
    rm -Rf /etc/letsencrypt/archive/$DOMAINS && \
    rm -Rf /etc/letsencrypt/renewal/$DOMAINS.conf" certbot
  echo
}

function request_certificates () {
  echo "### Requesting Let's Encrypt certificate for $DOMAINS ..."
  #Join $DOMAINS to -d args
  domain_args=""
  for domain in "${DOMAINS[@]}"; do
    domain_args="$domain_args -d $domain"
  done

  # Select appropriate email arg
  case "$EMAIL" in
    "") email_arg="--register-unsafely-without-email" ;;
    *) email_arg="--email $EMAIL" ;;
  esac

  # Enable staging mode if needed
  [ $STAGING != "0" ] && staging_arg="--staging"

  docker-compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      $domain_args \
      --rsa-key-size $RSA_KEY_SIZE \
      --agree-tos \
      --force-renewal" certbot
  echo
}

function reload_nginx () {
  echo "### Reloading nginx ..."
  docker-compose exec nginx nginx -s reload
}


function main () {

  check_confirmation

  check_docker_compose

  create_tls_parameters

  create_dummy_certificates

  start_nginx

  remove_dummy_certificates

  request_certificates

  reload_nginx
  
}

main "${@}"
