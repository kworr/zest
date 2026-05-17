MYHOST!=	hostname -s

.MAKE.JOBS!=	sysctl -n hw.ncpu

COMMANDS:=

NEWSYSLOG_DIR:=	/usr/local/etc/newsyslog.conf.d
NEWSYSLOG_FILES:=

SYSLOG_DIR:=	/usr/local/etc/syslog.d
SYSLOG_FILES:=	

PAM_DIR:=	/etc/pam.d

INSTALL=	install -C
.if empty(USER:Mroot)
INSTALL+=	-U
.endif
INSTALL_DIR=	${INSTALL} -m 755 -d
INSTALL+=	-m 644
