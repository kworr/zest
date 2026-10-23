MYHOST!=	hostname -s

NEWSYSLOG_FILES:=
SYSLOG_FILES:=

INSTALL=	install -C
INSTALL_DIR:=	${INSTALL} -m 755 -d
INSTALL+=	-m 644

OS!=	uname
USER!=	whoami

.if ${OS} == "Linux"
.MAKE.JOBS!=	nproc
NEWSYSLOG_DIR:=
SYSLOG_DIR:=
.elif ${OS} == "FreeBSD"
.MAKE.JOBS!=	sysctl -n hw.ncpu
NEWSYSLOG_DIR:=	/usr/local/etc/newsyslog.conf.d
SYSLOG_DIR:=	/usr/local/etc/syslog.d
.	if empty(USER:Mroot)
INSTALL+=	-U
.	endif
.else
.error Unsupported os [${OS}], please add to _config.mk
.endif

COMMANDS:=

PAM_DIR:=	/etc/pam.d
