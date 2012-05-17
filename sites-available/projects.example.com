# -*- mode: nginx; mode: flyspell-prog;  ispell-local-dictionary: "american" -*-
### Configuration for redmine with thin.

server {
    listen 80; # IPv4 socket listening on all addresses.
    ## Replace the IPv6 address by your own address. The address below
    ## was stolen from the wikipedia page on IPv6.
    listen [fe80::202:b3ff:fe1e:8329]:80 ipv6only=on;

    server_name projects.example.com;
    limit_conn arbeit 32;

    ## Access and error logs.
    access_log /var/log/nginx/projects.redmine.access.log;
    error_log /var/log/nginx/projects.redmine.error.log;


    ## Protection against illegal HTTP methods. Out of the box only HEAD,
    ## GET and POST are allowed.
    if ($not_allowed_method) {
        return 405;
    }

    ## The root of the Debian redmine.
    root /usr/share/redmine/public;

    ## Error pages for 404 and 50x.
    error_page 404 404.html;
    error_page 500 502 503 504 500.html;

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

} # server
