FROM debian:9-slim
MAINTAINER Fabio Rauber <fabiorauber@gmail.com>

# setup workdir
RUN mkdir /data
WORKDIR /data

# environment for osticket
ENV OSTICKET_VERSION 1.12.2
ENV HOME /data

# requirements
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive \
  apt-get -y install --no-install-recommends \
  ca-certificates \
  cron \
  msmtp \
  nano \
  nginx \
  php-memcache \
  php-cli \
  php-curl \
  php-fpm \
  php-gd \
  php-imap \
  php-mysql \
  php-ldap \
  php-xml \
  php-mbstring \
  supervisor \
  unzip \
  wget && \
  rm -rf /var/lib/apt/lists/*

# Download & install OSTicket
RUN wget -nv -O osTicket.zip https://github.com/osTicket/osTicket/releases/download/v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip && \
    unzip osTicket.zip && \
    rm osTicket.zip && \
    mv /data/upload/setup /data/upload/setup_hidden && \
    chown -R root:root /data/upload/setup_hidden && \
    chmod 700 /data/upload/setup_hidden && \
    chown -R www-data:www-data /data/upload/ && \
    chmod -R 755 /data/upload/
    
# Install languages packs and plugins
COPY plugins/pt_BR.phar upload/include/i18n/pt_BR.phar
COPY plugins/auth-ldap.phar upload/include/plugins/auth-ldap.phar
COPY plugins/auth-passthru.phar upload/include/plugins/auth-passthru.phar
COPY plugins/storage-fs.phar upload/include/plugins/storage-fs.phar
  
# Configure nginx
RUN sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
    sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \
    echo "daemon off;" >> /etc/nginx/nginx.conf

# Configure php-fpm & PHP5
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/7.0/fpm/php.ini && \
    sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/7.0/fpm/php.ini && \
    sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/7.0/fpm/php.ini && \
    sed -i -e 's#;sendmail_path\s*=\s*#sendmail_path = "/usr/bin/msmtp -C /etc/msmtp -t "#g' /etc/php/7.0/fpm/php.ini && \
    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.0/fpm/php-fpm.conf && \
    sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.0/fpm/pool.d/www.conf && \
    phpenmod imap && \
    mkdir -p /run/php

# Add nginx site
ADD virtualhost /etc/nginx/sites-available/default
ADD supervisord.conf /data/supervisord.conf
ADD msmtp.conf /data/msmtp.conf
ADD bin/ /data/bin

EXPOSE 80
CMD ["/data/bin/start.sh"]
