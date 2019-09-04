#!/bin/bash

if [ -z "$DOMAINS" ]; then
    echo "You have not set a DOMAINS environmental variable."
    exit 1
fi

if [ -z "$EMAIL" ]; then
    echo "You have not set an EMAIL environmental variable."
    exit 1
fi

HAPROXY_RELOAD_CMD="supervisorctl signal HUP haproxy"
LETSENCRYPT_PORT="54321"
LETSENCRYPT_DIR="/opt/letsencrypt";
MAX_DAYS_LEFT_TO_EXPIRATION=30;

OPTION_LIST=""
IFS=',' read -ra NEW_DOMAINS <<< "$DOMAINS"
for domain in "${NEW_DOMAINS[@]}"; do
    trimmed_domain=${domain//[[:blank:]]/}
    OPTION_LIST+=" -d $trimmed_domain"
    if [ -z "$ROOT_DOMAIN" ]; then
        ROOT_DOMAIN=$trimmed_domain
    fi
done
TMP_NEW_TRIMMED_DOMAINS=$(echo "$OPTION_LIST" | cut -c 4-)
NEW_TRIMMED_DOMAINS=(${TMP_NEW_TRIMMED_DOMAINS// -d / })
OPTION_LIST=${OPTION_LIST:1}
IFS=$'\n' NEW_DOMAINS=($(sort <<< "${NEW_TRIMMED_DOMAINS[*]}"))

echo "Using the domain '$ROOT_DOMAIN' as the name of our certificate."

PRIVATE_KEY_FILE="/etc/letsencrypt/live/$ROOT_DOMAIN/privkey.pem"
CERTIFICATE_FILE="/etc/letsencrypt/live/$ROOT_DOMAIN/fullchain.pem"
COPY_PRIVATE_KEY_FILE="/usr/local/etc/haproxy/certs/$ROOT_DOMAIN/privkey.pem"
COPY_CERTIFICATE_FILE="/usr/local/etc/haproxy/certs/$ROOT_DOMAIN/fullchain.pem"
FULLCHAIN_FILE="/usr/local/etc/haproxy/certs/$ROOT_DOMAIN/$ROOT_DOMAIN.pem"

create_certificate_files() {
    bash -c "cat $PRIVATE_KEY_FILE $CERTIFICATE_FILE > $FULLCHAIN_FILE"
    bash -c "cp $PRIVATE_KEY_FILE $COPY_PRIVATE_KEY_FILE"
    bash -c "cp $CERTIFICATE_FILE $COPY_CERTIFICATE_FILE"
}

print_creating_certificates() {
    echo "Creating $FULLCHAIN_FILE and copy certificates to mounted volume..."
}

certificate_needs_update() {
    if [ ! -e $COPY_CERTIFICATE_FILE ]; then
        echo "No certificate file found for domain $ROOT_DOMAIN."
    fi

    echo "Checking for newly added/subtracted domains:"

    local domains=$(openssl x509 -in $COPY_CERTIFICATE_FILE -text | grep "DNS:" | xargs | cut -c 5-)
    local domains=${domains//DNS:/}

    IFS=', ' read -ra OLD_DOMAINS <<< "$domains"
    IFS=$'\n' OLD_DOMAINS=($(sort <<< "${OLD_DOMAINS[*]}"))

    local diff=$(diff <(printf "%s\n" "${OLD_DOMAINS[@]}") <(printf "%s\n" "${NEW_DOMAINS[@]}"))
    if [[ -n "$diff" ]]; then
        echo "New or deleted domains found"
        echo "Old: ${OLD_DOMAINS[@]}"
        echo "New: ${NEW_DOMAINS[@]}"
        echo "Diff: $diff"
    fi

    echo "Checking expiration date for $ROOT_DOMAIN..."

    local expiration_time=$(date -d "`openssl x509 -in $COPY_CERTIFICATE_FILE -text -noout | grep "Not After" | cut -c 25-`" +%s)
    local now=$(date -d "now" +%s)
    local days_left_to_expiration=$(echo \( $expiration_time - $now \) / 86400 | bc)
    if [ "$days_left_to_expiration" -gt "$MAX_DAYS_LEFT_TO_EXPIRATION" ]; then
        echo "The certificate is up to date, no need for renewal ($days_left_to_expiration days left)."
    fi
    return 0
}

print_renewal_finish_statement() {
    echo "Renewal process finished for domain $ROOT_DOMAIN."
}

if certificate_needs_update; then
    mkdir -p /usr/local/etc/haproxy/certs/$ROOT_DOMAIN

    if [ -n "$INITIAL_RENEWAL" ]; then
        cmd="$LETSENCRYPT_DIR/certbot-auto certonly --standalone --non-interactive --agree-tos --email $EMAIL --force-renewal --no-self-upgrade --rsa-key-size 4096 $OPTION_LIST"
        echo "Creating certificate..."
        echo $cmd
        eval $cmd

        print_creating_certificates
        create_certificate_files
        print_renewal_finish_statement
    else
        cmd="$LETSENCRYPT_DIR/certbot-auto certonly --standalone --non-interactive --agree-tos --email $EMAIL --force-renewal --no-self-upgrade --rsa-key-size 4096 --http-01-port $LETSENCRYPT_PORT $OPTION_LIST"
        echo "The certificate for $ROOT_DOMAIN is about to expire soon. Starting Let's Encrypt renewal script..."
        echo $cmd
        eval $cmd

        print_creating_certificates
        create_certificate_files
        print_renewal_finish_statement
        eval $HAPROXY_RELOAD_CMD
    fi
fi
