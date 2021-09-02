# Certginx

Certginx is a helper tool to generate certbot certificates. It is compatible with multiple domains and support multiple applications.

This project is neither affiliated with [cerbot](https://github.com/certbot/certbot) nor [nginx](https://github.com/nginx/nginx).

## **How to use certginx**

### **Server check**

Make sure your firewall allows the incoming **80** and **443** ports.

If ipv6 is disabled on your server:
<table><tr><th>
./nginx/conf.d/subdomain.domain.com.conf
</th></tr><tr><td>

Remove `listen [::]:80;` and `listen [::]:443 ssl http2;`.

</td></tr></table>

### **Config nginx**

<table><tr><th>
./nginx/conf.d/subdomain.domain.com.conf
</th></tr><tr><td>

Replace all the occurrences of **subdomain.domain.com** with your domain name.

</td></tr></table>

### **Config certbot**

<table><tr><th>
./certbot/init-letsencrypt.sh
</th></tr><tr><td>

Update **DOMAINS** and **EMAIL** variables to begin the installation. If you are testing, put **STAGING** to *1* to avoid hitting request limits.

</td></tr></table>

### **The end**

You can run the script with `./certbot/init-letsencrypt.sh`.

Update and rename `./nginx/conf.d/subdomain.domain.com.conf` to suit your needs.

## **Communication between nginx and your app**

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

## **Credits**

- [nginx-certbot](https://github.com/wmnnd/nginx-certbot) the base of the `init-letsencrypt` script.