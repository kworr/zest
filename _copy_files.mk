# macro to automatically define rules for file installation
#
# variables:
#  - MOD: module where to take files from
#  - FILES: names of files to install (each: path[=mode:owner:group])
#  - DEST: destination directory, if not present FILES are using full path
#
# Parses optional per-file attrs and emits install rules. Does not create dirs
# or append to NEW_DIRS; modules must declare destination dirs in NEW_DIRS.

.if empty(MOD)
.error MOD unset, need to know module
.endif

.for FSPEC in ${FILES}
FILE_SPEC:=	${FSPEC:C|=| |}
.	if empty(DEST)
MYDEST:=	${FILE_SPEC:[1]:H}
MYFILE:=	${FILE_SPEC:[1]:T}
.	else
MYDEST:=	${DEST}
MYFILE:=	${FILE_SPEC:[1]}
.	endif
# resolve file attrs (mode:owner:group), empty/omitted fields inherit defaults
FILE_ARGS:=	${FILE_SPEC:[2]:C|:| |g}

ITEM_LIST:=	${.CURDIR}/${MOD}/${MYHOST}/${MYFILE}
.	for TAG in ${MYTAGS}
ITEM_LIST+=	${.CURDIR}/${MOD}/@${TAG}/${MYFILE}
.	endfor
ITEM_LIST+=	${.CURDIR}/${MOD}/${MYFILE}
FOUND:=
.	for ITEM in ${ITEM_LIST}
.		if empty(FOUND) && exists(${ITEM})
FOUND:=	found
THIS:=	${MYDEST}/${MYFILE}
${THIS}: INST_MODE=${FILE_ARGS:[1]} ${FILE_MODE}
${THIS}: INST_OWNER=${FILE_ARGS:[2]} ${FILE_OWNER}
${THIS}: INST_GROUP=${FILE_ARGS:[3]} ${FILE_GROUP}
${THIS}: ${ITEM} _text_file
.ORDER: ${MYDEST} ${THIS}
.		endif
.	endfor
.	if empty(FOUND)
.		error No variants found for ${MYFILE} in ${.CURDIR}/${MOD}
.	endif
.endfor

# reset all variables that can change inside module
.undef DEST FILES FOUND ITEM_LIST MYDEST MYFILE FILE_SPEC THIS FILE_ARGS
