# Here SYSLOG_FILES are a list of files that should be installed with full
# path to them

syslog: ${SYSLOG_COMMAND} ${SYSLOG_DIR}

${SYSLOG_COMMAND}: /etc/syslog.conf \
	${SYSLOG_FILES:T:%.syslog=${SYSLOG_DIR}/%.conf}
	service syslogd restart

FILES:=	/etc/syslog.conf
.include "${ZEST}/_copy_files.mk"

.for FILE in ${SYSLOG_FILES}
LOGFILES!=	awk '$$2~/\/.*/{print$$2}' < ${.CURDIR}/${FILE}
${FILE:T:%.syslog=${SYSLOG_DIR}/%.conf}: ${FILE} _text_file
.	for LOGFILE in ${LOGFILES:O:u}
.		if !exists(${LOGFILE})
	echo \# creating ${LOGFILE}
	touch ${LOGFILE}
.		endif
.	endfor
.endfor
