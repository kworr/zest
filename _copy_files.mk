# macro to automatically define rules for file installation
#
# variables:
#  - MOD: module where to take files from
#  - FILES: names of files to install
#  - DEST: destination directory, if not present FILES are using full path

.if empty(MOD)
.error MOD unset, need to know module
.endif

.if empty(FILES)
.error no FILES to copy
.endif

.if empty(DEST)
.	for FILE in ${FILES}
.		if exists(${.CURDIR}/${MOD}/${MYHOST}/${FILE:T})
${FILE}: ${.CURDIR}/${MOD}/${MYHOST}/${FILE:T} _text_file
.		else
${FILE}: ${.CURDIR}/${MOD}/${FILE:T} _text_file
.		endif
.ORDER: ${FILE:H} ${FILE}
.	endfor
.else
.	for FILE in ${FILES}
.		if exists(${.CURDIR}/${MOD}/${MYHOST}/${FILE})
${DEST}/${FILE}: ${.CURDIR}/${MOD}/${MYHOST}/${FILE} _text_file
.		else
${DEST}/${FILE}: ${.CURDIR}/${MOD}/${FILE} _text_file
.		endif
.ORDER: ${DEST}/${FILE} ${DEST}
.	endfor
.endif

# reset all variables that can change inside module
DEST:=
FILES:=
