#!/usr/bin/env bash
#
# MailScanner installation script for Debian based systems
# 
# This script installs the required software for
# MailScanner via apt-get and CPAN based on user input.  
#
#
# Written by:
# Jerry Benton < mailscanner@mailborder.com >
# 26 APR 2016

# clear the screen. yay!
clear

# where i started for RPM install
THISCURRPMDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Function used to Wait for n seconds
timewait () {
	DELAY=$1
	sleep $DELAY
}

# Check for root user
if [ $(whoami) != "root" ]; then
	clear
	echo;
	echo "Installer must be run as root. Aborting. Use 'su -' to switch to the root environment."; echo;
	exit 192
fi

# bail if apt-get is not installed
if [ ! -x '/usr/bin/apt-get' ]; then
	clear
	echo;
	echo "apt-get package manager is not installed. You must install this before starting";
	echo "the MailScanner installation process. Installation aborted."; echo;
	exit 192
else
	APTGET='/usr/bin/apt-get';
fi

# user info screen before the install process starts
echo "MailScanner Installation for Debian Based Systems"; echo; echo;
echo "This will INSTALL or UPGRADE the required software for MailScanner on Debian based systems";
echo "via the Apt package manager. Supported distributions are Debian and associated variants";
echo "such as Ubuntu. Internet connectivity is required for this installation script to execute."; 
echo;
echo "	WARNING - Make a backup of any custom configuration files if upgrading - WARNING";
echo;
echo "You may press CTRL + C at any time to abort the installation. Note that you may see";
echo "some errors during the perl module installation. You may safely ignore errors regarding";
echo "failed tests for optional packages."; echo;
echo "When you are ready to continue, press return ... ";
read foobar

# if already installed, offer to upgrade the mailscanner.conf
AUTOUPGRADE=0
if [ -f '/etc/MailScanner/MailScanner.conf' ]; then
	clear
	echo;
	echo "Automatically upgrade MailScanner.conf?"; echo;
	echo "Based on a system analysis, I think you are performing an upgrade. Would you like to";
	echo "automatically upgrade /etc/MailScanner/MailScanner.conf to the new version? If you ";
	echo "elect not to upgrade it automatically, you will need to manually run the upgrade";
	echo "script after installation. If this in fact a new installation and not an upgrade, you";
	echo "can just enter 'N' or 'no' to ignore this.";
	echo;
	echo "Recommended: Y (yes)"; echo;
	read -r -p "Auto upgrade MailScanner.conf? [n/Y] : " response
	
	if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
		# user wants to auto upgrade mailscanner.conf
		AUTOUPGRADE=1
	elif [ -z $response ]; then    
		# user wants to auto upgrade mailscanner.conf
		AUTOUPGRADE=1
    else
    	# no auto upgrade
    	AUTOUPGRADE=0
    fi
    
    # set this to automatically answer conf files questions
    CONFFILES="--force-confold"
   
else
	# new install
	CONFFILES=
fi

# ask if the user wants an mta installed
clear
echo;
echo "Do you want to install a Mail Transfer Agent (MTA)?"; echo;
echo "I can install an MTA via the apt package manager to save you the trouble of having to do";
echo "this later. If you plan on using an MTA that is not listed below, you will have install ";
echo "it manually yourself if you have not already done so.";
echo;
echo "1 - sendmail";
echo "2 - postfix";
echo "3 - exim";
echo "N - Do not install";
echo;
echo "Recommended: 1 (sendmail)"; echo;
read -r -p "Install an MTA? [1] : " response

if [[ $response =~ ^([nN][oO])$ ]]; then
    # do not install
    MTAOPTION=
elif [ -z $response ]; then    
	# sendmail default
    MTAOPTION="sendmail";
elif [ $response == 1 ]; then    
	# sendmail 
    MTAOPTION="sendmail";    
elif [ $response == 2 ]; then    
	# sendmail 
    MTAOPTION="postfix";
elif [ $response == 3 ]; then    
	# sendmail 
    MTAOPTION="exim4-base";        
else
	MTAOPTION=
fi

# clamav
clear
echo;
echo "Do you want to install or update Clam AV during this installation process?"; echo;
echo "This package is recommended unless you plan on using a different virus scanner.";
echo "Note that you may use more than one virus scanner at once with MailScanner.";
echo;
echo "Even if you already have Clam AV installed you should select this option so I";
echo "will know to check the clamav-wrapper and make corrections if required.";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install or update Clam AV? [n/Y] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
	# user wants clam av installed
	# some of these options may result in a 'no package available' on
	# some distributions, but that is ok
	CAV=1
	CAVOPTION="clamav-daemon libclamav-client-perl";
elif [ -z $response ]; then  
	CAV=1
	CAVOPTION="clamav-daemon libclamav-client-perl";
else
	# user does not want clam av
	CAV=0
	CAVOPTION=
fi

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I will attempt to install Perl modules via apt, but some may not be unavailable during the";
echo "installation process. Missing modules will likely cause MailScanner to malfunction.";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install missing Perl modules via CPAN? [n/Y] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # user wants to use CPAN for missing modules
	CPANOPTION=1
	
	# rpm install will fail if the modules were not installed via RPM
	# so i am setting the --nodeps flag here since the user elected to 
	# use CPAN to remediate the modules
	NODEPS='--nodeps';
elif [ -z $response ]; then 
	 # user wants to use CPAN for missing modules
	CPANOPTION=1
	
	# rpm install will fail if the modules were not installed via RPM
	# so i am setting the --nodeps flag here since the user elected to 
	# use CPAN to remediate the modules
	NODEPS='--nodeps';
else
    # user does not want to use CPAN
    CPANOPTION=0
fi

# ask if the user wants to ignore dependencies. they are automatically ignored
# if the user elected the CPAN option as explained above
clear
echo;
echo "Do you want to ignore MailScanner dependencies?"; echo;
echo "This will force install the MailScanner .deb package regardless of missing"; 
echo "dependencies. It is highly recommended that you DO NOT do this unless you"; 
echo "are debugging.";
echo;
echo "Recommended: N (no)"; echo;
read -r -p "Ignore MailScanner dependencies (nodeps)? [y/N] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
	# user wants to ignore deps
	NODEPS='--force'
else
	# requiring deps
	NODEPS=
fi

# ask if the user wants to add a ramdisk
clear
echo;
echo "Do you want to create a RAMDISK?"; echo;
echo "This will create a mount in /etc/fstab that attaches the processing"; 
echo "directory /var/spool/MailScanner/incoming to a RAMDISK, which greatly"; 
echo "increases processing speed at the cost of the reservation of some of";
echo "the system RAM. The size depends on the number of MailScanner children,";
echo "the number of messages per batch, and incoming email volume."
echo;
echo "Specify a size in MB or leave blank for none.";
echo;
echo "Suggestions:";
echo "		None		0";
echo "		Small		256";
echo "		Medium		512";
echo " 		Large 		1024 or 2048";
echo " 		Enterprise	4096 or 8192";
echo;
echo "Example: 1024"; echo;
read -r -p "Specify a RAMDISK size? [0] : " RAMDISKSIZE

if [[ $RAMDISKSIZE =~ ^[0-9]+$ ]]; then
	if [ $RAMDISKSIZE != 0 ]; then
		# user wants ramdisk
		RAMDISK=1
	else
		RAMDISK=0
	fi
else
	# no ramdisk
	RAMDISK=0
fi

# base system packages
BASEPACKAGES=();					
BASEPACKAGES+=('perl-doc');			BASEPACKAGES+=('libmailtools-perl');			BASEPACKAGES+=('re2c');
BASEPACKAGES+=('curl');				BASEPACKAGES+=('libnet-cidr-lite-perl');		BASEPACKAGES+=('libmime-tools-perl');
BASEPACKAGES+=('wget');				BASEPACKAGES+=('libtest-manifest-perl');		BASEPACKAGES+=('libnet-cidr-perl');
BASEPACKAGES+=('tar');				BASEPACKAGES+=('libdata-dump-perl');			BASEPACKAGES+=('libsys-syslog-perl');
BASEPACKAGES+=('binutils');			BASEPACKAGES+=('libbusiness-isbn-perl');		BASEPACKAGES+=('libio-stringy-perl');
BASEPACKAGES+=('unrar');			BASEPACKAGES+=('libdbd-mysql-perl');			BASEPACKAGES+=('perl-modules');
BASEPACKAGES+=('gcc');				BASEPACKAGES+=('libconvert-tnef-perl');			BASEPACKAGES+=('libdbd-mysql-perl');
BASEPACKAGES+=('make');				BASEPACKAGES+=('libdbd-sqlite3-perl');			BASEPACKAGES+=('libencode-detect-perl');
BASEPACKAGES+=('patch');			BASEPACKAGES+=('libfilesys-df-perl');			BASEPACKAGES+=('libc6-dev');
BASEPACKAGES+=('antiword');			BASEPACKAGES+=('libarchive-zip-perl');			BASEPACKAGES+=('libconfig-yaml-perl');
BASEPACKAGES+=('pyzor');			BASEPACKAGES+=('libole-storage-lite-perl');		BASEPACKAGES+=('libsys-sigaction-perl');
BASEPACKAGES+=('razor');			BASEPACKAGES+=('libinline-perl');				BASEPACKAGES+=('libmail-imapclient-perl');
BASEPACKAGES+=('tnef');				BASEPACKAGES+=('libmail-spf-perl');				BASEPACKAGES+=('libtest-pod-coverage-perl');
BASEPACKAGES+=('gzip');				BASEPACKAGES+=('libnetaddr-ip-perl');			BASEPACKAGES+=('libfile-sharedir-install-perl');
BASEPACKAGES+=('unzip');			BASEPACKAGES+=('libnet-ldap-perl');				BASEPACKAGES+=('libsys-hostname-long-perl');
BASEPACKAGES+=('openssl');			BASEPACKAGES+=('libmail-dkim-perl');			BASEPACKAGES+=('libhtml-tokeparser-simple-perl');
BASEPACKAGES+=('perl');				BASEPACKAGES+=('libbusiness-isbn-data-perl');	BASEPACKAGES+=('libnet-dns-resolver-programmable-perl');

	
# install these from array above in case one of the 
# packages produce an error
#
#"curl wget tar binutils libc6-dev gcc make patch gzip unzip openssl perl perl-doc libdbd-mysql-perl libconvert-tnef-perl libdbd-sqlite3-perl libfilesys-df-perl libmailtools-perl libmime-tools-perl libnet-cidr-perl libsys-syslog-perl libio-stringy-perl perl-modules libdbd-mysql-perl libencode-detect-perl unrar antiword libarchive-zip-perl libconfig-yaml-perl libole-storage-lite-perl libsys-sigaction-perl pyzor razor tnef libinline-perl libmail-imapclient-perl libtest-pod-coverage-perl libfile-sharedir-install-perl libmail-spf-perl libnetaddr-ip-perl libsys-hostname-long-perl libhtml-tokeparser-simple-perl libmail-dkim-perl libnet-ldap-perl libnet-dns-resolver-programmable-perl libnet-cidr-lite-perl libtest-manifest-perl libdata-dump-perl libbusiness-isbn-data-perl libbusiness-isbn-perl";

# the array of perl modules needed
ARMOD=();
ARMOD+=('Archive::Tar'); 		ARMOD+=('Archive::Zip');		ARMOD+=('bignum');				
ARMOD+=('Carp');				ARMOD+=('Compress::Zlib');		ARMOD+=('Compress::Raw::Zlib');	
ARMOD+=('Convert::BinHex'); 	ARMOD+=('Convert::TNEF');		ARMOD+=('Data::Dumper');		
ARMOD+=('Date::Parse');			ARMOD+=('DBD::SQLite');			ARMOD+=('DBI');					
ARMOD+=('Digest::HMAC');		ARMOD+=('Digest::MD5');			ARMOD+=('Digest::SHA1'); 		
ARMOD+=('DirHandle');			ARMOD+=('ExtUtils::MakeMaker');	ARMOD+=('Fcntl');				
ARMOD+=('File::Basename');		ARMOD+=('File::Copy');			ARMOD+=('File::Path');			
ARMOD+=('File::Spec');			ARMOD+=('File::Temp');			ARMOD+=('FileHandle');			
ARMOD+=('Filesys::Df');			ARMOD+=('Getopt::Long');		ARMOD+=('Inline::C');			
ARMOD+=('IO');					ARMOD+=('IO::File');			ARMOD+=('IO::Pipe');			
ARMOD+=('IO::Stringy');			ARMOD+=('HTML::Entities');		ARMOD+=('HTML::Parser');		
ARMOD+=('HTML::Tagset');		ARMOD+=('HTML::TokeParser');	ARMOD+=('Mail::Field');			
ARMOD+=('Mail::Header');		ARMOD+=('Mail::IMAPClient');	ARMOD+=('Mail::Internet');		
ARMOD+=('Math::BigInt');		ARMOD+=('Math::BigRat');		ARMOD+=('MIME::Base64');		
ARMOD+=('MIME::Decoder');		ARMOD+=('MIME::Decoder::UU');	ARMOD+=('MIME::Head');			
ARMOD+=('MIME::Parser');		ARMOD+=('MIME::QuotedPrint');	ARMOD+=('MIME::Tools');			
ARMOD+=('MIME::WordDecoder');	ARMOD+=('Net::CIDR');			ARMOD+=('Net::DNS');			
ARMOD+=('Net::IP');				ARMOD+=('OLE::Storage_Lite');	ARMOD+=('Pod::Escapes');		
ARMOD+=('Pod::Simple');			ARMOD+=('POSIX');				ARMOD+=('Scalar::Util');		
ARMOD+=('Socket'); 				ARMOD+=('Storable'); 	 	 	ARMOD+=('Test::Harness');		
ARMOD+=('Test::Pod');			ARMOD+=('Test::Simple');		ARMOD+=('Time::HiRes');			
ARMOD+=('Time::localtime'); 	ARMOD+=('Sys::Hostname::Long');	ARMOD+=('Sys::SigAction');		
ARMOD+=('Sys::Syslog'); 		ARMOD+=('Env'); 				ARMOD+=('File::ShareDir::Install');
ARMOD+=('Mail::SpamAssassin');

# not required but nice to have
ARMOD+=('bignum');				ARMOD+=('Business::ISBN');		ARMOD+=('Business::ISBN::Data');
ARMOD+=('Data::Dump');			ARMOD+=('DB_File');				ARMOD+=('DBD::SQLite');
ARMOD+=('DBI');					ARMOD+=('Digest');				ARMOD+=('Encode::Detect');
ARMOD+=('Error');				ARMOD+=('ExtUtils::CBuilder');	ARMOD+=('ExtUtils::ParseXS');
ARMOD+=('Getopt::Long');		ARMOD+=('Inline');				ARMOD+=('IO::String');	
ARMOD+=('IO::Zlib');			ARMOD+=('IP::Country');			ARMOD+=('Mail::SPF');
ARMOD+=('Mail::SPF::Query');	ARMOD+=('Module::Build');		ARMOD+=('Net::CIDR::Lite');
ARMOD+=('Net::DNS');			ARMOD+=('Net::LDAP');			ARMOD+=('Net::DNS::Resolver::Programmable');
ARMOD+=('NetAddr::IP');			ARMOD+=('Parse::RecDescent');	ARMOD+=('Test::Harness');
ARMOD+=('Test::Manifest');		ARMOD+=('Text::Balanced');		ARMOD+=('URI');	
ARMOD+=('version');				ARMOD+=('IO::Compress::Bzip2');

# additional spamassassin plugins				
ARMOD+=('Mail::SpamAssassin::Plugin::Rule2XSBody');		
ARMOD+=('Mail::SpamAssassin::Plugin::DCC');				
ARMOD+=('Mail::SpamAssassin::Plugin::Pyzor');


# logging starts here
(
clear
echo;
echo "Installation results are being logged to mailscanner-install.log";
echo;
timewait 1

# install the basics
echo "Installing required system packages ..."; echo;
timewait 2

# install required perl and base packages that are available via apt
#
# some items may not be available depending on the distribution 
# release but those items will be checked after this and installed
# via cpan if the user elected to do so.
$APTGET update

for i in "${BASEPACKAGES[@]}"
do
	$APTGET -yf install $i	
done

# install this separate in case it conflicts
if [ "x$MTAOPTION" != "x" ]; then
	$APTGET -yf install $MTAOPTION
fi

# fix the stupid line in /etc/freshclam.conf that disables freshclam 
if [ $CAV == 1 ]; then
	clear
	echo;
	echo "Installing Clam AV via apt ... "; echo;
	timewait 3
	$APTGET -y install $CAVOPTION
	COUT='#Example';
	if [ -f "/etc/freshclam.conf" ]; then
		perl -pi -e 's/Example/'$COUT'/;' /etc/freshclam.conf
	fi
fi

# check for curl
if [ ! -x /usr/bin/curl ]; then
	clear
	echo;
	echo "The curl command cannot be found. I have already attempted to install this";
	echo "package, but it is still not found. Please ensure that you have network access";
	echo "to the internet and try running the installation again.";
	echo;
	exit 1
else
	CURL='/usr/bin/curl';
fi

# create the cpan config if there isn't one and the user
# elected to use CPAN
if [ $CPANOPTION == 1 ]; then
	# user elected to use CPAN option
	if [ ! -f '/root/.cpan/CPAN/MyConfig.pm' ]; then
		echo;
		echo "CPAN config missing. Creating one ..."; echo;
		mkdir -p /root/.cpan/CPAN
		cd /root/.cpan/CPAN
		$CURL -O https://s3.amazonaws.com/msv5/CPAN/MyConfig.pm
		cd $THISCURRPMDIR
		timewait 1
		perl -MCPAN -e 'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit'
	fi
fi

# now check for missing perl modules and install them via cpan
# if the user elected to do so
clear; echo;
echo "Checking Perl Modules ... "; echo;
timewait 2
# used to trigger a wait if something this missing
PMODWAIT=0

# remediate
if [ $CPANOPTION == 1 ]; then
for i in "${ARMOD[@]}"
do
	perldoc -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then
		clear
		echo "$i is missing. Installing via CPAN ..."; echo;
		timewait 1
		perl -MCPAN -e "CPAN::Shell->force(qw(install $i ));"
	fi
done
fi

# check and notify of any missing modules
for i in "${ARMOD[@]}"
do
	perldoc -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then

		echo "WARNING: $i is missing.";
		PMODWAIT=5

	else
		echo "$i => OK";
	fi
done

# will pause if a perl module was missing
timewait $PMODWAIT

# save the old MailScanner.conf
if [ -f '/etc/MailScanner/MailScanner.conf' ]; then
	cp /etc/MailScanner/MailScanner.conf /etc/MailScanner/MailScanner.conf.$$
fi

# remove old versions
if [ -d /etc/MailScanner ]; then
	dpkg-query -l mailscanner > /dev/null 2>&1

	RETVAL="$?"

	if [ $RETVAL -eq 0 ]; then
		apt-get -y remove mailscanner
	fi
fi

clear
echo;
echo "Installing the MailScanner .deb package ... ";

# install the mailscanner package
dpkg -i $CONFFILES $NODEPS $THISCURRPMDIR/MailScanner-*-noarch.deb

if [ $? != 0 ]; then
	echo;
	echo '----------------------------------------------------------';
	echo 'Installation Error'; echo;
	echo 'The MailScanner package failed to install. Address the required';
	echo 'dependencies and run the installer again.';
	echo;
	echo 'Note that Perl modules need to be available system-wide. A';
	echo 'common issue is that missing modules were installed in a ';
	echo 'user specific configuration.';
	echo;
else
	SAVEDIR="$HOME/ms_upgrade/saved.$$";
	mkdir -p ${SAVEDIR}/etc/MailScanner
	
	if [ $AUTOUPGRADE == 1 ]; then
		echo "Upgrading /etc/MailScanner/MailScanner.conf";
		echo;
		echo "Your old configuration file will be saved as:";
		echo "/etc/MailScanner/MailScanner.conf.old.$$";
		echo;
		timewait 1
		
		if [ -f '/etc/MailScanner/MailScanner.conf' ]; then
			ms-upgrade-conf /etc/MailScanner/MailScanner.conf.$$ /etc/MailScanner/MailScanner.conf > /etc/MailScanner/MailScanner.new
			mv -f /etc/MailScanner/MailScanner.conf /etc/MailScanner/MailScanner.conf.old.$$
			mv -f /etc/MailScanner/MailScanner.new  /etc/MailScanner/MailScanner.conf
		fi

	fi
	
	mv -f /etc/MailScanner/MailScanner.conf.* ${SAVEDIR}/etc/MailScanner > /dev/null 2>&1
	
	# create ramdisk
	if [ $RAMDISK == 1 ]; then
		if [ -d '/var/spool/MailScanner/incoming' ]; then
			echo "Creating the ramdisk ...";
			echo;
			DISK="/var/spool/MailScanner/incoming";
			FSTYPE=$(df -P -T ${DISK}|tail -n +2 | awk '{print $2}')

			if [ $FSTYPE != tmpfs ]; then
				mount -t tmpfs -o size=${RAMDISKSIZE}M tmpfs ${DISK}
				echo "tmpfs ${DISK} tmpfs rw,size=${RAMDISKSIZE}M 0 0" >> /etc/fstab
				echo "Enabling ramdisk sync ...";
				if [ -f '/etc/MailScanner/defaults' ]; then
					OLD="^#ramdisk_sync=1";
					NEW="ramdisk_sync=1";
					sed -i "s/${OLD}/${NEW}/g" /etc/MailScanner/defaults
				fi
			else
				echo "${DISK} is already a RAMDISK!"; echo;
			fi
		fi
	fi
		
	/usr/sbin/ms-update-safe-sites
	/usr/sbin/ms-update-bad-sites
	
	if [ -d '/etc/clamav' ]; then
		/usr/bin/freshclam 
	fi
	
	echo;
	echo '----------------------------------------------------------';
	echo 'Installation Complete'; echo;
	echo 'See http://www.mailscanner.info for more information and  '
	echo 'support via the MailScanner mailing list.'
	echo;
	echo 'NOTE! If this was an upgrade, edit /etc/MailScanner/defaults'
	echo;
	echo 'New Install: Set your preferences in /etc/MailScanner/MailScanner.conf'
	echo 'and then edit /etc/MailScanner/defaults to enable';
	echo;
fi 

) 2>&1 | tee mailscanner-install.log