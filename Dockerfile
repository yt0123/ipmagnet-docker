FROM php:cli-alpine3.17

ARG TRACKER=http://localhost:80/ipmagnet/

RUN set -eux \
    && apk add --no-cache \
        lighttpd \
        lighttpd-mod_auth \
        tzdata

RUN set -eux \
    && apk add --no-cache --virtual .build-deps \
        wget \
        unzip \
    && tempDir="$(mktemp -d)" \
    && cd $tempDir \
    && wget https://github.com/cbdevnet/ipmagnet/archive/refs/heads/master.zip -O ipmagnet.zip \
    && unzip ipmagnet.zip \
    && cp -r ipmagnet-master /usr/local/ipmagnet \
    && apk del .build-deps \
    && { \
        echo '# {{{ ipmagnet settings'; \
        echo 'server.http-parseopts = ('; \
        echo '  "url-ctrls-reject" => "disable",'; \
        echo '  "url-path-dotseg-reject" => "disable",'; \
        echo '  "url-invalid-utf8-reject" => "disable"'; \
        echo ')'; \
        echo ''; \
        echo 'url.access-deny = ("~", ".db3")'; \
        echo '# }}}'; \
       } > "$tempDir/ipmagnet.conf" \
    && lineNum="$(awk '/^$/{ln=NR}END{print ln-1}' /etc/lighttpd/lighttpd.conf)" \
    && sed -ri \
        -e '/^\s*url\.access-deny\s*=/s/^/# /g' \
        -e "${lineNum}a" \
        -e "${lineNum}r ${tempDir}/ipmagnet.conf" \
        /etc/lighttpd/lighttpd.conf \
    && rm -r $tempDir \
    && sed -ri \
        -e "s!^(\s*\\\$TRACKER=)[^;]+!\1urlencode('$TRACKER')!g" \
        /usr/local/ipmagnet/index.php \
    && chown -R lighttpd:0 /usr/local/ipmagnet \
    && chmod -R g+w /usr/local/ipmagnet \
    && ln -sf /usr/local/ipmagnet /var/www/localhost/htdocs/ipmagnet

RUN set -eux \
    && sed -ri \
        -e 's!^(\s*server\.pid-file\s*=)\s*\S+!\1 "/tmp/lighttpd.pid"!g' \
        -e '/^#\s*include\s+"mod_fastcgi\.conf"/s/^#\s*//g' \
        /etc/lighttpd/lighttpd.conf \
    && sed -ri \
        -e 's!^(\s*"socket"\s*=>)\s*[^,]+!\1 "/tmp/php.sock"!g' \
        -e 's!^(\s*"bin-path"\s*=>)\s*\S+!\1 "/usr/local/bin/php-cgi"!g' \
        /etc/lighttpd/mod_fastcgi.conf \
    && chown -R lighttpd:0 /var/log/lighttpd \
    && chmod -R g+w /var/log/lighttpd \
    && chown -R lighttpd:0 /etc/lighttpd \
    && chmod -R g+w /etc/lighttpd \
    && ln -sf /dev/stderr /var/log/lighttpd/access.log \
    && ln -sf /dev/stderr /var/log/lighttpd/error.log \
    && chown -Rh lighttpd:lighttpd /var/www/localhost \
    && lighttpd -tt -f /etc/lighttpd/lighttpd.conf

RUN set -eux \
    && cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
    && sed -ri \
        -e 's!^;\s*(error_log\s*=)\s*\S+\.log!\1 php://stderr!g' \
        /usr/local/etc/php/php.ini \
    && php --ini

STOPSIGNAL SIGINT

COPY lighttpd-foreground /usr/local/bin/

USER lighttpd

EXPOSE 80
CMD ["lighttpd-foreground", "-f", "/etc/lighttpd/lighttpd.conf"]
