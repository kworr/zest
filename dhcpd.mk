DHCPD_FILES+=	/usr/local/etc/dhcpd.conf

dhcpd: ${SERVICE_ISC-DHCPD}

${SERVICE_ISC-DHCPD}: ${DHCPD_FILES}

FILES:=	${DHCPD_FILES}
.include "${ZEST}/_copy_files.mk"
