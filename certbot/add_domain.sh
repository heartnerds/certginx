#!/bin/sh

# EMAIL: Adding a valid address is strongly recommended
# STAGING: Set to 1 if you're testing your setup to avoid hitting request limits

DOMAINS="domain.com subdomain.domain.com"
EMAIL=""
STAGING=0
RSA_KEY_SIZE=4096

# DO NOT CHANGE
SCRIPT_PATH="$( cd "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

ERROR () {
  echo "\033[0;31m\033[1m!! ${1} !! \033[0m\n"
  exit 1
}

PRINT () {
  echo "\n > $1"
}

check_confirmation () {
  read -p "Data will be erased for ${DOMAINS}. Continue? (y/N) " decision
  [ "$decision" != "Y" ] && [ "$decision" != "y" ] && exit
}

check_docker_compose () {
  [ -x "$(command -v docker compose)" ] || ERROR "docker compose is not installed"
  stop_docker
}

create_tls_parameters () {
  PRINT "Downloading recommended TLS parameters ..."
  mkdir -p "$SCRIPT_PATH/conf" \
    && curl -f -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$SCRIPT_PATH/conf/options-ssl-nginx.conf" \
    && curl -f -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$SCRIPT_PATH/conf/ssl-dhparams.pem" \
    || ERROR "Unable to download recommended TLS parameters"
}

create_dummy_certificates () {
  PRINT "Creating dummy certificate for ${DOMAINS} ..."
  mkdir -p "$SCRIPT_PATH/conf/live/${DOMAINS%% *}"
  docker compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1\
      -keyout '/etc/letsencrypt/live/${DOMAINS%% *}/privkey.pem' \
      -out '/etc/letsencrypt/live/${DOMAINS%% *}/fullchain.pem' \
      -subj '/CN=localhost'" certbot \
    || ERROR "Unable to create dummy certificates"
}

start_nginx () {
  PRINT "Starting nginx ..."
  docker compose up --force-recreate -d nginx
  [ $(docker container inspect -f '{{.State.Running}}' "certginx_nginx") = "true" ] \
    || ERROR "Unbale to start nginx (check your configuration)"
}

remove_dummy_certificates () {
  PRINT "Deleting dummy certificate for ${DOMAINS} ..."
  docker compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/${DOMAINS%% *} && \
    rm -Rf /etc/letsencrypt/archive/${DOMAINS%% *} && \
    rm -Rf /etc/letsencrypt/renewal/${DOMAINS%% *}.conf" certbot \
    || ERROR "Unable to delete dummy certificates"
}

request_certificates () {
  PRINT "Requesting Let's Encrypt certificate for ${DOMAINS} ..."

  domain_args=""
  for domain in ${DOMAINS}; do
    domain_args="${domain_args} -d ${domain}"
  done

  [ $EMAIL = "" ] \
    && email_arg="--register-unsafely-without-email" \
    || email_arg="--email $EMAIL"

  [ $STAGING != "0" ] && staging_arg="--staging"

  docker compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      $domain_args \
      --rsa-key-size $RSA_KEY_SIZE \
      --agree-tos \
      --force-renewal" certbot \
    || ERROR "Unable to request certificates"
}

stop_docker () {
  PRINT "Stopping docker compose ..."
  docker compose down
}


check_confirmation

check_docker_compose

create_tls_parameters

create_dummy_certificates

start_nginx

remove_dummy_certificates

request_certificates

stop_docker
