# Cloud agent base image for the sent_emails gem.
# Do not COPY the project — Cursor checks out the correct commit into the workspace.
FROM ruby:3.3.8-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    RAILS_ENV=test \
    POSTGRES_HOST=localhost \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    libpq-dev \
    libsqlite3-dev \
    postgresql \
    postgresql-client \
    sudo \
    tzdata \
  && rm -rf /var/lib/apt/lists/* \
  && gem install bundler \
  && echo "ALL ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd \
  && chmod 0440 /etc/sudoers.d/nopasswd

# Prepare a local Postgres role/database for DB=postgresql specs.
USER postgres
RUN /etc/init.d/postgresql start \
  && psql --command "ALTER USER postgres WITH PASSWORD 'postgres';" \
  && createdb -O postgres sent_emails_test \
  && /etc/init.d/postgresql stop
USER root

WORKDIR /workspace
