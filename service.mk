# precreate services
#
# SERVICES syntax is:
# <service>:(restart|reload|stop)
#
# Also if command is started from '_' it's treated as a class we need to inherit
# (adding all commands from there into our batch)

# we don't need to create anything though
service:

.for SERVICE in ${SERVICES}
# whole string is service name/commands
SERVICE_DEF:=	${SERVICE:S|:| |g}
# first work is service name
SERVICE_NAME:=	${SERVICE_DEF:[1]}
# everything else are service commands
SERVICE_CMDS:=	${SERVICE_DEF:[2..-1]}
# creating a class for each service, it's up module to properly integrate
# that class with other configuration files
SERVICE_${SERVICE_NAME:tu}:=	${MAKEOBJDIR}/${SERVICE_NAME}.service
${SERVICE_${SERVICE_NAME:tu}}: _mark_command ${SERVICE_CMDS:M_*}
.	for SERVICE_CMD in ${SERVICE_CMDS:N_*}
SERVICE_CMD:=	${SERVICE_CMD}
	service ${SERVICE_NAME} ${SERVICE_CMD}
.	endfor
.ORDER: ${MAKEOBJDIR} ${SERVICE_${SERVICE:tu}}
.endfor
