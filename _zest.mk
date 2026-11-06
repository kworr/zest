# define where Zest is located
ZEST:=	${.PARSEDIR}

# this for temporary files (and converting service restarts to tasks)
MAKEOBJDIR:=	${.CURDIR}/obj.${USER}
.OBJDIR: ${MAKEOBJDIR}

# This one ensures files will be overwritten even if local configuration is newer
LAST_UPDATE:=	${MAKEOBJDIR}/last.update
${LAST_UPDATE}! ${MAKEOBJDIR}
	touch $@

.SILENT:
TARGETS:=

.include "_config.mk"
.sinclude "${.CURDIR}/_config.mk"

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
.if !empty(.TARGETS)
SUBDIR:=	${.TARGETS}
.else
SUBDIR:=	user
.endif

# for `root` - add default modules and then include host config
# also we are populating ${MYTAGS}
.if !empty(:!whoami!:Mroot)
.	include "${.CURDIR}/_default.mk"
.	for TAGLINE in ${TAGS}
THIS_HOST:=	${TAGLINE:C|.*=||:S|,| |g:M${MYHOST}}
.		if !empty(THIS_HOST)
MYTAGS+=	${TAGLINE:C|=.*||}
.		endif
.	endfor
.	sinclude "${.CURDIR}/_${MYHOST}.mk"
.	for TAG in ${MYTAGS}
.		sinclude "${.CURDIR}/@${TAG}.mk"
.	endfor
.endif

# import var defines, this is for crossdependencies, when some file is for other
# service, and should be hadles correctly elsewhere
.for MOD in ${SUBDIR}
.	if exists(Mk/${MOD}.var.mk)
.		include "Mk/${MOD}.var.mk"
.	elif exists(${ZEST}/${MOD}.var.mk)
.		include "${ZEST}/${MOD}.var.mk"
.	endif
.	-include "${.CURDIR}/${MOD}/_default.mk"
.	-include "${.CURDIR}/${MOD}/_${MYHOST}.mk"
.	for TAG in ${MYTAGS}
.		-include "${.CURDIR}/${MOD}/@${TAG}.mk"
.	endfor
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
.for MOD in ${SUBDIR}
MOD:=	${MOD} # for include visibility
.	if exists(Mk/${MOD}.mk)
.		include "Mk/${MOD}.mk"
TARGETS+=	${MOD}
.	elif exists(${ZEST}/${MOD}.mk)
.		include "${ZEST}/${MOD}.mk"
TARGETS+=	${MOD}
.	else
.		warning 'Module "${MOD}" not found.'
.	endif
.endfor

.PHONY: ${TARGETS}
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
