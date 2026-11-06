# macro to automatically define rules for file installation
#
# variables:
#  - MOD: module where to take files from
#  - FILES: names of files to install
#  - DEST: destination directory, if not present FILES are using full path

.if empty(MOD)
.error MOD unset, need to know module
.endif

.if empty(DEST)
.	for FILE in ${FILES}
ITEM_LIST:=	${.CURDIR}/${MOD}/${MYHOST}/${FILE:T}
.		for TAG in ${MYTAGS}
ITEM_LIST+=	${.CURDIR}/${MOD}/@${TAG}/${FILE:T}
.		endfor
ITEM_LIST+=	${.CURDIR}/${MOD}/${FILE:T}
FOUND:=
.		for ITEM in ${ITEM_LIST}
.			if empty(FOUND) && exists(${ITEM})
FOUND:=	found
${FILE}: ${ITEM} _text_file
.			endif
.		endfor
.ORDER: ${FILE:H} ${FILE}
.		if empty(FOUND)
.			error "No variants found for ${FILE} in ${.CURDIR}/${MOD}
.		endif
.	endfor
.else
.	for FILE in ${FILES}
ITEM_LIST:=	${.CURDIR}/${MOD}/${MYHOST}/${FILE}
.		for TAG in ${MYTAGS}
ITEM_LIST+=	${.CURDIR}/${MOD}/@${TAG}/${FILE}
.		endfor
ITEM_LIST+=	${.CURDIR}/${MOD}/${FILE}
FOUND:=
.		for ITEM in ${ITEM_LIST}
.			if empty(FOUND) && exists(${ITEM})
FOUND:=	found
${DEST}/${FILE}: ${ITEM} _text_file
.			endif
.		endfor
.ORDER: ${DEST} ${DEST}/${FILE}
.		if empty(FOUND)
.			error "No variants found for ${DEST}/${FILE} in ${.CURDIR}/${MOD}
.		endif
.	endfor
.endif

# reset all variables that can change inside module
.undef DEST FILES FOUND ITEM_LIST
