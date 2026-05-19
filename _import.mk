# imports local per-host configuration
#
# variables:
#  - MOD: module name

.if empty(MOD)
.error MOD name is not set
.endif

.-include "${.CURDIR}/${MOD}/_${MYHOST}.mk"
