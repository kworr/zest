# The way to manage systemd services: installing, updating, reloading,
# restarting
#
# SYSTEMD_SERVICES syntax is:
# <service>:(restart|reload|enable|disable|stop)=module:/etc/systemd/system/files.service,/other/file
#
# SYSTEMD_SERVICES_PRE syntax is:
# <service>:(restart|reload|enable|disable|stop)=version
#
# The difference is: PRE runs before systemd was reloaded, operating on
# currently active services
#
# Later definitely need to process all of that better

SYSTEMD_FILES:=

.for LIST in SYSTEMD_SERVICES SYSTEMD_SERVICES_PRE
# restarting/reloading individual services if their files were changed
.	for SERVICE in ${${LIST}}
# splitting by equal sign (it's optional)
SERVICE_TUPLE=	${SERVICE:C|=| |}
# if no sign whole string becomes service name/commands
SERVICE_DEF:=	${SERVICE_TUPLE:[1]:S|:| |g}
# first work is service name
SERVICE_NAME:=	${SERVICE_DEF:[1]}
# everything else are systemctl commands
SERVICE_CMDS:=	${SERVICE_DEF:[2..-1]}
SERVICE_FILES:=
# precreating postfix, so we can insert it into service flag name
${LIST:C|ES|E|}_${SERVICE_NAME:tu}=	${.OBJDIR}/${SERVICE_NAME}.systemd${${LIST}_POSTFIX_${SERVICE_NAME:tu}}
# if we have something after = that's files
.		if ${LIST} == SYSTEMD_SERVICES
.			if !empty(SERVICE_TUPLE:[2])
# before the files there's a module name to search for those files
SERVICE_DEPS:=	${SERVICE_TUPLE:[2]:S|:| |g}
SERVICE_MODULE:=	${SERVICE_DEPS:[1]}
# if we had = everything after that is comma separated list of files
SERVICE_FILES:=	${SERVICE_DEPS:[2]:S|,| |g}
# adding those to global list (for reload and copying)
SYSTEMD_FILES:=	${SYSTEMD_FILES} ${SERVICE_FILES}
.			endif
.ORDER: ${.OBJDIR}/systemd.reloaded ${SYSTEMD_SERVICE_${SERVICE_NAME:tu}}
.			if !empty(SERVICE_FILES)
NEW_DIRS:=	${NEW_DIRS} ${SERVICE_FILES:H:O:u}
FILES:=	${SERVICE_FILES}
MOD:=	${SERVICE_MODULE}
.				include "${ZEST}/_copy_files.mk"
.			endif
.		else
${LIST}_POSTFIX_${SERVICE_NAME:tu}:=	.pre.${SERVICE_TUPLE:[2]}
.ORDER: ${SYSTEMD_SERVICE_PRE_${SERVICE_NAME:tu}} ${.OBJDIR}/systemd.reloaded
.		endif
# materializing service name, so that other services can depend on it
${LIST:C|ES|E|}_${SERVICE_NAME:tu}:=	${${LIST:C|ES|E|}_${SERVICE_NAME:tu}}
# and creating a class for each service, it's up module to properly integrate
# that class with other configuration files
${${LIST:C|ES|E|}_${SERVICE_NAME:tu}}: ${SERVICE_FILES} _mark_command
.		for SERVICE_CMD in ${SERVICE_CMDS}
	echo '\# ${SERVICE:C|:.*||}: [${SERVICE_CMD}]'
	systemctl ${SERVICE_CMD} ${SERVICE:C|:.*||}
.		endfor
.	endfor
.endfor

# reloading systemctl if any files were changed
${.OBJDIR}/systemd.reloaded: ${SYSTEMD_FILES} _mark_command
	echo '\# Reloading systemctl configuration…'
	systemctl daemon-reload

systemd: ${.OBJDIR}/systemd.reloaded
