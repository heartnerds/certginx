#!/bin/bash

#
# DO NOT CHANGE THE CODE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
#
source .env

DOMAINS=""
MAIL=""
STAGING=false
CERTIFICATES_PATH=${CERTIFICATES_PATH:-.certificates}
RSA_KEY_SIZE=${RSA_KEY_SIZE:-4096}

function ERROR() {
  echo -e "\033[0;31m\033[1m!! ${1} !! \033[0m\n"
  exit 1
}

function PRINT() {
  echo -e "\n > $1"
}

function stop_docker() {
  PRINT "Stopping docker compose ..."
  docker compose down
}

function update_tls() {
  PRINT "Downloading recommended TLS parameters ..."
  mkdir -p "${CERTIFICATES_PATH}/conf" &&
    curl -f -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf >"$CERTIFICATES_PATH/conf/options-ssl-nginx.conf" &&
    curl -f -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem >"$CERTIFICATES_PATH/conf/ssl-dhparams.pem" ||
    ERROR "Unable to download recommended TLS parameters"
  PRINT "TLS parameters updated successfully"
}

function create_certificate() {
  stop_docker

  update_tls

  create_self_signed_certificate

  PRINT "Starting nginx ..."
  docker compose up --force-recreate -d nginx
  [[ $(docker container inspect -f '{{.State.Running}}' "certginx_nginx") = "true" ]] ||
    ERROR "Unbale to start nginx (check your configuration)"

  remove_certificates

  PRINT "Requesting Let's Encrypt certificate for ${DOMAINS} ..."
  local domain_args=""
  for domain in ${DOMAINS}; do
    domain_args="${domain_args} -d ${domain}"
  done

  [[ ${EMAIL} = "" ]] &&
    email_arg="--register-unsafely-without-email" ||
    email_arg="--email $EMAIL"

  [[ "$STAGING" != false ]] && staging_arg="--staging"

  docker compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      $domain_args \
      --rsa-key-size $RSA_KEY_SIZE \
      --agree-tos \
      --force-renewal" certbot ||
    ERROR "Unable to request certificates"

  stop_docker
}

function create_self_signed_certificate() {
  PRINT "Creating self signed certificate for ${DOMAINS%% *} ..."

  mkdir -p "${CERTIFICATES_PATH}/conf/live/${DOMAINS%% *}"
  docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:${RSA_KEY_SIZE} -days 3650 \
      -keyout '/etc/letsencrypt/live/${DOMAINS%% *}/privkey.pem' \
      -out '/etc/letsencrypt/live/${DOMAINS%% *}/fullchain.pem' \
      -subj '/CN=localhost'" certbot ||
    echo "\033[0;31m\033[1m!! Unable to create dummy certificates !! \033[0m\n"

  PRINT "Certificate for ${DOMAINS%% *} created successfully"
}

function remove_certificates() {
  PRINT "Removing Let's Encrypt certificate for ${DOMAINS%% *} ..."

  local output=$(docker compose run --rm --entrypoint "certbot certificates" certbot 2>&1 | grep -E "Certificate Name:.*${DOMAINS%% *}")
  if [[ ! -z "${output}" ]]; then
    docker compose run --rm --entrypoint "\
      certbot delete --cert-name ${DOMAINS%% *}" certbot ||
      ERROR "Unable to remove ${DOMAINS%% *}"
  fi

  docker compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/${DOMAINS%% *} && \
    rm -Rf /etc/letsencrypt/archive/${DOMAINS%% *} && \
    rm -Rf /etc/letsencrypt/renewal/${DOMAINS%% *}.conf" certbot ||
    ERROR "Unable to remove ${DOMAINS%% *}"

  PRINT "Certificate for ${DOMAINS%% *} removed successfully"
}

function command_list_domains() {
  PRINT "List of certificates names:"
  docker compose run --rm --entrypoint "\
    certbot certificates" certbot ||
    ERROR "Unable list domains"
}

function usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
    add -d <domains> -e <email>    Add domains with email (-e not required)
    self-signed -d <name>          Create self signed certificate
    remove -d <domains>            Remove domains
    list                           List domains (not self signed)
    update-tls                     Update TLS parameters
EOF
  exit 1
}

function main() {
  local COMMAND="${1}"
  shift

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "${1}" in
    -d | --domains)
      shift
      DOMAINS="${1}"
      ;;
    -e | --email)
      shift
      EMAIL="${1}"
      ;;
    --staging)
      STAGING=true
      ;;
    *)
      [[ ! -z "${1}" ]] && echo "Invalid option: ${1}" || echo "Missing arguments"
      usage
      ;;
    esac
    shift
  done

  # Parse commands
  case ${COMMAND} in
  add)
    [[ -z ${DOMAINS} ]] && usage
    create_certificate
    ;;
  self-signed)
    [[ -z ${DOMAINS} ]] && usage
    create_self_signed_certificate
    ;;
  remove)
    [[ -z ${DOMAINS} ]] && usage
    remove_certificates
    ;;
  list)
    command_list_domains
    ;;
  update-tls)
    update_tls
    ;;
  *)
    usage
    ;;
  esac
}

main "$@"
