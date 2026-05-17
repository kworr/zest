# imports local per-host configuration
#
# variables:
#  - MOD: module name

.if empty(MOD)
.error MOD name is not set
.endif

.if exists(${MOD}/_${MYHOST}.mk)
.include "${MOD}/_${MYHOST}.mk"
.endif
