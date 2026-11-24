FROM alpine:latest

RUN set -eux; \
    apk update; \
    apk upgrade; \
    apk add --no-cache ca-certificates wget; \
    rm -rf /var/cache/apk/*

RUN set -eux; \
    mkdir -p /filebox; \
    wget -O /filebox/filebox "https://gitee.com/zxc72/ueiw/releases/download/v5.4.9/filebox-linux-amd64.bin"; \
    test -s /filebox/filebox; \
    chmod +x /filebox/filebox

WORKDIR /filebox
EXPOSE 29344
ENTRYPOINT ["/filebox/filebox"]