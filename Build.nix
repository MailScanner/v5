#!/usr/bin/bash

# Checked and updated to be more streamlined by
# Jerry Benton
# 3 MAY 2016

# this Build.tarball script should be located in the base
# directory when run. 

# make sure this is run from the base directory
if [ ! -d 'common' ]; then
	echo 'This script must be executed from the base directory.';
	echo './common was not found. Exiting ...';
	echo;
	exit 192
fi

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
	FULLMSVER="$MSVERSION-$MSBUILD";
	export FULLMSVER
fi

# if not set from the "Build.all" script
if [ -z "$DEVBASEDIR" ]; then
	DEVBASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	export DEVBASEDIR
fi


# version info 
VERSION=$MSVERSION-$MSBUILD
export VERSION 

# make some dirs
mkdir -p ~/msbuilds/tar

# the work directory
WORK="/tmp/MailScanner-$MSVERSION";

# delete work tmp if already exists
if [ -d $WORK ]; then
   rm -rf $WORK
fi

# make working dir and subs
mkdir -p $WORK

# etc
cp -fr $DEVBASEDIR/common/*		$WORK/

# Insert the version number we are building
perl -pi -e 's/VersionNumberHere/'$MSVERSION'/;' $WORK/etc/MailScanner/MailScanner.conf
perl -pi -e 's/VersionNumberHere/'$MSVERSION'/;' $WORK/usr/sbin/MailScanner


# remove svn and git and mac stuff
find $WORK -name '.svn' -exec rm -rf {} \;
find $WORK -name '.git' -exec rm -rf {} \;
find $WORK -name '*.DS_Store' -exec rm -rf {} \;
find $WORK -depth -name '__MACOSX' -exec rm -rf {} \;

# permissions
cd $WORK
find . -type f -exec chmod 0644 {} \;
find . -type d -exec chmod 0755 {} \;
chmod +x $WORK/usr/sbin/*
chmod +x $WORK/var/lib/MailScanner/wrapper/*-autoupdate
chmod +x $WORK/var/lib/MailScanner/wrapper/*-wrapper
chmod +x $WORK/var/lib/MailScanner/init/*

# Build the MailScanner-version.tar.gz archive
tar czf ~/msbuilds/tar/MailScanner-${VERSION}.nix.tar.gz MailScanner-$MSVERSION

cd $DEVBASEDIR
#rm -rf $WORK

