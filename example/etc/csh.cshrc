umask 22

set path = (/usr/local/libexec/ccache /sbin /bin /usr/sbin /usr/bin /usr/games /usr/local/sbin /usr/local/bin $HOME/bin)

#setenv CCACHE_DIR /var/db/ccache
#setenv CCACHE_PATH /usr/bin:/usr/local/bin
#setenv CCACHE_CPP2

setenv CLICOLOR
setenv EDITOR vi
setenv PAGER less
setenv BLOCKSIZE K

if ($?prompt) then
	# An interactive shell -- set some stuff up
	set autocorrect
	set autoexpand
	set autolist = ambiguous
	set autorehash
	set color
	set colorcat
	set complete
	set filec
	set history = 10000
	set savehist = (10000 merge)
	set mail = (/var/mail/$USER)

	source /usr/share/examples/tcsh/complete.tcsh
	unsetenv MANPATH

	if ( $?tcsh ) then
		bindkey "^W" backward-delete-word
		bindkey -k up history-search-backward
		bindkey -k down history-search-forward
		bindkey '\e[1;5D' backward-word
		bindkey '\e[1;5C' forward-word
	endif
	set prompt = '%B%U%n@%m\\%u%c04%b%# '
	if (-x `which exa`) then
		alias ll exa -l
		alias ls exa
	endif
	if (-x `which fortune`) then
		setenv dirlist /usr/share/games/fortune
		if (-x `which iconv`) then
			foreach dir (/usr/local/share/games/fortune/rus /usr/local/share/games/fortune /usr/local/share/games/fortune/ru_RU.KOI8-R)
				if (-d $dir) then
					setenv dirlist "$dirlist $dir"
				endif
			end
			fortune -a $dirlist | iconv -c -f koi8-u
		else
			fortune -a $dirlist
		endif
	endif
	unsetenv dirlist
endif
