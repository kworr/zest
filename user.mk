USER_FILES:=
USER_LINKS:=

.if exists(/usr/local/bin/cargo)
# cargo
USER_FILES+=	${HOME}/.cargo/config.toml
STALE_FILES+=	${HOME}/.cargo/config
.endif

.if exists(/usr/local/lib/libgtk-3.so)
# GTK 3.0
USER_FILES+=	${HOME}/.config/gtk-3.0/settings.ini
.endif

.if exists(/usr/local/lib/libfontconfig.so)
USER_FILES+=	${HOME}/.config/fontconfig/fonts.conf
.endif

.if exists(/bin/csh)
# csh
USER_FILES+=	${HOME}/.cshrc
.endif

.if exists(/usr/local/share/icons/Ardoise_no_shadow_75)
# icons (mouse cursor)
USER_LINKS+=	${HOME}/.icons/default

${HOME}/.icons: _make_dir
${HOME}/.icons/default: /usr/local/share/icons/Ardoise_shadow_75 ${HOME}/.icons _link_file
.endif

.if exists(/usr/local/bin/tmux)
# tmux
USER_FILES+=	${HOME}/.tmux.conf
.endif

.if exists(/usr/local/bin/Xorg)
# X
USER_FILES+=	${HOME}/.Xdefaults \
	${HOME}/.xinitrc
.endif

FILES:=	${USER_FILES}
.include "${ZEST}/_copy_files.mk"

user: clean_stale .WAIT ${USER_FILES} ${USER_LINKS}
