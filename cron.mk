CRON_FILES:=	/etc/cron.d/hourly

cron: ${SERVICE_CRON}

${SERVICE_CRON}: ${CRON_FILES}

FILES:=	${CRON_FILES}
.include "${ZEST}/_copy_files.mk"
