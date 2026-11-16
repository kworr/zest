DHCPCD_FILES+=	/usr/local/etc/dhcpcd.conf

dhcpcd: ${SERVICE_DHCPCD}

${SERVICE_DHCPCD}: ${DHCPCD_FILES}

NEW_DIRS+=	${DHCPCD_FILES:H:O:u}

FILES:=	${DHCPCD_FILES}
.include "${ZEST}/_copy_files.mk"
