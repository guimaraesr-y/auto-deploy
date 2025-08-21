FROM postgres:17-alpine

RUN apk add cronie

COPY dump.sh /usr/local/bin/dump.sh
RUN chmod +x /usr/local/bin/dump.sh

COPY crontab /etc/crontabs/root
RUN chmod 0644 /etc/crontabs/root

RUN mkdir /dumps && chown postgres:postgres /dumps

CMD ["crond", "-f"]
