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
# 29 APR 2016
# Updated By:
# Manuel Dalla Lana < endelwar@aregar.it >
# Shawn Iverson < shawniverson@gmail.com >
# 24 SEP 2017

# clear the screen. yay!
clear

# unattended install: command line parameter parsing
parsedCommands=0;
while [ $# -gt 0 ]; do
    case "$1" in
        --update)
            # Select defaults and move forward
            arg_MTA="none";
            arg_installClamav=0;
            arg_installCPAN=1;
            arg_ignoreDeps=0;
            arg_ramdiskSize=0
            ((parsedCommands++));
        ;;

        --MTA=*)
            case ${1#*=} in
            "sendmail")  arg_MTA="sendmail"; ((parsedCommands++));;
            "postfix")   arg_MTA="postfix"; ((parsedCommands++));;
            "exim")      arg_MTA="exim4-base"; ((parsedCommands++));;
            "none")      arg_MTA=; ((parsedCommands++));;
            *)
                printf "Error: Invalid value for MTA: select one of 'sendmail', 'postfix', 'exim' or 'none'.\n"
                exit 1
            esac
        ;;

        --installClamav=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_installClamav=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_installClamav=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for installClamav: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --installCPAN=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_installCPAN=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_installCPAN=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for installCPAN: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --ignoreDeps=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_ignoreDeps=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_ignoreDeps=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for ignoreDeps: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --ramdiskSize=*)
            if [[ ${1#*=} =~ ^-?[0-9]+$ ]]; then
                arg_ramdiskSize="${1#*=}";
                ((parsedCommands++));
            else
                printf "Error: Invalid value for ramdiskSize: only integer values are accepted.\n"
                exit 1
            fi
        ;;

        --help)
            printf "MailScanner Installation for Debian Based Systems\n\n"
            printf "Usage: %s [--update] [--MTA=sendmail|postfix|exim|none] [--installClamav=Y|N] [--installCPAN=Y|N] [--ignoreDeps=Y|N] [--ramdiskSize=value]\n\n" "$0"
            printf -- "--update              Perform an update on an existing install using the following options (can be overridden):"
            printf -- "                        --MTA=none (assumed already installed)"
            printf -- "                        --installClamav=N (assumed already installed)"
            printf -- "                        --installCPAN=Y"
            printf -- "                        --ignoreDeps=N"
            printf -- "                        --ramdiskSize=0 (assumed already configured)"
            printf -- "--MTA=value           Select the Mail Transfer Agent (MTA) to be installed            (sendmail|postfix|exim|none)\n"
            printf    "                      Recommended: sendmail\n\n"
            printf -- "--installClamav=Y|N   Install or update Clam AV during installation                   (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--installCPAN=Y|N     Install missing perl modules via CPAN                           (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--ignoreDeps=Y|N      Force .deb package install regardless of missing dependencies   (Y or N)\n"
            printf    "                      Recommended: N (no)\n\n"
            printf -- "--ramdiskSize=value   Create a RAMDISK for incoming spool directory                   (integer value or 0 for none)\n"
            printf    "                      Suggestions:\n";
            printf    "                      None         0\n";
            printf    "                      Small        256\n";
            printf    "                      Medium       512\n";
            printf    "                      Large        1024 or 2048\n";
            printf    "                      Enterprise   4096 or 8192\n";
            exit 0
        ;;

        *)
            printf "Error: Invalid argument \"%s\".\n\n" "$1"
            printf "See help with %s --help\n" "$0"
            exit 1
    esac
    shift
done

# where i started for DEB install
THISCURRPMDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Function used to Wait for n seconds
timewait () {
    DELAY=$1
    sleep ${DELAY}
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
echo "WARNING - Make a backup of any custom configuration files if upgrading - WARNING";
echo;
echo "You may press CTRL + C at any time to abort the installation. Note that you may see";
echo "some errors during the perl module installation. You may safely ignore errors regarding";
echo "failed tests for optional packages."; echo;
if [ "$parsedCommands" -eq 0 ]; then
    echo "When you are ready to continue, press return ... ";
    read foobar
fi

# install or upgrade
if [ -f '/etc/MailScanner/MailScanner.conf' ]; then
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
if [ -z "${arg_MTA+x}" ]; then
    read -r -p "Install an MTA? [1] : " response
    if [[ $response =~ ^([nN][oO])$ ]]; then
        # do not install
        MTAOPTION=
    elif [ -z $response ]; then
        # sendmail default
        MTAOPTION="sendmail sendmail-bin";
    elif [ $response == 1 ]; then
        # sendmail
        MTAOPTION="sendmail sendmail-bin";
    elif [ $response == 2 ]; then
        # sendmail
        MTAOPTION="postfix";
    elif [ $response == 3 ]; then
        # sendmail
        MTAOPTION="exim4-base";
    else
        MTAOPTION=
    fi    
else
    MTAOPTION=${arg_MTA};
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
if [ -z "${arg_installClamav+x}" ]; then
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
else
    CAV=${arg_installClamav}
    CAVOPTION=
    if [ ${CAV} -eq 1 ]; then
        CAVOPTION="clamav-daemon libclamav-client-perl";
    fi
fi

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I will attempt to install Perl modules via apt, but some may not be unavailable during the";
echo "installation process. Missing modules will likely cause MailScanner to malfunction.";
echo;
echo "Recommended: Y (yes)"; echo;
if [ -z "${arg_installCPAN+x}" ]; then
    read -r -p "Install missing Perl modules via CPAN? [n/Y] : " response

    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # user wants to use CPAN for missing modules
        CPANOPTION=1

        # ignore dependency issue since the user elected to
        # use CPAN to remediate the modules
        NODEPS='--force-depends';
    elif [ -z $response ]; then
        # user wants to use CPAN for missing modules
        CPANOPTION=1

        # ignore dependency issue since the user elected to
        # use CPAN to remediate the modules
        NODEPS='--force-depends';
    else
        # user does not want to use CPAN
        CPANOPTION=0
    fi
else
    CPANOPTION=${arg_installCPAN}
    if [ $CPANOPTION -eq 1 ]; then
        NODEPS='--force-depends';
    fi
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
if [ -z "${arg_ignoreDeps+x}" ]; then
    read -r -p "Ignore MailScanner dependencies (nodeps)? [y/N] : " response

    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # user wants to ignore deps
        NODEPS='--force-depends'
    else
        # requiring deps
        NODEPS=
    fi
else
    if [ ${arg_ignoreDeps} -eq 1 ]; then
        NODEPS='--force-depends'
    else
        NODEPS=
    fi
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
if [ -z "${arg_ramdiskSize+x}" ]; then
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
else
    if [ ${arg_ramdiskSize} -eq 0 ]; then
        # no ramdisk
        RAMDISK=0;
    else
        RAMDISK=1;
        RAMDISKSIZE=${arg_ramdiskSize};
    fi
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
BASEPACKAGES+=('p7zip-full');       BASEPACKAGES+=('libgeo-ip-perl');               BASEPACKAGES+=('libnet-patricia-perl');

if [ "$parsedCommands" -gt 0 ]; then
    BASEPACKAGES+=('cpanminus');
fi

# install these from array above in case one of the 
# packages produce an error
#
#"curl wget tar binutils libc6-dev gcc make patch gzip unzip openssl perl perl-doc libdbd-mysql-perl libconvert-tnef-perl libdbd-sqlite3-perl libfilesys-df-perl libmailtools-perl libmime-tools-perl libnet-cidr-perl libsys-syslog-perl libio-stringy-perl perl-modules libdbd-mysql-perl libencode-detect-perl unrar antiword libarchive-zip-perl libconfig-yaml-perl libole-storage-lite-perl libsys-sigaction-perl pyzor razor tnef libinline-perl libmail-imapclient-perl libtest-pod-coverage-perl libfile-sharedir-install-perl libmail-spf-perl libnetaddr-ip-perl libsys-hostname-long-perl libhtml-tokeparser-simple-perl libmail-dkim-perl libnet-ldap-perl libnet-dns-resolver-programmable-perl libnet-cidr-lite-perl libtest-manifest-perl libdata-dump-perl libbusiness-isbn-data-perl libbusiness-isbn-perl";

# the array of perl modules needed
ARMOD=();
ARMOD+=('Archive::Tar');		ARMOD+=('Archive::Zip');		ARMOD+=('bignum');
ARMOD+=('Carp');				ARMOD+=('Compress::Zlib');		ARMOD+=('Compress::Raw::Zlib');
ARMOD+=('Convert::BinHex');		ARMOD+=('Convert::TNEF');		ARMOD+=('Data::Dumper');
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
ARMOD+=('Socket');				ARMOD+=('Storable');			ARMOD+=('Test::Harness');
ARMOD+=('Test::Pod');			ARMOD+=('Test::Simple');		ARMOD+=('Time::HiRes');
ARMOD+=('Time::localtime');		ARMOD+=('Sys::Hostname::Long');	ARMOD+=('Sys::SigAction');
ARMOD+=('Sys::Syslog');			ARMOD+=('Env');

MODSA='Mail::SpamAssassin';

# not required but nice to have
ARMODAFTERSA=();
ARMODAFTERSA+=('bignum');
ARMODAFTERSA+=('Data::Dump');		ARMODAFTERSA+=('DB_File');				ARMODAFTERSA+=('DBD::SQLite');
ARMODAFTERSA+=('DBI');				ARMODAFTERSA+=('Digest');				ARMODAFTERSA+=('Encode::Detect');
ARMODAFTERSA+=('Error');			ARMODAFTERSA+=('ExtUtils::CBuilder');	ARMODAFTERSA+=('ExtUtils::ParseXS');
ARMODAFTERSA+=('Getopt::Long');		ARMODAFTERSA+=('Inline');				ARMODAFTERSA+=('IO::String');
ARMODAFTERSA+=('IO::Zlib');			ARMODAFTERSA+=('IP::Country');			ARMODAFTERSA+=('Mail::SPF');
ARMODAFTERSA+=('Mail::SPF::Query');	ARMODAFTERSA+=('Module::Build');		ARMODAFTERSA+=('Net::CIDR::Lite');
ARMODAFTERSA+=('Net::DNS');			ARMODAFTERSA+=('Net::LDAP');			ARMODAFTERSA+=('Net::DNS::Resolver::Programmable');
ARMODAFTERSA+=('NetAddr::IP');		ARMODAFTERSA+=('Parse::RecDescent');	ARMODAFTERSA+=('Test::Harness');
ARMODAFTERSA+=('Test::Manifest');	ARMODAFTERSA+=('Text::Balanced');		ARMODAFTERSA+=('URI');
ARMODAFTERSA+=('version');			ARMODAFTERSA+=('IO::Compress::Bzip2');

# additional spamassassin plugins
ARMODAFTERSA+=('Mail::SpamAssassin::Plugin::Rule2XSBody');
ARMODAFTERSA+=('Mail::SpamAssassin::Plugin::DCC');
ARMODAFTERSA+=('Mail::SpamAssassin::Plugin::Pyzor');


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
    if [ $? != 0 ]; then
        echo "Error installing $MTAOPTION MTA"
        echo "This usually means an MTA is already installed."
    fi
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

# CPAN automation invoked?
if [ -z "${arg_installCPAN+x}" ]; then
    AUTOCPAN=0
else
    if [ $CPANOPTION -eq 1 ]; then
        AUTOCPAN=1
        # Install cpanminus
        $APTGET  -y install cpanminus
        if [ $? -ne 0 ]; then
            echo "Error installing cpanminus, falling back to perl invocation method."
            AUTOCPAN=0
        fi
    else
        AUTOCPAN=0
    fi
fi

# remediate
if [ ${CPANOPTION} == 1 ]; then
    #Install pre SpamAssassin modules
    for i in "${ARMOD[@]}"
    do
        perldoc -l ${i} >/dev/null 2>&1
        if [ $? != 0 ]; then
            clear
            echo "${i} is missing. Installing via CPAN ..."; echo;
            timewait 1
            if [ $AUTOCPAN -eq 0 ]; then
                perl -MCPAN -e "CPAN::Shell->force(qw(install ${i} ));"
            else
                cpanm --force --no-interactive $i
            fi
        fi
    done

    #Install SpamaAssassin, use standard cpan in normail install, or App::cpanminus in unattended install
    perldoc -l ${MODSA} >/dev/null 2>&1
    if [ $? != 0 ]; then
        clear
        echo "${MODSA} is missing. Installing via CPAN ..."; echo;
        timewait 1
        if [ $AUTOCPAN -eq 0 ]; then
            perl -MCPAN -e "CPAN::Shell->force(qw(install ${MODSA} ));"
        else
            cpanm --no-interactive --force ${MODSA}
        fi
    fi

    #Install post SpamAssassin modules
    for i in "${ARMODAFTERSA[@]}"
    do
        perldoc -l ${i} >/dev/null 2>&1
        if [ $? != 0 ]; then
            clear
            echo "${i} is missing. Installing via CPAN ..."; echo;
            timewait 1
            perl -MCPAN -e "CPAN::Shell->force(qw(install ${i} ));"
        fi
    done

fi

# check and notify of any missing modules
ARMODALL=("${ARMOD[@]}" "${MODSA}" "${ARMODAFTERSA[@]}")
for i in "${ARMODALL[@]}"
do
    perldoc -l ${i} >/dev/null 2>&1
    if [ $? != 0 ]; then

        echo "WARNING: $i is missing.";
        PMODWAIT=5

    else
        echo "${i} => OK";
    fi
done

# will pause if a perl module was missing
timewait ${PMODWAIT}

clear
echo;
echo "Installing the MailScanner .deb package ... ";

# install the mailscanner package
dpkg -i ${CONFFILES} ${NODEPS} "${THISCURRPMDIR}"/MailScanner-*-noarch.deb

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
                    OLD="^ramdisk_sync=0";
                    NEW="ramdisk_sync=1";
                    sed -i "s/${OLD}/${NEW}/g" /etc/MailScanner/defaults
                fi
            else
                echo "${DISK} is already a RAMDISK!"; echo;
            fi
        fi
    fi
        
    /usr/sbin/ms-update-phishing >/dev/null 2>&1
    
    if [ -d '/etc/clamav' ]; then
        #Test if freshclam is already running
        if [[ -z $(ps aux | grep "[f]reshclam") ]]; then
            /usr/bin/freshclam 2>/dev/null
        fi
    fi
    
    echo;
    echo '----------------------------------------------------------';
    echo 'Installation Complete'; echo;
    echo 'See http://www.mailscanner.info for more information and  '
    echo 'support via the MailScanner mailing list.'
    echo;
    echo;
    echo 'Review: Set your preferences in /etc/MailScanner/MailScanner.conf'
    echo 'and review /etc/MailScanner/defaults';
    echo;
fi 

) 2>&1 | tee mailscanner-install.log
