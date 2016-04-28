#!/bin/bash

# if not set from the "Build.all" script
if [ -z "$MSVERSION" ]; then
	echo "Please tell me the version number (x.xx.x):"
	read MSVERSION
	export MSVERSION
fi

# if not set from the "Build.all" script
if [ -z "$MSBUILD" ]; then
	echo "And the build number (-x):"
	read MSBUILD	
	export MSBUILD
fi

# if not set from the "Build.all" script
if [ -z "$FULLMSVER" ]; then
	FULLMSVER=$MSVERSION-$MSBUILD
	export FULLMSVER
fi

# this was set in the Build.all script. will switch directories if script is not being run locally
if [ ! -z "$DEVBASEDIR" ]; then
	cd $DEVBASEDIR/config.index
fi

# the php files below should be in the same directory
php -q create_conf_array.php > /tmp/conf_array.php
php-cgi -f dump_config.php v=$FULLMSVER > /tmp/MailScanner.conf.index.html

