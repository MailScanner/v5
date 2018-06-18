#!/usr/bin/env bash
#
# MailScanner installation script for SUSE based systems
#
# This script installs the required software for
# MailScanner via zypper and CPAN based on user input.  
#
# Tested distributions:     OpenSUSE 13.2-42.3
#
# Written by:
# Jerry Benton < mailscanner@mailborder.com >
# 3 MAY 2016
# Updated by:
# Manuel Dalla Lana < endelwar@aregar.it >
# Shawn Iverson < shawniverson@efa-project.org >
# 17 JUN 2018

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
            printf "MailScanner Installation for SuSE Based Systems\n\n"
            printf "Usage: %s [--update] [--MTA=sendmail|postfix|exim|none] [--installClamav=Y|N] [--installCPAN=Y|N] [--ignoreDeps=Y|N] [--ramdiskSize=value]\n\n" "$0"
            printf -- "--update              Perform an update on an existing install using the following options (can be overridden):\n"
            printf    "                        --MTA=none        (assumed already installed)\n"
            printf    "                        --installClamav=N (assumed already installed)\n"
            printf    "                        --installCPAN=Y\n"
            printf    "                        --ignoreDeps=N\n"
            printf    "                        --ramdiskSize=0   (assumed already configured)\n\n"
            printf -- "--MTA=value           Select the Mail Transfer Agent (MTA) to be installed            (sendmail|postfix|exim|none)\n"
            printf    "                      Recommended: sendmail\n\n"
            printf -- "--installClamav=Y|N   Install or update Clam AV during installation                   (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--installCPAN=Y|N     Install missing perl modules via CPAN                           (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--ignoreDeps=Y|N      Force .rpm package install regardless of missing dependencies   (Y or N)\n"
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

# bail if zypper is not installed
if [ ! -x '/usr/bin/zypper' ]; then
    clear
    echo;
    echo "Zypper package manager is not installed. You must install this before starting";
    echo "the MailScanner installation process. Installation aborted."; echo;
    exit 192
else
    ZYPPER='/usr/bin/zypper';
fi

# confirm the RHEL release is known before continuing
if [ -f '/etc/redhat-release' ]; then
    # this is mostly to prevent accidental installation on a non redhat based system
    echo "This appears to be a Red Hat based system. This installer is for SuSE. Installation aborted."; echo;
    exit 192
fi

# user info screen before the install process starts
echo "MailScanner Installation for SUSE Based Systems"; echo; echo;
echo "This will INSTALL or UPGRADE the required software for MailScanner on SuSE based systems";
echo "via the zypper package manager. Tested distributions are openSUSE 13.2 and associated";
echo "variants. Internet connectivity is required for this installation script to execute."; 
echo;
echo "WARNING - Make a backup of any custom configuration files if upgrading - WARNING";
echo;
echo "You may press CTRL + C at any time to abort the installation. Note that you may see";
echo "some errors during the perl module installation. You may safely ignore errors regarding";
echo "failed tests if you opt to use CPAN. You may also ignore 'No package available' notices";
echo "during the zypper installation of packages."; echo;
if [ "$parsedCommands" -eq 0 ]; then
    echo "When you are ready to continue, press return ... ";
    read foobar
fi

# ask if the user wants an mta installed
clear
echo;
echo "Do you want to install a Mail Transfer Agent (MTA)?"; echo;
echo "I can install an MTA via the zypper package manager to save you the trouble of having to do";
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
        MTAOPTION="sendmail";
    elif [ $response == 1 ]; then    
        # sendmail 
        MTAOPTION="sendmail";    
    elif [ $response == 2 ]; then    
        # sendmail 
        MTAOPTION="postfix";
    elif [ $response == 3 ]; then    
        # sendmail 
        MTAOPTION="exim";        
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
        CAVOPTION="pcre-devel clamav clamav-database clamav-nodb clamz";
    elif [ -z $response ]; then  
        CAV=1
        CAVOPTION="pcre-devel clamav clamav-database clamav-nodb clamz";
    else
        # user does not want clam av
        CAV=0
        CAVOPTION=
    fi
else
    CAV=${arg_installClamav}
    CAVOPTION=
    if [ ${CAV} -eq 1 ]; then
        CAVOPTION="pcre-devel clamav clamav-database clamav-nodb clamz";
    fi
fi

# no longer asking - just get spamassassin installed
SA=1
SAOPTION="spamassassin"

# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I will attempt to install Perl modules via zypper, but some may not be unavailable during the";
echo "installation process. Missing modules will likely cause MailScanner to malfunction.";
echo;
echo "Recommended: Y (yes)"; echo;
if [ -z "${arg_installCPAN+x}" ]; then
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
else
    CPANOPTION=${arg_installCPAN}
    if [ $CPANOPTION -eq 1 ]; then
        NODEPS='--nodeps';
    fi
fi

# ask if the user wants to install the Mail::ClamAV module
if [ $CPANOPTION = 1 ]; then
    # Mail::ClamAV
    CAV=1

    # Mail::SpamAssassin
    SA=1

else
    # don't install if not using CPAN
    CAV=0
    SA=0
fi

# ask if the user wants to ignore dependencies. they are automatically ignored
# if the user elected the CPAN option as explained above
if [ $CPANOPTION != 1 ]; then
    clear
    echo;
    echo "Do you want to ignore MailScanner dependencies?"; echo;
    echo "This will force install the MailScanner RPM package regardless of missing"; 
    echo "dependencies. It is highly recommended that you DO NOT do this unless you"; 
    echo "are debugging.";
    echo;
    echo "Recommended: N (no)"; echo;
    if [ -z "${arg_ignoreDeps+x}" ]; then
        read -r -p "Ignore MailScanner dependencies (nodeps)? [y/N] : " response

        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # user wants to ignore deps
            NODEPS='--nodeps'
        else
            # requiring deps
            NODEPS=
        fi
    else
        if [ ${arg_ignoreDeps} -eq 1 ]; then
            NODEPS='--nodeps'
        else
            NODEPS=
        fi
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
BASEPACKAGES="binutils gcc glibc-devel libaio1 make man-pages patch rpm tar time unzip which zip libtool perl curl wget openssl libopenssl-devel bzip2 tnef unrar razor-agents libbz2-devel";

# Packages available in the suse base 13.2. If the user elects not to use EPEL or if the 
# package is not available for their distro release it will be ignored during the install.
#
MOREPACKAGES="perl-Archive-Zip perl-Convert-BinHex perl-Convert-TNEF perl-DBD-SQLite perl-DBI perl-MIME-tools perl-Digest-HMAC perl-Digest-SHA1 perl-ExtUtils-MakeMaker perl-File-ShareDir-Install perl-File-Temp perl-Filesys-Df perl-Getopt-Long-Descriptive perl-IO-stringy perl-HTML-Parser perl-HTML-Tagset perl-Inline perl-Mail-DKIM perl-Mail-SPF perl-MailTools perl-Net-CIDR-Set perl-Net-DNS perl-Net-IP perl-OLE-Storage_Lite perl-Scalar-List-Utils perl-razor-agents perl-Sys-Hostname-Long perl-Sys-SigAction perl-Test-Pod perl-TimeDate perl-URI re2c perl-Encode-Detect perl-LDAP perl-IO-Compress-Bzip2 p7zip";

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
ARMOD+=('version');				ARMOD+=('IO::Compress::Bzip2');

# additional spamassassin plugins				
ARMOD+=('Mail::SpamAssassin::Plugin::Rule2XSBody');		
ARMOD+=('Mail::SpamAssassin::Plugin::DCC');				
ARMOD+=('Mail::SpamAssassin::Plugin::Pyzor');

# add to array if the user is installing spamassassin
if [ $SA == 1 ]; then
    ARMOD+=('Mail::SpamAssassin');
fi

# add to array if the user is installing clam av
if [ $CAV == 1 ]; then
    ARMOD+=('Mail::ClamAV');
fi

# logging starts here
(
clear
echo;
echo "Installation results are being logged to mailscanner-install.log";
echo;
timewait 1

# install the basics
echo "Installing required base system utilities.";
echo;
timewait 2

# install base packages
$ZYPPER --non-interactive --ignore-unknown install $BASEPACKAGES

# install this separate in case it conflicts
if [ "x$MTAOPTION" != "x" ]; then
    $ZYPPER --non-interactive --ignore-unknown install $MTAOPTION
    if [ $? != 0 ]; then
        echo "Error installing $MTAOPTION MTA"
        echo "This usually means an MTA is already installed."
    fi
    if [ $MTAOPTION = "sendmail" ]; then
        mkdir -p /var/spool/mqueue
        mkdir -p /var/spool/mqueue.in
    fi
fi

# make sure rpm is available
if [ -x /bin/rpm ]; then
    RPM=/bin/rpm
elif [ -x /usr/bin/rpm ]; then
    RPM=/usr/bin/rpm
else
    clear
    echo;
    echo "The 'rpm' command cannot be found. I have already attempted to install this";
    echo "package, but it is still not found. Please ensure that you have network";
    echo "access to the internet and try running the installation again.";
    echo;
    exit 1
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
        cd "$THISCURRPMDIR"
        timewait 1
    fi
fi

# install required perl packages that are available via zypper along
#
# some items may not be available depending on the distribution 
# release but those items will be checked after this and installed
# via cpan if the user elected to do so.
clear
echo;
echo "Installing available Perl packages, Clam AV (if elected), and ";
echo "Spamassassin (if elected) via zypper. You can safely ignore any";
echo "subsequent warnings from zypper."; echo;
timewait 3

$ZYPPER --non-interactive --ignore-unknown install $MOREPACKAGES $CAVOPTION $SAOPTION

# now check for missing perl modules and install them via cpan
# if the user elected to do so
clear; echo;
echo "Checking Perl Modules ... "; echo;
timewait 2
# used to trigger a wait if something this missing
PMODWAIT=0

# first try to install missing perl modules via zypper
# using this trick
for i in "${ARMOD[@]}"
do
    perldoc -l $i >/dev/null 2>&1
    if [ $? != 0 ]; then
        echo "$i is missing. Trying to install via Zypper ..."; echo;
        THING="perl($i)";
        $ZYPPER --non-interactive --ignore-unknown install $THING
    fi
done

# CPAN automation invoked?
if [ -z "${arg_installCPAN+x}" ]; then
    AUTOCPAN=0
else
    if [ $CPANOPTION -eq 1 ]; then
        AUTOCPAN=1
        # Install cpanminus
        $ZYPPER  --non-interactive install cpanm
        if [ $? -ne 0 ]; then
            echo "Error installing cpanminus, falling back to perl invocation method."
            AUTOCPAN=0
        fi
    else
        AUTOCPAN=0
    fi
fi

for i in "${ARMOD[@]}"
do
    perldoc -l $i >/dev/null 2>&1
    if [ $? != 0 ]; then
        if [ $CPANOPTION == 1 ]; then
            clear
            echo "$i is missing. Installing via CPAN ..."; echo;
            timewait 1
            if [ $AUTOCPAN -eq 0 ]; then
                perl -MCPAN -e "CPAN::Shell->force(qw(install $i ));"
            else
                cpanm --force --no-interactive $i
            fi
        else
            echo "WARNING: $i is missing. You should fix this.";
            PMODWAIT=5
        fi
    else
        echo "$i => OK";
    fi
done

if [ $CPANOPTION -eq 1]; then
  # Install MIME::Tools from CPAN even though rpm is present
  # Fixes outdated MIME::Tools causing MailScanner to crash
  clear
  echo "Latest MIME::Tools is needed, Installing via CPAN ..."; echo;
  timewait 1
  perl -MCPAN -e "CPAN::Shell->force(qw(install MIME::Tools));"
else
  echo "WARNING: Outdated MIME::Tools may be present. You should fix this.";
  PMODWAIT=5
fi

# will pause if a perl module was missing
timewait $PMODWAIT

# go to where i started
cd "$THISCURRPMDIR"

# Freshclam
if [ $CAV == 1 ]; then
    COUT='#Example';
    perl -pi -e 's/Example/'$COUT'/;' /etc/freshclam.conf
    systemctl enable clamd.service
    freshclam 2>/dev/null
fi

clear
echo;
echo "Installing the MailScanner RPM ... ";

# using --force option to reinstall the rpm if the same version is
# already installed. this will not overwrite configuration files
# as they are protected in the rpm spec file
$RPM -Uvh $NODEPS MailScanner*noarch.rpm

if [ $? != 0 ]; then
    echo;
    echo '----------------------------------------------------------';
    echo 'Installation Error'; echo;
    echo 'The MailScanner RPM failed to install. Address the required';
    echo 'dependencies and run the installer again. Note that electing';
    echo 'to use CPAN should resolve dependency errors.';
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
    
    /usr/sbin/ms-update-phishing > /dev/null 2>&1
    
    # fix the clamav wrapper if the user does not exist
    if [ -f '/etc/freshclam.conf' ]; then
        if id -u vscan >/dev/null 2>&1; then
            #vscan is being used instead of clamav
            OLDCAVUSR='ClamUser="clamav"';
            NEWCAVUSR='ClamUser="vscan"'

            if [ -f '/usr/lib/MailScanner/wrapper/clamav-wrapper' ]; then
                perl -pi -e 's/'$OLDCAVUSR'/'$NEWCAVUSR'/;' /usr/lib/MailScanner/wrapper/clamav-wrapper
            fi

            mkdir -p /var/run/clamav
            chown vscan:vscan /var/run/clamav
        fi
    fi

    ldconfig

    echo;
    echo '----------------------------------------------------------';
    echo 'Installation Complete'; echo;
    echo 'See http://www.mailscanner.info for more information and  '
    echo 'support via the MailScanner mailing list.'
    echo;
    echo;
    echo 'Review: Set your preferences in /etc/MailScanner/MailScanner.conf'
    echo 'and review /etc/MailScanner/defaults';
fi 

) 2>&1 | tee mailscanner-install.log
