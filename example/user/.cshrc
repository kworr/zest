#!/bin/csh -
# vim:ft=csh:

setenv TOP '-a -s1'
setenv MC_SKIN darkfar
setenv SCCACHE_CACHE_SIZE 4G
setenv XCURSOR_THEME Ardoise_shadow_75
setenv XCURSOR_SIZE 32

alias ll ls -la
#alias mtr env TERM=screen-256color mtr

if (-x `which nvim`) then
	alias vi nvim
	setenv EDITOR nvim
else if (-x `which vim`) then
	alias vi vim
	setenv EDITOR vim
endif

if (-x `which bat`) then
	alias more 'bat -p --theme ansi'
	setenv PAGER 'bat -p --theme ansi'
else if (-x `which nvimpager`) then
	alias more nvimpager
	setenv PAGER nvimpager
else if (-x `which most`) then
	alias more most
	setenv PAGER most
endif
