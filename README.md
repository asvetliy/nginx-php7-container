# Docker nginx + php7.1 container

Docker container based on `debian:stable-slim` version. Using `nginx stable` version with `php 7.1`. This is simple container for my own personally purpose. If you have an idea how to improve it, contact me [o.svitlyi@gmail.com](mailto:o.svitlyi@gmail.com)

## Includes packages

 * nginx, nano, memcached, curl/wget, zip/unzip, supervisor
 * git, composer
 * php 7.1 (fpm, cli, bcmath, dev, common, json, opcache, readline, mbstring, mcrypt, curl, gd, imagick, mysql, zip, pgsql,  intl, xml, pear, browscap)

## Usage

Creating container via `docker-compose` file.

```yaml
  web:
    image: osvitlyi/nginx-php7-container
    volumes:
      # 1. mount your workdir path
      - ./docker/src/html/:/usr/share/nginx/html/
      # 2. mount your configuration of site
      - ./conf/nginx/website.conf:/etc/nginx/conf.d/default.conf:ro
      # 3. if you want to override php.ini file
      - ./conf/fpm/custom.ini:/etc/php/7.1/fpm/conf.d/custom.ini
```

### Explanations

Check usage section and see explanations

 1. Mount your working directory
 2. Set your own nginx configuration which will be included at `nginx.conf` `http` block.
 3. Just set your own options to override default `php.ini` file.
