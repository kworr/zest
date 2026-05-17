CYRUS_ETC=/usr/local/etc

CYRUS_FILES:=	imapd.conf cyrus.conf

cyrus: ${IMAPD_COMMAND}

${IMAPD_COMMAND}: \
	${CYRUS_FILES:%=${CYRUS_ETC}/%}
	service imapd restart

FILES:=	${CYRUS_FILES}
DEST:=	${CYRUS_ETC}
.include "${ZEST}/_copy_files.mk"
