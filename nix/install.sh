#!/bin/bash
#
# MailScanner installation script for NIX* based systems
# 
#
# Updated: 2 Nov 2019
# MailScanner Team <https://www.mailscanner.info>

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

clear
echo;
echo "WRANING: backup your custom MailScanner files before proceeding. They will be overwritten!";
echo;
echo "These items should be installed before proceeding: perl, perldoc, curl, cpan";
echo;
echo "Press <return> to continue or CTRL+C to quit.";
echo;
read foobar

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I can attempt to install Perl modules via CPAN. Missing modules will likely ";
echo "cause MailScanner to malfunction.";
echo;
echo "WARNING: You must have perl, perldoc, curl, cpan installed for this to work!";
echo;
echo "Recommended: Y (yes)"; echo;
read -r -p "Install missing Perl modules via CPAN? [n/Y] : " response

if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # user wants to use CPAN for missing modules
	CPANOPTION=1
elif [ -z $response ]; then 
	 # user wants to use CPAN for missing modules
	CPANOPTION=1

else
    # user does not want to use CPAN
    CPANOPTION=0
fi


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
ARMOD+=('Sys::Syslog'); 		ARMOD+=('Env'); 				
ARMOD+=('Mail::SpamAssassin');

# not required but nice to have
ARMOD+=('bignum');				
ARMOD+=('Data::Dump');			ARMOD+=('DB_File');				ARMOD+=('DBD::SQLite');
ARMOD+=('DBI');					ARMOD+=('Digest');				ARMOD+=('Encode::Detect');
ARMOD+=('Error');				ARMOD+=('ExtUtils::CBuilder');	ARMOD+=('ExtUtils::ParseXS');
ARMOD+=('Getopt::Long');		ARMOD+=('Inline');				ARMOD+=('IO::String');	
ARMOD+=('IO::Zlib');			ARMOD+=('IP::Country');			ARMOD+=('Mail::SPF');
ARMOD+=('Mail::SPF::Query');	ARMOD+=('Module::Build');		ARMOD+=('Net::CIDR::Lite');
ARMOD+=('Net::DNS');			ARMOD+=('Net::LDAP');			ARMOD+=('Net::DNS::Resolver::Programmable');
ARMOD+=('NetAddr::IP');			ARMOD+=('Parse::RecDescent');	ARMOD+=('Test::Harness');
ARMOD+=('Test::Manifest');		ARMOD+=('Text::Balanced');		ARMOD+=('URI');
ARMOD+=('version');				ARMOD+=('IO::Compress::Bzip2'); ARMOD+=('Sendmail::PMilter');

# additional spamassassin plugins				
ARMOD+=('Mail::SpamAssassin::Plugin::Rule2XSBody');		
ARMOD+=('Mail::SpamAssassin::Plugin::DCC');				
ARMOD+=('Mail::SpamAssassin::Plugin::Pyzor');
ARMOD+=('Mail::SpamAssassin');
ARMOD+=('Mail::ClamAV');

# 32 or 64 bit
MACHINE_TYPE=`uname -m`

# logging starts here
(
clear
echo;
echo "Installation results are being logged to mailscanner-install.log";
echo;
timewait 1

CURL=`which curl`

# check for curl
if [ ! -x "$CURL" ]; then
	clear
	echo;
	echo "The curl command cannot be found. Please install this to continue";
	echo;
	exit 1
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
		"$CURL" -O https://s3.amazonaws.com/msv5/CPAN/MyConfig.pm
		cd "$THISCURRPMDIR"
		timewait 1
	fi
fi

# fix the stupid line in /etc/freshclam.conf that disables freshclam 
COUT='#Example';
if [ -f '/etc/freshclam.conf' ]; then
	perl -pi -e 's/Example/'$COUT'/;' /etc/freshclam.conf
fi


# now check for missing perl modules and install them via cpan
# if the user elected to do so
clear; echo;
echo "Checking Perl Modules ... "; echo;
timewait 2

for i in "${ARMOD[@]}"
do
	perldoc -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then
		if [ $CPANOPTION == 1 ]; then
			clear
			echo "$i is missing. Installing via CPAN ..."; echo;
			perl -MCPAN -e "CPAN::Shell->force(qw(install $i ));"
		else
			echo "WARNING: $i is missing. You should fix this.";
		fi
	else
		echo "$i => OK";
	fi
done

# make sure in starting directory
cd "$THISCURRPMDIR"

clear
echo;
echo "Installing the MailScanner files ... ";

if [ -f '/etc/MailScanner/MailScanner.conf' ]; then
	cp -f /etc/MailScanner/MailScanner.conf /etc/MailScanner/MailScanner.conf.original.$$
fi

if [ -f './etc/MailScanner/MailScanner.conf' ]; then
	cp -fr ./etc /
	cp -fr ./usr /
	cp -fr ./var /
	
	if [ -f '/etc/MailScanner/custom' ]; then
		rm -f /etc/MailScanner/custom
	fi
	
	if [ ! -L '/etc/MailScanner/custom' ]; then
		ln -s /usr/share/MailScanner/perl/custom /etc/MailScanner/custom
	fi
	
	if [ -f '/etc/MailScanner/reports' ]; then
		rm -f /etc/MailScanner/reports
	fi
	
	if [ ! -L '/etc/MailScanner/reports' ]; then
		ln -s /usr/share/MailScanner/reports /etc/MailScanner/reports
	fi
	
	echo;
	echo '----------------------------------------------------------';
	echo 'Installation Complete'; echo;
	echo 'See http://www.mailscanner.info for more information and  '
	echo 'support via the MailScanner mailing list.'
	echo;

else
	
	echo; 
	echo '----------------------------------------------------------';
	echo 'Installation Failed'; echo;
	echo 'I cannot find the MailScanner source files in my directory';
fi

) 2>&1 | tee mailscanner-install.log