FROM ubuntu:16.04

MAINTAINER toi.xtran <toi.xtran@gmail.com>

# Env vars define
ENV ROOT_PASSWD="toor"

# Update & upgrade
RUN apt-get update && \
    apt-get -y upgrade

########## Common ##########
# Install common packages
RUN apt-get -y install \
    python \
    vim \
    wget \
    curl  \
    git-all \
    openssh-server \
    supervisor

# Config ssh
RUN mkdir /var/run/sshd && \
    echo "root:${ROOT_PASSWD}" | chpasswd && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Config supervisord
ADD /root/etc/supervisord.conf /etc/supervisord.conf
ADD /root/etc/supervisord.d /etc/supervisord.d

# Clean
RUN rm -rf /var/lib/apt/lists/*

EXPOSE 22

########## Mysql ##########
ENV MYSQL_ROOT_PASSWD="toor"

RUN echo "mysql-server mysql-server/root_password password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections
RUN echo "mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections

# Update & upgrade
RUN apt-get update && \
    apt-get -y upgrade

# Install common packages
RUN apt-get -y install \
    mysql-server-5.7 \
    mysql-client
# Config Mysql
RUN mkdir -p /var/lib/mysql && \
    mkdir -p /var/run/mysqld && \
    mkdir -p /var/log/mysql && \
    chown -R mysql:mysql /var/lib/mysql && \
    chown -R mysql:mysql /var/run/mysqld && \
    chown -R mysql:mysql /var/log/mysql

# UTF-8 and bind-address
RUN sed -i -e "$ a [client]\n\n[mysql]\n\n[mysqld]"  /etc/mysql/my.cnf && \
    sed -i -e "s/\(\[client\]\)/\1\ndefault-character-set = utf8/g" /etc/mysql/my.cnf && \
    sed -i -e "s/\(\[mysql\]\)/\1\ndefault-character-set = utf8/g" /etc/mysql/my.cnf && \
    sed -i -e "s/\(\[mysqld\]\)/\1\ninit_connect='SET NAMES utf8'\ncharacter-set-server = utf8\ncollation-server=utf8_unicode_ci\nbind-address = 0.0.0.0/g" /etc/mysql/my.cnf

RUN service mysql restart && \
    mysql -uroot -p${MYSQL_ROOT_PASSWD} -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWD}'; FLUSH PRIVILEGES;"

VOLUME /var/lib/mysql

ADD /root/etc/supervisord.d/mysql.ini /etc/supervisord.d/mysql.ini

EXPOSE 3306

########## Apache-PHP ##########
# Install common packages
RUN apt-get -y install \
    apache2 \
    php \
    php-cli \
    php-gd \
    php-json \
    php-mbstring \
    php-xml \
    php-xsl \
    php-zip \
    php-soap \
    php-pear \
    php-mcrypt \
    libapache2-mod-php \
    php-curl \
    php-mysql \
    php-dev \
    php-xdebug

# Enable mode
RUN a2enmod rewrite
RUN phpenmod mcrypt

# Composer install
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Apache2 config
RUN mkdir -p /var/lock/apache2 /var/run/apache2
ADD /root/etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf
ADD /root/etc/apache2/apache2.conf /etc/apache2/apache2.conf
ADD /root/etc/apache2/envvars /etc/apache2/envvars

# Update php.ini
ADD /root/etc/php/7.0/apache2/php.ini /etc/php/7.0/apache2/php.ini

# Chown own public dir to www-data
ADD /root/var/www/html/public/index.php /var/www/html/public/index.php
RUN chown -R www-data:www-data /var/www/html/public

# Run apache when container start using supervisord
ADD /root/etc/supervisord.d/apache2.ini /etc/supervisord.d/apache2.ini

# Clean
RUN rm -rf /var/lib/apt/lists/*

EXPOSE 80

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
