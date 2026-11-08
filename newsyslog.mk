newsyslog: ${NEWSYSLOG_FILES:T:%.newsyslog=${NEWSYSLOG_DIR}/%.conf}

.for FILE in ${NEWSYSLOG_FILES}
TARGET_FILE=	${FILE:T:%.newsyslog=${NEWSYSLOG_DIR}/%.conf}
${TARGET_FILE}: ${FILE} _text_file
.ORDER: ${NEWSYSLOG_DIR} ${TARGET_FILE}
.endfor
