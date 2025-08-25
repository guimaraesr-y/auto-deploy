FROM node:24-alpine

RUN apk add postgresql-client
RUN npm install -g pg-anonymizer

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
