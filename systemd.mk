# The way to manage systemd services: installing, updating, reloading, restarting
#
# SYSTEMD_SERVICE syntax is:
# <service>:(restart|reload|enable|disable|stop)=/etc/systemd/system/files.service,/other/file
#
# Later definitely need to process all of that better

# restarting/reloading individual services if their files were changed
.for SERVICE in ${SYSTEMD_SERVICES}
# splitting by equal sign (it's optional)
SERVICE_TUPLE=	${SERVICE:C|=| |}
# if no sign whole string becomes service name/commands
SERVICE_DEF:=	${SERVICE_TUPLE:[1]:S|:| |}
# first work is service name
SERVICE_NAME:=	${SERVICE_DEF:[1]}
# everything else are systemctl commands
SERVICE_CMDS:=	${SERVICE_DEF:[2..-1]}
# if we had = everything after that is comma separated list of files
SERVICE_FILES:=	${SERVICE_TUPLE:[2]:S|,| |}
# adding those to global list (for reload and copying)
SYSTEMD_FILES+=	${SERVICE_FILES}
# and creating a class for each service, it's up module to properly integrate
# that class with other configuration files
_systemd_${SERVICE_NAME}: ${SERVICE_FILES} .USEBEFORE
.	for SERVICE_CMD in ${SERVICE_CMDS}
	systemctl ${SERVICE_CMD} ${SERVICE_NAME}
.	endfor
# here individual services does not depend on global reload, but if reload
# happens it should happen before other services are restarted 
.ORDER: systemd _systemd_${SERVICE_NAME}
.endfor

# reloading systemctl if any files were changed
systemd: ${SYSTEMD_FILES}
	systemctl daemon-reload

FILES:=	${SYSTEMD_FILES}
.include "${ZEST}/_copy_files.mk"
