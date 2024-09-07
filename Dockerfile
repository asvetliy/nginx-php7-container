FROM debian:stable-slim

LABEL maintainer="Oleksandr Svitlyi <o.svitlyi@gmail.com>"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND=noninteractive
ENV PHP_CONF=/etc/php/7.1/fpm/php.ini
ENV FPM_CONF=/etc/php/7.1/fpm/pool.d/www.conf
ARG COMPOSER_VERSION=2.7.9
ENV BUILD_DEPS='curl gcc openssl make autoconf libc-dev zlib1g-dev pkg-config gnupg2 ca-certificates lsb-release debian-archive-keyring dirmngr wget apt-transport-https supervisor'
ENV EXTRA_DEPS='apt-utils nano zip unzip git libmemcached-dev libmemcached11 libmagickwand-dev'
ARG CUSTOM_DEPS=''

# Install Basic Requirements
RUN set -x \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -q -y ${BUILD_DEPS} \
    && apt install --no-install-recommends --no-install-suggests -q -y ${EXTRA_DEPS} \
    && if [ "${CUSTOM_DEPS}" != "" ]; then \
         apt install --no-install-recommends --no-install-suggests -q -y ${CUSTOM_DEPS}; \
       fi \
    && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
    && gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt update \
    && apt install -q -y nginx \
    && apt install -y \
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
            php7.1-igbinary \
            php7.1-msgpack \
            php7.1-redis \
            php7.1-memcached \
    && cd /tmp \
    && apt install -q -y python3 python3-pip \
    && pip3 install supervisor-stdlog --break-system-packages \
    && wget https://browscap.org/stream?q=PHP_BrowsCapINI \
    && mv 'stream?q=PHP_BrowsCapINI' /etc/php/7.1/mods-available/browscap.ini \
    && sed -i 's+;browscap = extra/browscap.ini+browscap = /etc/php/7.1/mods-available/browscap.ini+g' /etc/php/7.1/fpm/php.ini \
    && mkdir -p /run/php \
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
    && curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
    && rm -rf /tmp/composer-setup.php \
    && apt update && apt upgrade -y \
    && rm -rf /tmp/pear \
    && apt clean \
    && apt autoremove \
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