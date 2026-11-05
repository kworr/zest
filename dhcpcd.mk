DHCPCD_FILES:=	/usr/local/etc/dhcpcd.conf

dhcpcd: ${DHCPCD_COMMAND}

${DHCPCD_COMMAND}: \
	${DHCPCD_FILES}
	service dhcpcd restart

FILES:=	${DHCPCD_FILES}
.include "${ZEST}/_copy_files.mk"
