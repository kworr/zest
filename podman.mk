PODMAN_CONTAINERS=
PODMAN_FILES=	/usr/local/etc/containers/containers.conf

.include "${ZEST}/_import.mk"

.for STACK in ${PODMAN_CONTAINERS}
.	if exists(${MOD}/${STACK})
PODMAN_TARGETS+=	${MOD}_${STACK}
PODMAN_TARGET_DIR:=	${.CURDIR}/${MOD}/${STACK}
# XXX Add tracking via obj dir, or leave as it is, making a full run
# automatically an update attempt
${MOD}_${STACK}: .PHONY
	echo '# Composing ${STACK}'; \
	cd ${PODMAN_TARGET_DIR}; \
	podman compose up -d --pull
.	endif
.endfor

podman: ${PODMAN_SERVICE_COMMAND} .WAIT ${PODMAN_TARGETS}
${PODMAN_SERVICE_COMMAND}: ${PODMAN_FILES}
	service podman_service restart

FILES:=	${PODMAN_FILES}
.include "${ZEST}/_copy_files.mk"
