.PHONY: all
.MAIN: all

FILES:=access aliases canonical generic mx transport passwd virtual_domains
DB_TYPE:=cdb

# plainly generating all except 'aliases'
INDICES:=
.for file in ${FILES:Naliases}
.	if exists(${file})
INDICES+=${file:S/$/.${DB_TYPE}/}
.	endif
.endfor

${INDICES}: ${@:R}
	postmap $>

.if ${FILES:Maliases}
INDICES+=	aliases.cdb
aliases.cdb: aliases
	/usr/local/bin/newaliases
.endif

.if exists(virtual_custom)
INDICES+=	virtual.cdb
virtual.cdb: virtual_domains virtual_custom
	printf "# The file is regenerated automatically, changes are discarded!!!\n\n" > virtual
	awk 'BEGIN{mboxes[0]="abuse";mboxes[1]="hostmaster";mboxes[2]="postmaster";mboxes[3]="webmaster"}$$1~/^[^#]/{if($$3~/^#$$/)next;print"# "$$1;for(mbox in mboxes)print mboxes[mbox]"@"$$1" "mboxes[mbox];print""}' < virtual_domains >> virtual
	cat virtual_custom >> virtual
	postmap virtual
.elif exists(virtual)
INDICES+=	virtual.cdb
virtual.cdb: virtual
	postmap $>
.endif

all: ${INDICES}
	postfix reload
