DHCPCD_FILES+=	/usr/local/etc/dhcpcd.conf

dhcpcd: ${SERVICE_DHCPCD}

${SERVICE_DHCPCD}: ${DHCPCD_FILES}

FILES:=	${DHCPCD_FILES}
.include "${ZEST}/_copy_files.mk"
