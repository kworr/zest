DHCPD_FILES:=	/usr/local/etc/dhcpd.conf

dhcpd: ${DHCPD_COMMAND}

${DHCPD_COMMAND}: \
	${DHCPD_FILES}
	service isc-dhcpd restart

FILES:=	${DHCPD_FILES}
.include "${ZEST}/_copy_files.mk"
