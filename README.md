# Nginx configuration for running Redmine

## Introduction

   This is an example configuration from running
   [Redmine](http://redmine.org) using
   [nginx](http://nginx.org) as a HTTP reverse proxy to [thin]().

    There's nothing particularly fancy or oblique about this
    configuration. In fact, getting `thin` to work as it should is 80%
    of the problem.
    
## General Features

 1. Regular HTTP and HTTPS configurations.
 
 2. Lightweight. 
 
 3. IPv6 and IPv4 support.

 4. Usage of the open files cache (inode search) for speeding up
    static asset delivery.
 
 5. Support for
    [X-Frame-Options](https://developer.mozilla.org/en/The_X-FRAME-OPTIONS_response_header)
      HTTP header to avoid Clickjacking attacks.
 
 6. Use of [Strict Transport Security](http://www.chromium.org/sts
      "STS at chromium.org") for enhanced security. It forces during
      the specified period for the configured domain to be contacted
      only over HTTPS. Requires a modern browser to be of use, i.e.,
      **Chrome/Chromium**, **Firefox 4** or **Firefox with NoScript**.
      
 7. DoS prevention with a _low_ number of connections by client
    allowed: **32**. This number can be adjusted as you see fit.
   
 8. Limitation of allowed HTTP methods. Out of the box only `GET`,
      `HEAD` and `POST`are allowed.
      
## HTTP allowed methods made to measure

   For a *standard* redmine install there's no need for any method
   besides `GET`, `HEAD` and `POST`. The allowed methods are
   enumerated in the file `map_block_http_methods.conf`.
   
   If your site uses/provide web services then you must add the
   methods you need to the list. For example if you want to allow
   `PUT` then do:
   
       map $request_method $not_allowed_method {
           default 1;
           GET 0;
           HEAD 0;
           POST 0;
           PUT 0;
       }

   Note that this enables `PUT` for all locations and clients. If you
   need a finer control than use the
   [`limit_except`](http://nginx.org/en/docs/http/ngx_http_core_module.html#limit_except)
   directive and enumerate the client IPs that are allowed to use the
   *extra* methods like `PUT`.

## IPv6 and IPv4

The configuration of the example vhosts uses **separate** sockets for
IPv6 and IPv4. This way is simpler for those not (yet) having IPv6
support to disable it by commenting out the
[`listen`](http://nginx.org/en/docs/http/ngx_http_core_module.html#listen)
directive with the `ipv6only=on` parameter.

Note that the IPv6 address uses an IP _stolen_ from the
[IPv6 Wikipedia page](https://en.wikipedia.org/wiki/IPv6). You **must
replace** the indicated address by **your** address. 

## Installation

### Redmine from Debian

The installation procedure assumes that you install redmine from
[Debian](http://packages.debian.org/sid/redmine) **unstable**.  The
reason why I recommend installing from unstable is that by doing so
you get the **latest** version of redmine.

You must also install one of the following persistence layer backends:

 + [redmine-sqlite](http://packages.debian.org/sid/redmine-sqlite)

 + [redmine-mysql](http://packages.debian.org/sid/redmine-mysql)

 + [redmine-pgsql](http://packages.debian.org/sid/redmine-pgsql)

### Thin from Debian

[Thin](http://code.macournoyer.com/thin/) provides the backend that
receives requests from Nginx and forwards them to redmine.

We're also installing
[thin](http://packages.debian.org/sid/all/thin/download) from debian unstable.

### Howto

 1. Choose the mirror that is nearest to you from the 
    [list](http://packages.debian.org/sid/all/redmine/download).

    also for the above referenced persistence layer (redmine-sqlite,
    redmine-mysql or redmine-pgsql).
    
    Install them:
    
    `aptitude install -t unstable redmine`
    
    Here were using the mysql backend.
    
    `aptitude install -t unstable redmine-mysql`

    You'll have to configure redmine.

 2. Install thin.
 
    `aptitude -t unstable install thin` 

 3. Install Nginx if you don't have it already installed.
 
 4. Configure thin.
     
        thin config --config /tmp/redmine.yml --chdir /usr/share/redmine --environment production --socket /var/run/redmine/sockets/thin.sock --daemonize --log /var/log/thin/redmine.log --pid /var/run/thin/redmine.pid --user www-data --group www-data --servers 1
 
    Here we're configuring thin to run with **one server**, to run as
    a **daemon** (in the background), to log at
    `/var/log/thin/redmine.log` to write the PID file at
    `/var/run/thin/redmine.pid` to create the listeninx UNIX sockets
    at `/var/run/redmine/sockets` to run with user and group
    `www-data` and to run the rails app (redmine) in a **production** setup.

    Move the config file to the final location:
        
        mv /tmp/redmine.yml /etc/thin1.8
        
    Create and fix the permissions of the sockets directory.
    
        mkdir -p /var/run/redmine/sockets
        
        chown www-data.www-data /var/run/redmine/sockets
    
 5. Launch thin:
        
        service thin start
        
    You should see the socket that was created, `ls /var/run/redmine/sockets`:
    
    `srwxrwxrwx 1 www-data www-data 0 Abr 11 15:42 thin.0.sock`    
 

 6. Move the old `/etc/nginx` directory to `/etc/nginx.old`.
   
 7. Clone the git repository from github:
   
      `git clone https://github.com/perusio/redmine-nginx.git`
   
 8. Edit the `sites-available/projects.example.com.conf` or the
    `secure.projects.example.com.conf` (if using SSL) configuration file to
      suit your requirements. Namely replacing example.com with
      **your** domain and also dealing with IPv6 configuration.
   
 9. Create the `/etc/nginx/sites-enabled` directory and enable the
    virtual host using one of the methods described below.
      
    Note that if you're using the
    [nginx_ensite](http://github.com/perusio/nginx_ensite) script
    described below it **creates** the `/etc/nginx/sites-enabled`
    directory if it doesn't exist the first time you run it for
    enabling a site.
    
 10. Reload Nginx:
   
     `service nginx reload`

 11. Configure the mail setup for Redmine as described in the
     [wiki](http://www.redmine.org/projects/redmine/wiki/EmailConfiguration).
   
 12. Restart thin.
 
         service thin restart
   
 13. Done. You can now login to your redmine site using the user and
     pass `admin`. The first thing to do is change them to something else.      
   
## Enabling and Disabling Virtual Hosts

   I've created a shell script
   [nginx_ensite](http://github.com/perusio/nginx_ensite) that lives
   here on github for quick enabling and disabling of virtual hosts.
   
   If you're not using that script then you have to **manually**
   create the symlinks from `sites-enabled` to `sites-available`. Only
   the virtual hosts configured in `sites-enabled` will be available
   for Nginx to serve.

## Getting the latest Nginx packaged for Debian or Ubuntu

   I maintain a [debian repository](http://debian.perusio.net/unstable
   "my debian repo") with the
   [latest](http://nginx.org/en/download.html "Nginx source download")
   version of Nginx. This is packaged for Debian **unstable** or
   **testing**. The instructions for using the repository are
   presented on this [page](http://debian.perusio.net/debian.html
   "Repository instructions").
 
   It may work or not on Ubuntu. Since Ubuntu seems to appreciate more
   finding semi-witty names for their releases instead of making clear
   what's the status of the software included, meaning. Is it
   **stable**? Is it **testing**? Is it **unstable**? The package may
   work with your currently installed environment or not. I don't have
   the faintest idea which release to advise. So you're on your
   own. Generally the APT machinery will sort out for you any
   dependencies issues that might exist.

## Monitoring nginx

   I use [Monit](http://mmonit.com) for supervising the nginx
   daemon. Here's my
   [configuration](http://github.com/perusio/monit-miscellaneous) for
   nginx.

## Caveat emptor

   You should **always** test the configuration with `nginx -t` to see
   if everything is correct. Only after a successful should you reload
   nginx. On Debian and any of its derivatives you can also test the
   configuration by invoking the init script as: `/etc/init.d/nginx
   testconfig`.

## My other nginx configs on github

   + [Drupal](https://github.com/perusio/drupal-with-nginx "Drupal
     Nginx config") 

   + [WordPress](https://github.com/perusio/wordpress-nginx "WordPress Nginx
     config")

   + [Chive](https://github.com/perusio/chive-nginx "Chive Nginx
     config")
     
   + [Piwik](https://github.com/perusio/piwik-nginx "Piwik Nginx
     config")
       
   + [SquirrelMail](https://github.com/perusio/squirrelmail-nginx
     "SquirrelMail Nginx configuration")
