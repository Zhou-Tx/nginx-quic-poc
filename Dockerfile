### Builder ###
FROM ubuntu:22.04 AS builder

RUN useradd nginx
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y mercurial openssl libssl-dev libpcre3-dev zlib1g-dev gcc make
RUN hg clone http://hg.nginx.org/nginx-quic && cd nginx-quic && hg update 'quic'

# Build nginx-quic
WORKDIR /nginx-quic
RUN ./auto/configure --prefix=/etc/nginx \
    --build=$(hg tip | head -n 1 | awk '{ print $2 }') \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-debug \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-stream_quic_module \
    --with-http_v3_module \
    --with-cc-opt='-I/usr/include/openssl -O0 -fno-common -fno-omit-frame-pointer -DNGX_QUIC_DRAFT_VERSION=29 -DNGX_HTTP_V3_HQ=1'
RUN make -j$(nproc)
RUN make install

### Image ###
FROM ubuntu:22.04

COPY --from=builder /usr/sbin/nginx /usr/sbin/
COPY --from=builder /etc/nginx      /etc/nginx
COPY nginx.conf                     /etc/nginx/
COPY docker-entrypoint.sh           /usr/sbin
RUN chmod +x /usr/sbin/docker-entrypoint.sh
RUN useradd nginx
RUN mkdir -p /var/cache/nginx       /var/log/nginx
ADD poc.conf                        /etc/nginx/conf.d/

EXPOSE 443/udp
EXPOSE 443/tcp

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["nginx", "-c", "/etc/nginx/nginx.conf"]
