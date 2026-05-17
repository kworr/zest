SSHD_ETC:=	/etc/ssh

.include "${ZEST}/_import.mk"

YEAR_AGO!=date -v -365d +%s
MODULI_FLAG=${SSHD_ETC}/.moduli_4096_generated
.if exists(${MODULI_FLAG})
MODULI_CHANGE!=stat -f%m ${MODULI_FLAG}
.else
MODULI_CHANGE=0
.endif

${SSHD_ETC}/ssh_host_rsa_key:
	ssh-keygen -q -N "" -t rsa -b 4096 -f ${SSHD_ETC}/ssh_host_rsa_key

${SSHD_ETC}/ssh_host_ed25519_key:
	ssh-keygen -q -N "" -t ed25519 -f ${SSHD_ETC}/ssh_host_ed25519_key

sshd: \
	${SSHD_ETC}/ssh_host_rsa_key \
	${SSHD_ETC}/ssh_host_ed25519_key \
	${SSHD_ETC}/server_ca.pub \
	${SSHD_ETC}/ssh_config \
	${SSHD_ETC}/sshd_config \
	${SSHD_ETC}/ssh_known_hosts
	rm -f ${SSHD_ETC}/ssh_host_ecdsa_*

moduli:
	cd ${SSHD_ETC}/ && \
	test ${YEAR_AGO} -lt ${MODULI_CHANGE} || ( \
	ssh-keygen -M generate -O bits=4096 moduli-4096.candidates && \
	ssh-keygen -M screen -f moduli-4096.candidates moduli-4096 && \
	mv moduli-4096 ${SSHD_ETC}/moduli && \
	touch .moduli_4096_generated && \
	rm -f moduli-4096.candidates )

${SSHD_ETC}/server_ca.pub: sshd/server_ca.pub_${CA} _text_file

${SSHD_ETC}/ssh_config: sshd/ssh_config _text_file

${SSHD_ETC}/ssh_known_hosts: sshd/ssh_known_hosts _text_file

.if empty(SSHD_PORTS)
${SSHD_ETC}/sshd_config: sshd/sshd_config_root _text_file
.else
${SSHD_ETC}/sshd_config: sshd/sshd_config _text_file
.endif
