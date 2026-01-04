#
# Container parts
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

# IDENTICAL containerPHPHeader 5
ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-apache
ENV BUILD_CODE=web
ENV APACHE_HOME=/etc/apache2
# -- containerPHPHeader -------------------------------------------------------

# IDENTICAL containerMariaDBPrefix 9
FROM mariadb:10
ARG BUILD_CODE=db
ENV USER_HOME=/root
ARG APPLICATION_USER=root
ARG APPLICATION_HOME=/root/app
ARG DATABASE_ROOT_PASSWORD
ENV MARIADB_ROOT_PASSWORD=${DATABASE_ROOT_PASSWORD?no-root-password}
ENV APPLICATION_PREFIX=""
# -- containerMariaDBPrefix ---------------------------------------------------

# IDENTICAL containerWebApplication 5
ENV USER_HOME=/var/www
ENV LOG_HOME=/var/www/log
ENV APPLICATION_USER=www-data
ENV APPLICATION_PREFIX=""
# -- containerRootApplication -------------------------------------------------

# IDENTICAL containerDatabaseEnvironmentVariables 7
ENV DATABASE_NETWORK=%
ENV DATABASE_USER=docker
ENV DATABASE_PASSWORD=hard-to-guess
ENV DATABASE_HOST=db
ENV DATABASE_NAME=container
ENV DSN="mysqli://$DATABASE_USER:$DATABASE_PASSWORD@$DATABASE_HOST/$DATABASE_NAME"
# -- containerDatabaseEnvironmentVariables ------------------------------------
# -- containerDatabaseEnvironmentVariables ------------------------------------
# -- containerDatabaseEnvironmentVariables ------------------------------------

# IDENTICAL containerDockerPrefix 11
# -----------------------------------------------------------------------------
ENV APPLICATION_CONF=/etc/application.conf
RUN mkdir -p "$APPLICATION_HOME"
ADD . "$APPLICATION_HOME"
RUN printf -- "%s\n" "$BUILD_CODE" > /etc/docker-role
COPY etc/docker/install.sh /usr/local/sbin/install.sh
COPY bin/build/ /usr/local/bin/build/
RUN /usr/local/sbin/install.sh
RUN /usr/local/sbin/install.sh __installBase
RUN /usr/local/sbin/install.sh __installDevelopment
COPY .env /tmp/application.conf
# -- containerDockerPrefix ----------------------------------------------------
# -- containerDockerPrefix ----------------------------------------------------
# -- containerDockerPrefix ----------------------------------------------------
# -- containerDockerPrefix ----------------------------------------------------

# IDENTICAL containerApplicationInstance 2
COPY etc/docker/application.sh /usr/local/bin/application.sh
# -- containerApplicationInstance ---------------------------------------------

# IDENTICAL containerMariaDBApplication 6
RUN mkdir -p /docker-entrypoint-initdb.d/
RUN /usr/local/sbin/install.sh __installEnvironment /tmp/application.conf "$APPLICATION_CONF" "$APPLICATION_HOME" MARIADB_ROOT_PASSWORD DSN
RUN chmod 640 "$APPLICATION_CONF" && chown "root:$APPLICATION_USER" "$APPLICATION_CONF"
COPY etc/docker/db/db-health.sh /db-health.sh
COPY etc/docker/db/db-connect.sh /db-connect.sh
# -- containerMariaDBApplication ----------------------------------------------

COPY etc/docker/schema.sql "/docker-entrypoint-initdb.d/MAP.schema-original.sql"

# IDENTICAL containerPHPApplication 11
RUN /usr/local/sbin/install.sh __installEnvironment /tmp/application.conf "$APPLICATION_CONF" "$APPLICATION_HOME" "$APPLICATION_PREFIX" PHP_IDE_CONFIG XDEBUG_CLIENT_HOST APPLICATION_USER LOG_HOME
RUN mkdir -p "$LOG_HOME" && chmod 770 "$LOG_HOME" && chown "root:$APPLICATION_USER" "$LOG_HOME"
# PHP
COPY etc/docker/web/php.ini /usr/local/etc/php/MAP.php.ini
# XDebug
COPY etc/docker/web/xdebug.ini /usr/local/etc/php/conf.d/MAP.xdebug.ini
COPY composer.json /tmp/composer.json
RUN /usr/local/sbin/install.sh __installPHP /tmp/composer.json
RUN /usr/local/sbin/install.sh __mapFiles /usr/local/etc/php
RUN /usr/local/sbin/install.sh __installPHPXdebug
# -- containerPHPApplication --------------------------------------------------

# IDENTICAL containerDockerSuffix 2
RUN /usr/local/sbin/install.sh __installClean
# -- containerDockerSuffix ----------------------------------------------------

# IDENTICAL containerBashRoot 2
COPY etc/docker/user/bashrc.sh "/root/MAP..bashrc"
# -- containerBashRoot --------------------------------------------------------

# IDENTICAL containerBashUser 2
COPY etc/docker/user/bashrc.sh "$USER_HOME/MAP..bashrc"
# -- containerBashUser --------------------------------------------------------

# IDENTICAL containerMapApache 2
RUN /usr/local/sbin/install.sh __mapFiles "$APACHE_HOME" "$USER_HOME" "/root/" --keep "$APPLICATION_HOME"
# -- containerMapApache -------------------------------------------------------

# IDENTICAL containerMapDatabase 2
RUN /usr/local/sbin/install.sh __mapFiles "/docker-entrypoint-initdb.d/" "$USER_HOME" "/root/" --keep "$APPLICATION_HOME" --keep "/docker-entrypoint-initdb.d/"
# -- containerMapDatabase -----------------------------------------------------

# IDENTICAL containerBashUserSuffix 3
RUN chown "$APPLICATION_USER" "$USER_HOME/.bashrc" "$USER_HOME"
USER "$APPLICATION_USER"
WORKDIR "$APPLICATION_HOME"
# -- containerBashUserSuffix --------------------------------------------------
