#!/bin/sh

RSA_KEY_SIZE=4096
DUMMY_NAME="dummy-certificate"

# DO NOT CHANGE
SCRIPT_PATH="$( cd "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"

mkdir -p "$SCRIPT_PATH/conf/live/${DUMMY_NAME}"
docker compose run --rm --entrypoint "\
openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 3650\
    -keyout '/etc/letsencrypt/live/${DUMMY_NAME}/privkey.pem' \
    -out '/etc/letsencrypt/live/${DUMMY_NAME}/fullchain.pem' \
    -subj '/CN=localhost'" certbot \
|| echo "\033[0;31m\033[1m!! Unable to create dummy certificates !! \033[0m\n"