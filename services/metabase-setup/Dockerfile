FROM alpine:3.18
RUN apk add --no-cache curl jq netcat-openbsd
COPY setup.sh /setup.sh
RUN chmod +x /setup.sh
CMD ["/setup.sh"]