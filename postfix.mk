POSTFIX_ETC=/usr/local/etc/postfix

POSTFIX_CONFIGS:=	access aliases header_checks main.cf master.cf

.include "${ZEST}/_import.mk"

postfix: ${POSTFIX_COMMAND}

${POSTFIX_COMMAND}: \
	${POSTFIX_ETC}/Makefile \
	${POSTFIX_CONFIGS:%=${POSTFIX_ETC}/%}
	make -C ${POSTFIX_ETC} -j ${.MAKE.JOBS}

${POSTFIX_ETC}: _make_dir

${POSTFIX_ETC}/Makefile: postfix/index.mk _text_file
.ORDER: ${POSTFIX_ETC} ${POSTFIX_ETC}/Makefile

FILES:=	${POSTFIX_CONFIGS}
DEST:=	${POSTFIX_ETC}
.include "${ZEST}/_copy_files.mk"
