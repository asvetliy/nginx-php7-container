FROM debian:stable-slim

LABEL maintainer="Oleksandr Svitlyi <o.svitlyi@gmail.com>"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive
ENV PHP_CONF /etc/php/7.1/fpm/php.ini
ENV FPM_CONF /etc/php/7.1/fpm/pool.d/www.conf
ENV COMPOSER_VERSION 2.0.13

ARG BUILD_DEPS='curl gcc make autoconf libc-dev zlib1g-dev pkg-config gnupg2 ca-certificates lsb-release debian-archive-keyring dirmngr wget apt-transport-https'
ARG EXTRA_DEPS='apt-utils nano zip unzip python-pip python-setuptools git libmemcached-dev libmemcached11 libmagickwand-dev'
ARG CUSTOM_DEPS=''

# Install Basic Requirements
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y ${BUILD_DEPS} \
    && apt-get install --no-install-recommends --no-install-suggests -q -y ${EXTRA_DEPS} \
    # Nginx install
    && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
    && gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian `lsb_release -cs` nginx" \
           | sudo tee /etc/apt/sources.list.d/nginx.list \
    && echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
           | sudo tee /etc/apt/preferences.d/99nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y nginx \
    # PHP 7.1 install
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
            php7.1-fpm \
            php7.1-cli \
            php7.1-bcmath \
            php7.1-dev \
            php7.1-common \
            php7.1-json \
            php7.1-opcache \
            php7.1-readline \
            php7.1-mbstring \
            php7.1-mcrypt \
            php7.1-curl \
            php7.1-gd \
            php7.1-imagick \
            php7.1-mysql \
            php7.1-zip \
            php7.1-pgsql \
            php7.1-intl \
            php7.1-xml \
            php-pear \
    && cd /tmp \
    && wget https://browscap.org/stream?q=PHP_BrowsCapINI \
    && mv 'stream?q=PHP_BrowsCapINI' /etc/php/7.1/mods-available/browscap.ini \
    && sed -i 's+;browscap = extra/browscap.ini+browscap = /etc/php/7.1/mods-available/browscap.ini+g' /etc/php/7.1/fpm/php.ini \
    && pecl -d php_suffix=7.1 install -o -f redis memcached \
    && mkdir -p /run/php \
    && pip install wheel \
    && pip install supervisor supervisor-stdout \
    # Configuring
    && echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
    && rm -rf /etc/nginx/conf.d/default.conf \
    && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${PHP_CONF} \
    && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${PHP_CONF} \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${PHP_CONF} \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${PHP_CONF} \
    && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${PHP_CONF} \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.1/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${FPM_CONF} \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${FPM_CONF} \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${FPM_CONF} \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${FPM_CONF} \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${FPM_CONF} \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${FPM_CONF} \
    && sed -i -e "s/www-data/nginx/g" ${FPM_CONF} \
    && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${FPM_CONF} \
    && echo "extension=redis.so" > /etc/php/7.1/mods-available/redis.ini \
    && echo "extension=memcached.so" > /etc/php/7.1/mods-available/memcached.ini \
    && ln -sf /etc/php/7.1/mods-available/redis.ini /etc/php/7.1/fpm/conf.d/20-redis.ini \
    && ln -sf /etc/php/7.1/mods-available/redis.ini /etc/php/7.1/cli/conf.d/20-redis.ini \
    && ln -sf /etc/php/7.1/mods-available/memcached.ini /etc/php/7.1/fpm/conf.d/20-memcached.ini \
    && ln -sf /etc/php/7.1/mods-available/memcached.ini /etc/php/7.1/cli/conf.d/20-memcached.ini \
    # Install Composer
    && curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
    && rm -rf /tmp/composer-setup.php \
    # Clean up
    && rm -rf /tmp/pear \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Supervisor config
COPY ./config/supervisor/supervisord.conf /etc/supervisord.conf

# Override nginx's default config
COPY ./config/nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Copy Scripts
COPY ./config/start.sh /start.sh

EXPOSE 80

CMD ["/start.sh"]