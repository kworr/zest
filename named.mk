NAMED_ETC=/usr/local/etc/namedb
INSTALLED=${:!cd ${NAMED_ETC}/master && find . -type f -name "*.db"!:C|^\.\/||:C|\.conf$||}

NAMED_ZONES:=	empty localhost-reverse localhost-forward bind
NAMED_CONFIGS:=	named logging acls ads generic local master

OLD_FILES:=	/etc/newsyslog.conf.d/named.conf

.include "${ZEST}/_import.mk"

named: /var/log/named clean_stale ${NAMED_COMMAND}

${NAMED_COMMAND}: \
	${NAMED_CONFIGS:%=${NAMED_ETC}/%.conf} \
	${NAMED_ZONES:%=${NAMED_ETC}/master/%.db}
	rndc reload

${NAMED_ETC}: _make_dir
${NAMED_ETC}/master: _make_dir
.ORDER: ${NAMED_ETC} ${NAMED_ETC}/master

FILES:=	${NAMED_CONFIGS:%=%.conf}
DEST:=	${NAMED_ETC}
.include "${ZEST}/_copy_files.mk"

.for ZONE in ${NAMED_ZONES:%=%.db}
${NAMED_ETC}/master/${ZONE}: named/zones/${ZONE} _text_file
.ORDER: ${NAMED_ETC}/master ${NAMED_ETC}/master/${ZONE}
INSTALLED:=${INSTALLED:N${ZONE}}
.endfor

STALE_FILES+=	${INSTALLED:C|^.+$|${NAMED_ETC}/master/&|g} ${OLD_FILES}

/var/log/named:
	touch $@
	chown bind:wheel $@
