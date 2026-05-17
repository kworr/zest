OPENDKIM_ETC=/usr/local/etc/mail
OPENDKIM_DB=/var/db/dkim

OPENDKIM_TABLES=KeyTable SigningTable TrustedHosts

.include "${ZEST}/_import.mk"

opendkim: ${OPENDKIM_COMMAND}

${OPENDKIM_COMMAND}: \
	${OPENDKIM_ETC}/opendkim.conf \
	${OPENDKIM_TABLES:%=${OPENDKIM_DB}/%}
	service milter-opendkim restart

${OPENDKIM_DB}: _make_dir

FILES:=	${OPENDKIM_ETC}/opendkim.conf
.include "${ZEST}/_copy_files.mk"

FILES:=	${OPENDKIM_TABLES}
DEST:=	${OPENDKIM_DB}
.include "${ZEST}/_copy_files.mk"
