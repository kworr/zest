ETC_FILES:=	\
	/etc/csh.cshrc \
	/etc/motd.template \
	/etc/periodic.conf \
	/etc/periodic.local
ETC_FILES_RESOLVCONF:=	/etc/resolvconf.conf

etc: ${ETC_FILES} ${ETC_RESOLVCONF_COMMAND}

${ETC_RESOLVCONF_COMMAND}: ${ETC_FILES_RESOLVCONF}
	resolvconf -u

FILES:=	${ETC_FILES} ${ETC_FILES_RESOLVCONF}
.include "${ZEST}/_copy_files.mk"
