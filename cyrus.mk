CYRUS_ETC?=	/usr/local/etc

CYRUS_FILES+=	imapd.conf cyrus.conf

cyrus: ${SERVICE_IMAPD} ${CYRUS_ETC}

${SERVICE_IMAPD}: ${CYRUS_FILES:%=${CYRUS_ETC}/%}

NEW_DIRS+=	${CYRUS_ETC}
FILES:=	${CYRUS_FILES}
DEST:=	${CYRUS_ETC}
.include "${ZEST}/_copy_files.mk"
