#
# web Container running Apache and PHP
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

# IDENTICAL containerPHPHeader 5
ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-apache
ENV BUILD_CODE=web
ENV APACHE_HOME=/etc/apache2
# -- containerPHPHeader -------------------------------------------------------

# Custom configuration here
ENV APPLICATION_HOME=/var/www/app
ENV WEB_ROOT=$APPLICATION_HOME/public

# IDENTICAL containerWebApplication 5
ENV USER_HOME=/var/www
ENV LOG_HOME=/var/www/log
ENV APPLICATION_USER=www-data
ENV APPLICATION_PREFIX=""
# -- containerRootApplication -------------------------------------------------

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

# Apache Configuration
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
COPY etc/docker/web/web.conf "${APACHE_HOME}/sites-available/MAP.web.conf"
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

# IDENTICAL containerBashRoot 2
COPY etc/docker/user/bashrc.sh "/root/MAP..bashrc"
# -- containerBashRoot --------------------------------------------------------

# IDENTICAL containerBashUser 2
COPY etc/docker/user/bashrc.sh "$USER_HOME/MAP..bashrc"
# -- containerBashUser --------------------------------------------------------

# IDENTICAL containerBashUser 2
COPY etc/docker/user/bashrc.sh "$USER_HOME/MAP..bashrc"
# -- containerBashUser --------------------------------------------------------

# IDENTICAL containerMapApache 2
RUN /usr/local/sbin/install.sh __mapFiles "$APACHE_HOME" "$USER_HOME" "/root/" --keep "$APPLICATION_HOME"
# -- containerMapApache -------------------------------------------------------

# IDENTICAL containerApacheSuffix
RUN /usr/sbin/a2enmod rewrite alias
# RUN printf "%s\n" "*" | a2disconf >/dev/null || :
RUN printf "%s\n" "*" | a2dissite >/dev/null || :
RUN /usr/sbin/a2ensite web
RUN rm -rf "/var/www/html"

# IDENTICAL containerBashUserSuffix 3
RUN chown "$APPLICATION_USER" "$USER_HOME/.bashrc" "$USER_HOME"
USER "$APPLICATION_USER"
WORKDIR "$APPLICATION_HOME"
# -- containerBashUserSuffix --------------------------------------------------
