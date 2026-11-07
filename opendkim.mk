OPENDKIM_ETC=/usr/local/etc/mail
OPENDKIM_DB=/var/db/dkim

OPENDKIM_TABLES=KeyTable SigningTable TrustedHosts

opendkim: ${SERVICE_OPENDKIM}

${SERVICE_OPENDKIM}: \
	${OPENDKIM_ETC}/opendkim.conf \
	${OPENDKIM_TABLES:%=${OPENDKIM_DB}/%}

${OPENDKIM_DB}: _make_dir

FILES:=	${OPENDKIM_ETC}/opendkim.conf
.include "${ZEST}/_copy_files.mk"

FILES:=	${OPENDKIM_TABLES}
DEST:=	${OPENDKIM_DB}
.include "${ZEST}/_copy_files.mk"
