FROM postgres:17

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    postgresql-server-dev-17 \
    pgxnclient \
 && rm -rf /var/lib/apt/lists/*

RUN pgxn install postgresql_anonymizer

RUN curl -fsSL \
  https://gitlab.com/dalibo/postgresql_anonymizer/-/raw/master/docker/anon.sh \
  -o /anon.sh \
 && chmod +x /anon.sh

COPY setup.sql /anon_setup.sql

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER postgres

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]