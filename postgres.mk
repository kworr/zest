POSTGRES_VERSION:=14
POSTGRES_ETC=/var/db/postgres/data${POSTGRES_VERSION}

POSTGRES_CONFIGS:=	pg_hba postgresql pg_ident

.include "${ZEST}/_import.mk"

postgres: \
	${PAM_DIR}/postgres \
	${POSTGRES_CONFIGS:%=${POSTGRES_ETC}/%.conf}

${PAM_DIR}/postgres: postgres/postgres.pam _text_file

FILES:=	${POSTGRES_CONFIGS:%=%.conf}
DEST:=	${POSTGRES_ETC}
.include "${ZEST}/_copy_files.mk"
