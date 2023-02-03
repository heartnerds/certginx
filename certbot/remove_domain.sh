#!/bin/sh

DOMAINS="domain.com subdomain.domain.com"

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

remove_certificates () {
  PRINT "Removing Let's Encrypt certificate for ${DOMAINS} ..."

  for domain in ${DOMAINS}; do
    docker compose run --rm --entrypoint "\
      certbot delete --cert-name $domain" certbot \
      || ERROR "Unable to remove $domain"
  done
}

stop_docker () {
  PRINT "Stopping docker compose ..."
  docker compose down
}


check_confirmation

check_docker_compose

remove_certificates

stop_docker
