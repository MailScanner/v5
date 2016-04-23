#!/usr/bin/env bash

# Checked and updated to be more streamlined by
# Jerry Benton
# 24 FEB 2015

# this Build.tarball script should be located in the base
# directory when run. Example: /msdev/v4/Build.tarball

# make sure this is run from the base directory
if [ ! -d 'config.index' ]; then
	echo 'This script must be executed from the base directory.';
	echo './config.index was not found. Exiting ...';
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

# create this if missing
if [ ! -a '/tmp/MailScanner.conf.index.html' ]; then
	sh $DEVBASEDIR/config.index/make.sh
	cd $DEVBASEDIR
fi

# set stuff
# export NUMBER=$MSVERSION
export VERSION=MailScanner-$MSVERSION
export INSTALL=MailScanner-install-$MSVERSION
export RELEASE=$MSBUILD
export BUILDROOT=$HOME/msbuilds/tar

# make some dirs
mkdir -p $BUILDROOT
rm -rf $BUILDROOT/$VERSION-$RELEASE
mkdir -p $BUILDROOT/$VERSION-$RELEASE

# Put the docs in place
#tar cf - www/README README | ( cd $BUILDROOT/$VERSION-$RELEASE && tar xvBpf - )
cd $DEVBASEDIR
cp /tmp/MailScanner.conf.index.html $BUILDROOT/$VERSION-$RELEASE

# module check script
cp $DEVBASEDIR/check_modules.sh $BUILDROOT/$VERSION-$RELEASE
chmod 0755 $BUILDROOT/$VERSION-$RELEASE/check_modules.sh

# Put all the subdirs (including the code) in place
( cd mailscanner && tar cf - . ) | ( cd $BUILDROOT/$VERSION-$RELEASE && tar xvBpf - )
ln -s ms-upgrade-conf $BUILDROOT/$VERSION-$RELEASE/bin/upgrade_languages_conf

# Copy all the cron jobs into the cron dir
mkdir -p $BUILDROOT/$VERSION-$RELEASE/bin/cron
cp RPM.files/common/*cron $BUILDROOT/$VERSION-$RELEASE/bin/cron
perl -pi -e 's/\/usr\/sbin/\/opt\/MailScanner\/bin/g;' $BUILDROOT/$VERSION-$RELEASE/bin/cron/*

cd $BUILDROOT/$VERSION-$RELEASE
## Copy in the old (working) ms-check script
# And fix the paths in it and the scanners updater script
perl -pi - bin/ms-check <<EOF2
s/process=mailscanner/process=MailScanner/;
s/mailscanner.conf/MailScanner.conf/;
EOF2

# Get rid of Subversion dirs, autoconf files and useless tnef sources
find . -type d -name '.svn' -exec rm -rf {} \;
find . -type d -name '.git' -exec rm -rf {} \;
rm -f bin/tnef*tar.gz
find . -type f -name '*.in' -print -exec rm -f {} \;

# Add the -I to the start of the main perl script so it gets all its libs
perl -pi - $BUILDROOT/$VERSION-$RELEASE/bin/mailscanner.sbin <<EOF
s./usr/bin/perl$./usr/bin/perl -U -I/var/lib/MailScanner/.;
EOF

# Set the default path to the SA cache file
perl -pi - $BUILDROOT/$VERSION-$RELEASE/bin/ms-sa-cache <<EOF
s./etc/MailScanner./etc/MailScanner.;
EOF

# Insert the version number we are building
perl -pi -e 's/VersionNumberHere/'$MSVERSION'/;' etc/mailscanner.conf

# do the same for the mailscanner.sbin
perl -pi -e 's/VersionNumberHere/'$MSVERSION'/;' bin/mailscanner.sbin


# Move all the bin/MailScanner to lib/MailScanner
mv bin/MailScanner lib/MailScanner
# And the top-level perl module
mv bin/MailScanner.pm lib/MailScanner.pm
# Rename the main MS script to MailScanner
mv bin/mailscanner.sbin bin/MailScanner
# Rename the main MS config file
mv etc/mailscanner.conf etc/MailScanner.conf

cd $BUILDROOT
# Set the permissions correctly
cd $VERSION-$RELEASE
find . -type f -print | xargs chmod a-x
chmod a+x bin/* bin/cron/*
chmod a+x lib/*-wrapper lib/*-autoupdate
cd ..
# Build the MailScanner-version.tar.gz archive
tar czf $VERSION-$RELEASE.tar.gz $VERSION-$RELEASE

#
# Now wrap it all up in the new installer tar ball
#

rm -rf $BUILDROOT/$INSTALL
mkdir -p $BUILDROOT/$INSTALL/FreeBSD
mkdir -p $BUILDROOT/$INSTALL/OpenBSD
cd $BUILDROOT/$INSTALL
mkdir perl-tar
cd $DEVBASEDIR
cp installer/install.sh $BUILDROOT/$INSTALL
cp README $BUILDROOT/$INSTALL
cp mailscanner/LICENSE $BUILDROOT/$INSTALL
cp FreeBSD/INSTALL.FreeBSD $BUILDROOT/$INSTALL/FreeBSD
cp FreeBSD/rc.MailScanner $BUILDROOT/$INSTALL/FreeBSD
cp OpenBSD/INSTALL.OpenBSD $BUILDROOT/$INSTALL/OpenBSD
cp changelog $BUILDROOT/$INSTALL
chmod 0755 $BUILDROOT/$INSTALL/install.sh
#cp mailscanner/bin/CheckModuleVersion $BUILDROOT/$INSTALL
#cp mailscanner/bin/getPERLLIB $BUILDROOT/$INSTALL
#cp mailscanner/bin/ms-peek $BUILDROOT/$INSTALL
#chmod 0755 $BUILDROOT/$INSTALL/CheckModuleVersion
#chmod 0755 $BUILDROOT/$INSTALL/getPERLLIB
#chmod 0755 $BUILDROOT/$INSTALL/ms-peek
#cp RPM.files/perl-module-src/*tar.gz $BUILDROOT/$INSTALL/perl-tar
# Now remove the odd exception - this saves download time!
#rm -f $BUILDROOT/$INSTALL/perl-tar/MIME-tools-5.411.tar.gz
#cp mailscanner/bin/tnef-1.4.5*tar.gz $BUILDROOT/$INSTALL/perl-tar
cp $BUILDROOT/$VERSION-$RELEASE.tar.gz $BUILDROOT/$INSTALL/perl-tar
chmod 0644 $BUILDROOT/$INSTALL/perl-tar/*tar.gz

cd $BUILDROOT
tar czf mailscanner-$MSVERSION-$MSBUILD.tar.gz $INSTALL
rm -rf $BUILDROOT/$VERSION-$RELEASE.tar.gz
rm -rf $BUILDROOT/$VERSION-$RELEASE
rm -rf $BUILDROOT/$INSTALL
mv mailscanner-$MSVERSION-$MSBUILD.tar.gz MailScanner-$MSVERSION-$MSBUILD.tar.gz
