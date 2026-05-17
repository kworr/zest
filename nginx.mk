NGINX_ETC=/usr/local/etc/nginx
INSTALLED=${:!cd ${NGINX_ETC}/local && find . -type f!:C|^\.\/||:C|\.conf$||}

NGINX_SITES:=
NGINX_CONFIGS:=	le_webroot nginx ssl local
NGINX_MAINT:=

.include "${ZEST}/_import.mk"

nginx: ${NGINX_COMMAND} clean_stale

${NGINX_COMMAND}: \
	/var/ca/dhparam.pem \
	${NGINX_SITES:%=${NGINX_ETC}/local/%.conf} \
	${NGINX_CONFIGS:%=${NGINX_ETC}/%.conf} \
	${NGINX_MAINT:%=${NGINX_ETC}/maintenance/%.html}
	nginx -t && nginx -s reload

/var/ca: _make_dir
${NGINX_ETC}: _make_dir
${NGINX_ETC}/local: _make_dir
${NGINX_ETC}/maintenance: _make_dir
.ORDER: ${NGINX_ETC} ${NGINX_ETC}/local
.ORDER: ${NGINX_ETC} ${NGINX_ETC}/maintenance

FILES:=	${NGINX_CONFIGS:%=%.conf}
DEST:=	${NGINX_ETC}
.include "${ZEST}/_copy_files.mk"

.for SITE in ${NGINX_SITES}
INSTALLED:=${INSTALLED:N${SITE}}
${NGINX_ETC}/local/${SITE}.conf: nginx/site/${SITE}.conf _text_file
.ORDER: ${NGINX_ETC}/local ${NGINX_ETC}/local/${SITE}.conf
.endfor

.for PAGE in ${NGINX_MAINT}
${NGINX_ETC}/maintenance/${PAGE}.html: nginx/${PAGE}.html ${NGINX_ETC}/maintenance _text_file
.ORDER: ${NGINX_ETC}/maintenance ${NGINX_ETC}/maintenance/${PAGE}.conf
.endfor

STALE_FILES=${INSTALLED:C|^.+$|${NGINX_ETC}/local/&.conf|g}

/var/ca/dhparam.pem: /var/ca
	openssl dhparam -dsaparam -out $@ 4096
