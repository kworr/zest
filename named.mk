NAMED_ETC?=	/usr/local/etc/namedb
INSTALLED:=	${:!cd ${NAMED_ETC}/master && find . -type f -name "*.db"!:C|^\.\/||:C|\.conf$||}

NAMED_ZONES+=	empty localhost-reverse localhost-forward bind
NAMED_CONFIGS+=	named logging acls ads generic local master

STALE_FILES+=	/etc/newsyslog.conf.d/named.conf

named: /var/log/named clean_stale ${SERVICE_NAMED} \
	${NAMED_ETC}/master

${SERVICE_NAMED}: \
	${NAMED_CONFIGS:%=${NAMED_ETC}/%.conf} \
	${NAMED_ZONES:%=${NAMED_ETC}/master/%.db}

_named_reload: .USE
	rndc reload

${NAMED_ETC}/master: _make_dir

FILES:=	${NAMED_CONFIGS:%=%.conf}
DEST:=	${NAMED_ETC}
.include "${ZEST}/_copy_files.mk"

.for ZONE in ${NAMED_ZONES:%=%.db}
${NAMED_ETC}/master/${ZONE}: named/zones/${ZONE} _text_file
.ORDER: ${NAMED_ETC}/master ${NAMED_ETC}/master/${ZONE}
INSTALLED:=${INSTALLED:N${ZONE}}
.endfor

STALE_FILES+=	${INSTALLED:C|^.+$|${NAMED_ETC}/master/&|g}

/var/log/named:
	touch $@
	chown bind:wheel $@
