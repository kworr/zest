# macro to automatically define rules for file installation
#
# variables:
#  - MOD: module where to take files from
#  - FILES: names of files to install
#  - DEST: destination directory, if not present FILES are using full path

.if empty(MOD)
.error MOD unset, need to know module
.endif

.for FILE in ${FILES}
.	if empty(DEST)
MYDEST:=	${FILE:H}
MYFILE:=	${FILE:T}
.	else
MYDEST:=	${DEST}
MYFILE:=	${FILE}
.	endif
ITEM_LIST:=	${.CURDIR}/${MOD}/${MYHOST}/${MYFILE}
.	for TAG in ${MYTAGS}
ITEM_LIST+=	${.CURDIR}/${MOD}/@${TAG}/${MYFILE}
.	endfor
ITEM_LIST+=	${.CURDIR}/${MOD}/${MYFILE}
FOUND:=
.	for ITEM in ${ITEM_LIST}
.		if empty(FOUND) && exists(${ITEM})
FOUND:=	found
${MYDEST}/${MYFILE}: ${ITEM} _text_file
.ORDER: ${MYDEST} ${MYDEST}/${MYFILE}
.		endif
.	endfor
.	if empty(FOUND)
.		error "No variants found for ${MYFILE} in ${.CURDIR}/${MOD}
.	endif
.endfor

# reset all variables that can change inside module
.undef DEST FILES FOUND ITEM_LIST MYDEST MYFILE
