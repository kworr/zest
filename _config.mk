MYHOST!=	hostname -s

NEWSYSLOG_DIR:=
NEWSYSLOG_FILES:=

SYSLOG_DIR:=
SYSLOG_FILES:=

FILE_MODE?=	644
FILE_OWNER?=
FILE_GROUP?=
DIR_MODE?=	755
DIR_OWNER?=
DIR_GROUP?=

NEW_DIRS:=

INSTALL=	install -C

OS!=	uname
USER!=	whoami

.if ${OS} == "Linux"
.MAKE.JOBS!=	nproc
.elif ${OS} == "FreeBSD" || "DragonFly"
.MAKE.JOBS!=	sysctl -n hw.ncpu
NEWSYSLOG_DIR:=	/usr/local/etc/newsyslog.conf.d
SYSLOG_DIR:=	/usr/local/etc/syslog.d
.	if empty(USER:Mroot)
INSTALL+=	-U
.	endif
.else
.error Unsupported os [${OS}], please add to _config.mk
.endif

PAM_DIR:=	/etc/pam.d
