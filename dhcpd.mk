DHCPD_FILES+=	/usr/local/etc/dhcpd.conf

dhcpd: ${SERVICE_ISC-DHCPD}

${SERVICE_ISC-DHCPD}: ${DHCPD_FILES}

NEW_DIRS+=	${DHCPD_FILES:H:O:u}

FILES:=	${DHCPD_FILES}
.include "${ZEST}/_copy_files.mk"
