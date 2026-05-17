# define where Zest is located
ZEST=	${.PARSEDIR}

# this for temporary files (and converting service restarts to tasks)
MAKEOBJDIR:=	${.CURDIR}/obj.${.MAKE.UID}
.OBJDIR: ${MAKEOBJDIR}

# This one ensures files will be overwritten even if local configuration is newer
LAST_UPDATE:=	${MAKEOBJDIR}/last.update
${LAST_UPDATE}!
	touch $@

.SILENT:
TARGETS:=

.include "${ZEST}/_config.mk"
.if exists(_config.mk)
.	include "_config.mk"
.endif

.MAKE.JOBS?=1
.if !empty(.MAKE.MODE:Mcompat)
.error "ERROR: Zest doesn't support "compat" mode."
.endif

_mark_command: .USE
	touch $@

_text_file: .USEBEFORE ${LAST_UPDATE}
	if [ -f $@ ]; then \
		diff -u $@ ${>:[1]} || true; \
	else \
		echo '# new file $@'; \
	fi
	${INSTALL} ${>:[1]} $@

_link_file: .USEBEFORE ${LAST_UPDATE}
	${INSTALL} -lsa ${>:[1]} $@

_make_dir: .USEBEFORE
	${INSTALL_DIR} $@

.for DIR in ${NEWSYSLOG_DIR} ${SYSLOG_DIR} ${MAKEOBJDIR}
.	if !exists(${DIR})
${DIR}: _make_dir
TARGETS+=	${DIR}
.	endif
.endfor

# The only default subdir. Everything else is added only for root and only
# through other config files
SUBDIR:=	user

# for `root` - add default modules and then include host config
.if !empty(:!whoami!:Mroot)
.	include "_default.mk"
.	if exists(_${MYHOST}.mk)
.		include "_${MYHOST}.mk"
.	endif
.endif

# import var defines, this is for crossdependencies, when some file is for other
# service, and should be hadles correctly elsewhere
.for DIR in ${SUBDIR}
.	if exists(Mk/${DIR}.var.mk)
.		include "Mk/${DIR}.var.mk"
.	elif exists(${ZEST}/${DIR}.var.mk)
.		include "${ZEST}/${DIR}.var.mk"
.	endif
.endfor

# precreate commands, should be split in separate step if more then one module
# would require to precreate some targets based on vars
.for COMMAND in ${COMMANDS}
${COMMAND:tu}_COMMAND:=	${MAKEOBJDIR}/${COMMAND}.restarted
${${COMMAND:tu}_COMMAND}: _mark_command
.ORDER: ${MAKEOBJDIR} ${${COMMAND:tu}_COMMAND}
.endfor

# now the part that actually defines dependencies based on collected
# configuration
.for DIR in ${SUBDIR}
.	if exists(Mk/${DIR}.var.mk)
MOD:= ${DIR}
.		include "Mk/${DIR}.var.mk"
TARGETS+=	${DIR}
.PHONY: ${DIR}
.	elif exists(${ZEST}/${DIR}.mk)
MOD:= ${DIR}
.		include "${ZEST}/${DIR}.mk"
TARGETS+=	${DIR}
.PHONY: ${DIR}
.	else
.		warning 'Module "${DIR}" not found under.'
.	endif
.endfor

.MAIN: ${TARGETS}

clean_stale: clean_files clean_dirs

clean_files:
.for FILE in ${STALE_FILES}
.	if exists(${FILE})
	echo "\# rm ${FILE}"; \
	rm -f ${FILE}
.	endif
.endfor

clean_dirs:
.for DIR in ${STALE_DIRS}
.	if exists(${DIR})
	echo "\# rm -rf ${DIR}"; \
	rm -rf ${DIR}
.	endif
.endfor
