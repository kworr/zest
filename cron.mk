CRON_FILES:=	/etc/cron.d/hourly

cron: ${CRON_COMMAND}

${CRON_COMMAND}: \
	${CRON_FILES}
	service cron restart

FILES:=	${CRON_FILES}
.include "${ZEST}/_copy_files.mk"
