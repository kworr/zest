# define where Zest is located
ZEST:=	${.PARSEDIR}

.include "_config.mk"

# this for temporary files (and converting service restarts to tasks)
MAKEOBJDIR:=	${.CURDIR}/obj.${USER}
.if !exists(${MAKEOBJDIR})
_MAKEOBJDIR!=	mkdir -p ${MAKEOBJDIR}
.endif
.undef _MAKEOBJDIR
.OBJDIR: ${MAKEOBJDIR}

# This one ensures files will be overwritten even if local configuration is newer
LAST_UPDATE:=	${.OBJDIR}/last.update
${LAST_UPDATE}!
	touch $@

.SILENT:
TARGETS:=

.sinclude "${.CURDIR}/_config.mk"

.if !empty(MYHOST:C|[a-zA-Z0-9-]*||)
.	error "only FQDN hostnames are supported."
.endif

.MAKE.JOBS?=1
.if !empty(.MAKE.MODE:Mcompat)
.error "ERROR: Zest doesn't support "compat" mode."
.endif

# This means the target is a path to file under OBJDIR, and should be bumped
# makes current target a one-shot command, that will be executed when any deps
# change
_mark_command: .USE
	touch $@

# Attr-aware helpers. Extra source token ZFLAGS="..." (pre-resolved install flags)
# may be provided by generated rules; defaults preserve current behavior.
# Accept global variables: $@_MODE, $@_OWNER, $@_GROUP
_text_file: .USEBEFORE ${LAST_UPDATE}
	if [ -f $@ ]; then \
		diff -u $@ ${>:[1]} || true; \
	else \
		echo '# new file $@'; \
	fi; \
	${INSTALL} ${$@_MODE:U${FILE_MODE}:@x@-m ${x}@} \
		${$@_OWNER:[1]:U${FILE_OWNER}:@x@-o ${x}@} \
		${$@_GROUP:[1]:U${FILE_GROUP}:@x@-g ${x}@} \
		${>:[1]} $@

_link_file: .USEBEFORE ${LAST_UPDATE}
	if [ -f $@ ]; then \
		ls -la $@; \
	else \
		echo '# new link $@'; \
	fi; \
	${INSTALL} -lsa ${>:[1]} $@

_make_dir: .USEBEFORE ${LAST_UPDATE}
	if [ ! -d $@ ]; then \
		echo "# new dir $@"; \
	fi; \
	${INSTALL} -d ${$@_MODE:[1]:U${DIR_MODE}:@x@-m ${x}@} \
		${$@_OWNER:[1]:U${DIR_OWNER}:@x@-o ${x}@} \
		${$@_GROUP:[1]:U${DIR_GROUP}:@x@-g ${x}@} \
		$@ > /dev/null

# The only default subdir. Everything else is added only for root and only
# through other config files
.if !empty(.TARGETS)
SUBDIR+=	${.TARGETS}
.else
SUBDIR+=	user
.endif

#### Global configuration
# for `root` - add default modules and then include host config
# also we are populating ${MYTAGS}
.if empty(USER:Nroot) && empty(.TARGETS)
NEW_DIRS+=	${NEWSYSLOG_DIR} ${SYSLOG_DIR}
.	include "${.CURDIR}/_default.mk"
.		for TAGLINE in ${TAGS}
THIS_HOST:=	${TAGLINE:C|.*=||:S|,| |g:M${MYHOST}}
.			if !empty(THIS_HOST)
MYTAGS+=	${TAGLINE:C|=.*||}
.			endif
.		endfor
.		sinclude "${.CURDIR}/_${MYHOST}.mk"
.	for TAG in ${MYTAGS}
.		sinclude "${.CURDIR}/@${TAG}.mk"
.	endfor
.endif

# now we are making SUBDIR empty for second pass, where modules can declare
# depends, this time it's order is precious, as, for example, services should
# populate variables before the module is referencing those targets
UNORDERED_SUBDIR:=	${SUBDIR}
SUBDIR:=

#### Per module configuration
# import var defines, this is for crossdependencies, when some file is for other
# service, and should be hadles correctly elsewhere
.for MOD in ${UNORDERED_SUBDIR:O:u}
MOD:=	${MOD} # for include visibility
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
SUBDIR+=	${MOD}
.endfor

# Now SUBDIR can refer to other modules twice, but we don't need to include
# them more then once, and we olready have them in a working order, so we just
# skipping duplicates
INCLUDED:=

# now the part that actually defines dependencies based on collected
# configuration
.for MOD in ${SUBDIR}
.	if empty(INCLUDED:M${MOD})
MOD:=	${MOD} # for include visibility
.		if exists(Mk/${MOD}.mk)
.			include "Mk/${MOD}.mk"
TARGETS+=	${MOD}
.		elif exists(${ZEST}/${MOD}.mk)
.			include "${ZEST}/${MOD}.mk"
TARGETS+=	${MOD}
.		else
.			warning 'Module "${MOD}" not found.'
.		endif
INCLUDED+=	${MOD}
.	endif
.endfor

# Global NEW_DIRS processing (after module aggregation): create each declared
# directory once with resolved attrs. Duplicates (same dir path) are errors.
_ZEST_SEEN_DIRS:=
TARGET_DIRS:=
.for DSPEC in ${NEW_DIRS:O:u} # if dir reqirements match we are ok with that
DIRSPEC:=	${DSPEC:C|=| |}
THIS:=	${DIRSPEC:[1]}
.	for MDIR in ${_ZEST_SEEN_DIRS:M${THIS}}
.		if ${MDIR} == ${THIS}
.			error "duplicate dir ${THIS} (${NEW_DIRS})"
.		endif
.	endfor
_ZEST_SEEN_DIRS:=	${_ZEST_SEEN_DIRS} ${THIS}
DIR_ARGS:=	${DIRSPEC:[2]:S|^:|_:|:S|::|:_:|g:S|::|:_:|g:C|:| |g}
.	if ${DIR_ARGS:[1]:N_}
${THIS}_MODE:=	${DIR_ARGS:[1]}
.	endif
.	if ${DIR_ARGS:[2]:N_}
${THIS}_OWNER:=	${DIR_ARGS:[2]}
.	endif
.	if ${DIR_ARGS:[3]:N_}
${THIS}_GROUP:=	${DIR_ARGS:[3]}
.	endif
TARGET_DIRS:=	${TARGET_DIRS} ${THIS}
${THIS}: _make_dir
.endfor
.undef _ZEST_SEEN_DIRS THIS DIRSPEC DIR_ARGS

.PHONY: ${TARGETS}
.MAIN: ${TARGETS} ${TARGET_DIRS}

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
