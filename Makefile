all: .SILENT
	echo '# This file creates a sample zest script for your config tree'
	echo '# Make sure to update it when base repo is changed or moved'
	echo
	echo '.include "'${.CURDIR}'/_zest.mk"'
