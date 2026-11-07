POSTFIX_ETC?=	/usr/local/etc/postfix

POSTFIX_CONFIGS+=	access aliases header_checks main.cf master.cf

postfix: ${SERVICE_POSTFIX} ${POSTFIX_ETC}

${SERVICE_POSTFIX}: postfix_rehash

${MAKEOBJDIR}/postfix_rehashed: \
	${POSTFIX_ETC}/Makefile \
	${POSTFIX_CONFIGS:%=${POSTFIX_ETC}/%}
	make -C ${POSTFIX_ETC} -j ${.MAKE.JOBS}
	touch $@

${POSTFIX_ETC}/Makefile: postfix/index.mk _text_file
.ORDER: ${POSTFIX_ETC} ${POSTFIX_ETC}/Makefile

FILES:=	${POSTFIX_CONFIGS}
DEST:=	${POSTFIX_ETC}
.include "${ZEST}/_copy_files.mk"
