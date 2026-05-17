USER_FILES:=
USER_LINKS:=

.if exists(/usr/local/bin/cargo)
# cargo
USER_FILES+=	${HOME}/.cargo/config.toml
STALE_FILES+=	${HOME}/.cargo/config

${HOME}/.cargo: _make_dir
${HOME}/.cargo/config.toml: user/cargo.toml ${HOME}/.cargo _text_file
.endif

.if exists(/usr/local/lib/libgtk-3.so)
# GTK 3.0
USER_FILES+=	${HOME}/.config/gtk-3.0/settings.ini

${HOME}/.config/gtk-3.0: _make_dir
${HOME}/.config/gtk-3.0/settings.ini: user/settings.ini ${HOME}/.config/gtk-3.0 _text_file
.endif

.if exists(/usr/local/lib/libfontconfig.so)
USER_FILES+=	${HOME}/.config/fontconfig/fonts.conf

${HOME}/.config/fontconfig: _make_dir
${HOME}/.config/fontconfig/fonts.conf: user/fonts.conf ${HOME}/.config/fontconfig _text_file
.endif

.if exists(/bin/csh)
# csh
USER_FILES+=	${HOME}/.cshrc

${HOME}/.cshrc: user/.cshrc _text_file
.endif

.if exists(/usr/local/share/icons/Ardoise_no_shadow_75)
# icons (mouse cursor)
USER_LINKS+=	${HOME}/.icons/default

${HOME}/.icons: _make_dir
${HOME}/.icons/default: /usr/local/share/icons/Ardoise_shadow_75 ${HOME}/.icons _link_file
.endif

.if exists(/usr/local/bin/tmux)
# tmux
USER_FILES+=	${HOME}/.tmux.conf \

.	if exists(user/${MYHOST}/.tmux.conf)
${HOME}/.tmux.conf: user/${MYHOST}/.tmux.conf _text_file
.	else
${HOME}/.tmux.conf: user/.tmux.conf _text_file
.	endif
.endif

.if exists(/usr/local/bin/Xorg)
# X
USER_FILES+=	${HOME}/.Xdefaults \
	${HOME}/.xinitrc

${HOME}/.Xdefaults: user/.Xdefaults _text_file
${HOME}/.xinitrc: user/.xinitrc _text_file
.endif

user: clean_stale .WAIT ${USER_FILES} ${USER_LINKS}
