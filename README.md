# Certginx

Certginx is a helper tool to generate certbot certificates. It is compatible with multiple domains and support multiple applications.

This project is neither affiliated with [cerbot](https://github.com/certbot/certbot) nor [nginx](https://github.com/nginx/nginx).

## **How to use certginx**

### **Configuring firewall**

Make sure your firewall allows the incoming **80** and **443** ports.

*Open ports with iptables:*
```sh
iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
```

### **Configuring nginx**

<table><tr><th>
./nginx/conf.d/subdomain.domain.com.conf
</th></tr><tr><td>

Replace all the occurrences of **subdomain.domain.com** with your domain name.

Rename `up-app` with `up-<app-name>`, it may create conflicts if you use the same name between files.

Rename `./nginx/conf.d/subdomain.domain.com.conf` with `./nginx/conf.d/<your-domain>.conf`.

</td></tr></table>

### **Configuring certbot**

Every time you want to add a new domain. You need to configure the file below.

<table><tr><th>
./certbot/add_domain.sh
</th></tr><tr><td>

Update **DOMAINS** and **EMAIL** variables to begin the installation. If you are testing, put **STAGING** to *1* to avoid hitting request limits.

</td></tr></table>

### **Executing the script**

Run the script with `./certbot/add_domain.sh`.

### **Configuring after script**

Update `./nginx/conf.d/<your-domain>.conf` to suit your needs.

<table><tr><th>
./nginx/conf.d/<your-domain>.conf
</th></tr><tr><td>

Update **localhost** in `up-<app-name>` section with the name of your docker container.

</td></tr></table>

## **Communicating between certginx and your app**

I will use `example-app` as network, you may rename it.

<table><tr><th>
./docker-compose.yml
</th></tr><tr><td>

At the end of `nginx` service, add:
```yml
networks:
    - example-app
```

At the end of the file, add:
```yml
networks:
    example-app:
        external: true
```

External networks are not automatically created by docker-compose. To do so, just run the command below:
```
docker network create example-app
```

</td></tr></table>

You need to do the same thing in your `docker-compose.yml` app, but instead of `nginx` service, it will be your communicating service.

## **Best practice to deploy**

The best way to deploy your app with certginx is to create a user per application (eg. user *certginx* for certgins and user *website* for your website).

## **Secure your nginx**

Use the latest ssl protocols.

<table><tr><th>
./nginx/conf.d/00_tls-cipher.conf
</th></tr><tr><td>

```conf
ssl_protocols TLSv1.3;
ssl_prefer_server_ciphers off;
```

</td></tr></table>

Catch bad sni (replace `dummy-certificate` with a dummy certificate).

<table><tr><th>
./nginx/conf.d/01_catch-bad-sni.conf
</th></tr><tr><td>

```conf
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;

    ssl_certificate /etc/letsencrypt/live/dummy-certificate/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dummy-certificate/privkey.pem;

    return 444;
}
```

</td></tr></table>

Catch bad vhost.

<table><tr><th>
./nginx/conf.d/01_catch-bad-vhost.conf
</th></tr><tr><td>

```conf
server {
    listen 80;
    listen [::]:80;
    server_name _;

    return 444;
}
```

</td></tr></table>

## **Credits**

- [nginx-certbot](https://github.com/wmnnd/nginx-certbot) the base of the `add_domain` script.
