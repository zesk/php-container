#
# database Container running MariaDB
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

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

# IDENTICAL containerDatabaseEnvironmentVariables 7
ENV DATABASE_NETWORK=%
ENV DATABASE_USER=docker
ENV DATABASE_PASSWORD=hard-to-guess
ENV DATABASE_HOST=db
ENV DATABASE_NAME=container
ENV DSN="mysqli://$DATABASE_USER:$DATABASE_PASSWORD@$DATABASE_HOST/$DATABASE_NAME"
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
# -- containerDockerPrefix --------------------------------------------------

# IDENTICAL containerMariaDBApplication 6
RUN mkdir -p /docker-entrypoint-initdb.d/
RUN /usr/local/sbin/install.sh __installEnvironment /tmp/application.conf "$APPLICATION_CONF" "$APPLICATION_HOME" MARIADB_ROOT_PASSWORD DSN
RUN chmod 640 "$APPLICATION_CONF" && chown "root:$APPLICATION_USER" "$APPLICATION_CONF"
COPY etc/docker/db/db-health.sh /db-health.sh
COPY etc/docker/db/db-connect.sh /db-connect.sh
# -- containerMariaDBApplication ----------------------------------------------

# ---------------------------------------------------------------------------
# -- Cusom Schema Code ------------------------------------------------------
# ---------------------------------------------------------------------------

COPY etc/docker/db/sample-schema.sql "/docker-entrypoint-initdb.d/MAP.schema-original.sql"

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

# IDENTICAL containerDockerSuffix 2
RUN /usr/local/sbin/install.sh __installClean
# -- containerDockerSuffix ----------------------------------------------------

# IDENTICAL containerBashUser 2
COPY etc/docker/user/bashrc.sh "$USER_HOME/MAP..bashrc"
# -- containerBashUser --------------------------------------------------------

# IDENTICAL containerMapDatabase 2
RUN /usr/local/sbin/install.sh __mapFiles "/docker-entrypoint-initdb.d/" "$USER_HOME" "/root/" --keep "$APPLICATION_HOME" --keep "/docker-entrypoint-initdb.d/"
# -- containerMapDatabase -----------------------------------------------------
