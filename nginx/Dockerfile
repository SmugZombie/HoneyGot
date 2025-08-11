# nginx/Dockerfile
FROM openresty/openresty:alpine-fat

RUN apk add --no-cache build-base lua5.1-dev luarocks && \
    luarocks install lua-resty-maxminddb && \
    luarocks install lua-resty-iputils   && \
    luarocks install lua-resty-string
