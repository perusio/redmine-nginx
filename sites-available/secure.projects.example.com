# -*- mode: nginx; mode: flyspell-prog; mode: autopair; ispell-local-dictionary: "american" -*-
### Configuration for secure.projects.example.com.

server {
    ## This is to avoid the spurious if for sub-domain name
    ## rewriting. See http://wiki.nginx.org/Pitfalls#Server_Name.
    listen 80;
    ## Replace the IPv6 address by your own address. The address below
    ## was stolen from the wikipedia page on IPv6.
    listen [fe80::202:b3ff:fe1e:8329]:80;
    server_name secure.projects.example.com;
    ## Use only HTTPS.
    return 301 https://secure.projects.example.com$request_uri;

} # server domain rewrite.

server {
    ## This is to avoid the spurious if for sub-domain name
    ## rewriting. See http://wiki.nginx.org/Pitfalls#Server_Name.
    listen 80;
    listen 443;
    ## Replace the IPv6 address by your own address. The address below
    ## was stolen from the wikipedia page on IPv6.
    listen [fe80::202:b3ff:fe1e:8329]:80 ipv6only=on;
    listen [fe80::202:b3ff:fe1e:8329]:443 ssl ipv6only=on;
    server_name www.secure.projects.example.com;

    ## See the keepalive_timeout directive in nginx.conf.
    ## Server certificate and key.
    ssl_certificate /etc/ssl/certs/secure.projects.example.com-cert.pem;
    ssl_certificate_key /etc/ssl/private/perusio.com-key.pem;

    ## Use only HTTPS.
    return 301 https://secure.projects.example.com$request_uri;

} # server domain rewrite.


server {
    listen 443 ssl; # IPv4 socket listening on all addresses.
    ## Replace the IPv6 address by your own address. The address below
    ## was stolen from the wikipedia page on IPv6.
    listen [fe80::202:b3ff:fe1e:8329]:443 ssl ipv6only=on;

    limit_conn arbeit 32;
    server_name secure.projects.example.com;

    ## Keep alive timeout set to a greater value for SSL/TLS.
    keepalive_timeout 75 75;

    ## Access and error logs.
    access_log /var/log/nginx/damiao_org.access.log;
    error_log /var/log/nginx/damiao_org.error.log;

    ## See the keepalive_timeout directive in nginx.conf.
    ## Server certificate and key.
    ssl_certificate /etc/ssl/certs/secure.projects.example.com-cert.pem;
    ssl_certificate_key /etc/ssl/private/perusio.com-key.pem;

    ## Strict Transport Security header for enhanced security. See
    ## http://www.chromium.org/sts.
    add_header Strict-Transport-Security "max-age=7200";

    root /usr/share/redmine/public;
    index index.html;

    ## See the blacklist.conf file at the parent dir: /etc/nginx.
    ## Deny access based on the User-Agent header.
    if ($bad_bot) {
        return 444;
    }
    ## Deny access based on the Referer header.
    if ($bad_referer) {
        return 444;
    }

    location / {
        try_files $uri @thin;
    }

    ## All static files will be served directly.
    location ~* ^.+\.(?:css|js|jpe?g|gif|htc|ico|png|html)$ {
        access_log off;
        expires 30d;
        ## No need to bleed constant updates. Send the all shebang in one
        ## fell swoop.
        tcp_nodelay off;
        ## Set the OS file cache.
        open_file_cache max=3000 inactive=120s;
        open_file_cache_valid 45s;
        open_file_cache_min_uses 2;
        open_file_cache_errors off;
    }

    ## Support for favicon. Return an 1x1 transparent GIF if it doesn't
    ## exist.
    location = /favicon.ico {
        expires 30d;
        try_files /favicon.ico @empty;
    }

    ## Return an in memory 1x1 transparent GIF.
    location @empty {
        expires 30d;
        empty_gif;
    }

    ## Location
    location @thin {
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_pass http://redmine_thin;
    }

    ## Protect .git files.
    location ^~ /.git {
        return 404;
    }

} # server HTTPS
