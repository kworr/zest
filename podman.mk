PODMAN_CONTAINERS?=
PODMAN_FILES+=	/usr/local/etc/containers/containers.conf

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

podman: ${PODMAN_TARGETS}

${PODMAN_TARGETS}: ${SERVICE_PODMAN_SERVICE}

${SERVICE_PODMAN_SERVICE}: ${PODMAN_FILES}

FILES:=	${PODMAN_FILES}
.include "${ZEST}/_copy_files.mk"
