#!/bin/bash
#
# MailScanner installation script for RPM based systems
# 
# This script installs the required software for
# MailScanner via yum and CPAN based on user input.  
#
# Tested distributions:     CentOS 5,6,7
#                           RHEL 6,7
#                           Fedora 26,27,28
#
# Written by:
# Jerry Benton < mailscanner@mailborder.com >
# 29 APR 2016
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
            # Set update mode and move forward
            arg_MTA="none";
            arg_installClamav=0;
            arg_configClamav=0;
            arg_installCPAN=1;
            arg_ignoreDeps=0;
            arg_ramdiskSize=0
            arg_installEPEL=0;
            arg_installTNEF=0;
            arg_installUnrar=0;
            arg_installDf=0;
            arg_SELPermissive=0;
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
        
        --configClamav=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_configClamav=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_configClamav=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for configClamav: only Y or N values are accepted.\n"
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

        --installEPEL=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_installEPEL=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_installEPEL=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for installEPEL: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --installTNEF=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_installTNEF=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_installTNEF=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for installTNEF: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --installUnrar=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_installUnrar=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_installUnrar=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for installUnrar: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --installDf=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_installDf=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_installDf=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for installDf: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --SELPermissive=*)
            if [[ ${1#*=} =~ ^([yY])$ ]]; then
                arg_SELPermissive=1;
                ((parsedCommands++));
            elif [[ ${1#*=} =~ ^([nN])$ ]]; then
                arg_SELPermissive=0;
                ((parsedCommands++));
            else
                printf "Error: Invalid value for SELPermissive: only Y or N values are accepted.\n"
                exit 1
            fi
        ;;

        --help)
            printf "MailScanner Installation for Red Hat Based Systems\n\n"
            printf "Usage: %s [--update] [--MTA=sendmail|postfix|exim|none] [--installEPEL=Y|N] [--installClamav=Y|N] [--configClamav=Y|N] [--installTNEF=Y|N] [--installUnrar=Y|N] [--installCPAN=Y|N] [--installDf=Y|N] [--ignoreDeps=Y|N] [--SELPermissive=Y|N] [--ramdiskSize=value]\n\n" "$0"
            printf -- "--update              Perform an update on an existing install using the following options (can be overridden):\n"
            printf    "                        --MTA=none        (assumed already installed)\n"
            printf    "                        --installEPEL=N   (assumed already installed)\n"
            printf    "                        --installClamav=N (assumed already installed)\n"
            printf    "                        --configClamav=N  (assumed already installed)\n"
            printf    "                        --installTNEF=N   (assumed already installed)\n"
            printf    "                        --installUnrar=N  (assumed already installed)\n"
            printf    "                        --installCPAN=Y\n"
            printf    "                        --installDf=N     (assumed already installed)\n"
            printf    "                        --SELPermissive=N (assumed already configured)\n"
            printf    "                        --ignoreDeps=N\n"
            printf    "                        --ramdiskSize=0   (assumed already configured)\n\n"
            printf -- "--MTA=value           Select the Mail Transfer Agent (MTA) to be installed            (sendmail|postfix|exim|none)\n"
            printf    "                      Recommended: sendmail\n\n"
            printf -- "--installEPEL=Y|N     Install and use EPEL repository                                 (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--installClamav=Y|N   Install or update Clam AV during installation (requires EPEL)   (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--configClamav=Y|N    Configure Clam AV (CentOS 7 only)                               (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--installTNEF=Y|N     Install tnef via RPM                                            (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--installUnrar=Y|N    Install unrar via RPM                                           (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--installCPAN=Y|N     Install missing perl modules via CPAN                           (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--installDf=Y|N       Install perl-Filesys-Df and perl-Sys-Hostname-Long (CentOS 7)   (Y or N)\n"
            printf    "                      Recommended: Y (yes)\n\n"
            printf -- "--SELPermissive=Y|N   Set SELinux to Permissive mode                                  (Y or N)\n"
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

# bail if yum is not installed
if [ ! -x '/usr/bin/yum' ]; then
    clear
    echo;
    echo "Yum package manager is not installed. You must install this before starting";
    echo "the MailScanner installation process. Installation aborted."; echo;
    exit 192
else
    YUM='/usr/bin/yum';
fi

# confirm the RHEL release is known before continuing
if [ ! -f '/etc/redhat-release' ]; then
    # this is mostly to prevent accidental installation on a non redhat based system
    echo "Unable to determine distribution release from /etc/redhat-release. Installation aborted."; echo;
    exit 192
else
    # figure out what release is being used
    if grep -qs 'release 5' /etc/redhat-release ; then
            # RHEL 5
            RHEL=5
    elif grep -qs 'release 6' /etc/redhat-release ; then
            # RHEL 6
            RHEL=6
    elif grep -qs 'release 7' /etc/redhat-release ; then
            # RHEL 7
            RHEL=7
    else
            # No supported release match
            RHEL=0
    fi
fi

FEDORA=
# Is this a Fedora System?
if [ -f /etc/fedora-release ]; then
    if grep -qs 'release 26' /etc/fedora-release ; then
        # Fedora 26
        FEDORA=26
    elif grep -qs 'release 27' /etc/fedora-release ; then
        # Fedora 27
        FEDORA=27
    elif grep -qs 'release 28' /etc/fedora-release ; then
        # Fedora 28
        FEDORA=28
    else
        # Unsupported release
        FEDORA=0
    fi
fi

# user info screen before the install process starts
echo "MailScanner Installation for RPM Based Systems"; echo; echo;
echo "This will INSTALL or UPGRADE the required software for MailScanner on RPM based systems";
echo "via the Yum package manager. Supported distributions are RHEL 5,6,7 and associated";
echo "variants such as CentOS and Scientific Linux. Internet connectivity is required for"; 
echo "this installation script to execute. "; echo;
echo;
echo "WARNING - Make a backup of any custom configuration files if upgrading - WARNING";
echo;
echo "You may press CTRL + C at any time to abort the installation. Note that you may see";
echo "some errors during the perl module installation. You may safely ignore errors regarding";
echo "failed tests if you opt to use CPAN. You may also ignore 'No package available' notices";
echo "during the yum installation of packages."; echo;
if [ "$parsedCommands" -eq 0 ]; then
    echo "When you are ready to continue, press return ... ";
    read foobar
fi

# ask if the user wants an mta installed
clear
echo;
echo "Do you want to install a Mail Transfer Agent (MTA)?"; echo;
echo "I can install an MTA via the Yum package manager to save you the trouble of having to do";
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

# no longer asking - just get spamassassin installed
SA=1
SAOPTION="spamassassin"

if [ -z $FEDORA ]; then
    # ask if the user wants to install EPEL
    clear
    echo;
    echo "Do you want to install EPEL? (Extra Packages for Enterprise Linux)"; echo;
    echo "Installing EPEL will make more yum packages available, such as extra perl modules"; 
    echo "and Clam AV, which is recommended. This will also reduce the number of Perl modules";
    echo "installed via CPAN. Note that EPEL is considered a third party repository."; 
    echo;
    echo "Recommended: Y (yes)"; echo;
    if [ -z "${arg_installEPEL+x}" ]; then
        read -r -p "Install EPEL? [n/Y] : " response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # user wants EPEL installed
            EPEL=1
            EPELOPTION="epel-release";
        elif [ -z $response ]; then    
            # user wants EPEL installed
            EPEL=1
            EPELOPTION="epel-release";
        else
            # user does not want EPEL
            EPEL=0
            EPELOPTION=
        fi
    else
        EPEL=${arg_installEPEL};
        if [ $EPEL -eq 1 ]; then
            EPELOPTION="epel-release";
        fi
    fi
fi

# ask if the user wants Clam AV installed if they selected EPEL or if this is a Fedora Server
if [[ $EPEL -eq 1 || -n $FEDORA ]]; then
    clear
    echo;
    echo "Do you want to install or update Clam AV during this installation process?"; echo;
    echo "This package is recommended unless you plan on using a different virus scanner.";
    echo "Note that you may use more than one virus scanner at once with MailScanner.";
    echo;
    echo "Recommended: Y (yes)"; echo;
    if [ -z "${arg_installClamav+x}" ]; then
        read -r -p "Install or update Clam AV? [n/Y] : " response

        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # user wants clam av installed
            # some of these options may result in a 'no package available' on
            # some distributions, but that is ok
            CAV=1
            CAVOPTION="clamav clamd clamav-update clamav-server clamav-devel";
        elif [ -z $response ]; then  
            CAV=1
            CAVOPTION="clamav clamd clamav-update clamav-server clamav-devel";
        else
            # user does not want clam av
            CAV=0
            CAVOPTION=
        fi
    else
        CAV=${arg_installClamav}
        CAVOPTION=
        if [ ${CAV} -eq 1 ]; then
            CAVOPTION="clamav clamd clamav-update clamav-server clamav-devel";
        fi
    fi
else
    # user did not select EPEL or is not on Fedora Server so clamav is not available via yum
    CAV=0
    CAVOPTION=
fi

# Check if clamav is being installed on CentOS 7 and ask if user wants to configure
if [[ $RHEL -eq 7 && $CAV -eq 1 ]]; then
    clear
    echo;
    echo "Do you want to configure clam AV during this installation process?"; echo;
    echo;
    echo "Choosing yes will install required configuration files and settings for";
    echo "Clam AV to function out of the box on CentOS 7 installations";
    echo;
    echo "Recommended: Y (yes)"; echo;
    if [ -z "${arg_configClamav+x}" ]; then
        read -r -p "Configure Clam AV? [n/Y] : " response

        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # user wants clam av configured
            CONFCAV=1
        elif [ -z $response ]; then
            CONFCAV=1
        else
            CONFCAV=0
        fi
    fi
else
    # Not CentOS/RHEL7 or Clam not being installed/updated
    CONFCAV=0
fi

# ask if the user wants to install tnef by RPM if missing
TNEF="tnef";
clear
echo;
echo "Do you want to install tnef via RPM if missing?"; echo;
echo "I will attempt to install tnef via the Yum Package Manager, but if not found I can ";
echo "install this from an RPM provided by the MailScanner Community Project. Tnef allows";
echo "MailScanner to handle Microsoft specific winmail.dat files.";
echo;
echo "Recommended: Y (yes)"; echo;
if [ -z "${arg_installTNEF+x}" ]; then
    read -r -p "Install missing tnef via RPM? [n/Y] : " response

    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # user wants to use RPM for missing tnef
        TNEFOPTION=1
    elif [ -z $response ]; then 
        # user wants to use RPM for missing tnef
        TNEFOPTION=1
    else
        # user does not want to use RPM
        TNEFOPTION=0
    fi
else
    TNEFOPTION=${arg_installTNEF}
fi

# ask if the user wants to install unrar by RPM if missing
clear
echo;
echo "Do you want to install unrar via RPM if missing?"; echo;
echo "I will attempt to install unrar via the Yum Package Manager, but if not found I can ";
echo "install this from an RPM provided by MailScanner Community Project. unrar allows";
echo "MailScanner to handle archives compressed with rar.";
echo;
echo "Recommended: Y (yes)"; echo;
if [ -z "${arg_installUnrar+x}" ]; then
    read -r -p "Install missing unrar via RPM? [n/Y] : " response
    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # user wants to use RPM for missing unrar
        UNRAROPTION=1
    elif [ -z $response ]; then 
        # user wants to use RPM for missing unrar
        UNRAROPTION=1
    else
        # user does not want to use RPM
        UNRAROPTION=0
    fi
else
    UNRAROPTION=${arg_installUnrar}
fi
# ask if the user wants missing modules installed via CPAN
clear
echo;
echo "Do you want to install missing perl modules via CPAN?"; echo;
echo "I will attempt to install Perl modules via yum, but some may not be unavailable during the";
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
# ask if the user wants to install 3rd party rpms for missing
# perl-Filesys-Df and perl-Sys-Hostname-Long
DFOPTION=0
if [ $RHEL == 7 ]; then
    clear
    echo;
    echo "Do you want to install perl-Filesys-Df and perl-Sys-Hostname-Long via RPM if missing?"; echo;
    echo "perl-Filesys-Df and perl-Sys-Hostname-Long and known to be missing from the Yum base and the";
    echo "EPEL repo for RHEL7 at the release of this installer. I will try to install them from the";
    echo "official Yum base and EPEL repo first. (If you elected the EPEL option.) If they are still ";
    echo "missing I can attempt to install these two missing RPMs with 3rd party RPM packages. If they";
    echo "are still missing and you selected the CPAN remediation I will try to install them from CPAN.";
    echo;
    echo "Recommended: Y (yes)"; echo;
    if [ -z "${arg_installDf+x}" ]; then
        read -r -p "Install these missing items via RPM? [n/Y] : " response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # user wants to use RPM for missing stuff
            DFOPTION=1
        elif [ -z $response ]; then 
            # user wants to use RPM for missing stuff
            DFOPTION=1
        else
            # user does not want to use RPM
            DFOPTION=0
        fi
    else
        DFOPTION=${arg_installDf}
    fi
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
            NODEPS='--nodeps --force'
        else
            # requiring deps
            NODEPS=
        fi
    else
        if [ ${arg_ignoreDeps} -eq 1 ]; then
            NODEPS='--nodeps --force'
        else
            NODEPS=
        fi
    fi
fi

# ask about setting permissive mode for SeLinux
clear
echo;
echo "Set PERMISSIVE mode for SELinux?"; echo;
echo "SELinux will cause problems for virus scanners accessing the working directory";
echo "used when processing email. Enabling permissive mode will allow the virus scanner";
echo "to access the files that need to be scanned until you can create a policy to ";
echo "allow working directory file access while in ENFORCING mode. If you have already";
echo "disabled SELinux selecting 'yes' will not change that. Note that a reboot is ";
echo "required after the installation for this to take effect.";
echo;
echo "Recommended: Y (yes)"; echo;
if [ -z "${arg_SELPermissive+x}" ]; then
    read -r -p "Set permissive mode for SELinux? [n/Y] : " response

    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # user wants to set permissive mode
        SELMODE=1
    elif [ -z $response ]; then 
         # user wants to set permissive mode
        SELMODE=1
    else
        # user does not want to change SELinux
        SELMODE=0
    fi
else
    SELMODE=${arg_SELPermissive}
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
BASEPACKAGES="binutils gcc glibc-devel libaio make man-pages man-pages-overrides patch rpm tar time unzip which zip libtool-ltdl perl curl wget openssl openssl-devel bzip2-devel";

# Packages available in the yum base of RHEL 5,6,7
# and EPEL. If the user elects not to use EPEL or if the 
# package is not available for their distro release it
# will be ignored during the install.
#
MOREPACKAGES="perl-Archive-Tar perl-Archive-Zip perl-Compress-Raw-Zlib perl-Compress-Zlib perl-Convert-BinHex perl-CPAN perl-Data-Dump perl-DBD-SQLite perl-DBI perl-Digest-HMAC perl-Digest-SHA1 perl-Env perl-ExtUtils-MakeMaker perl-File-ShareDir-Install perl-File-Temp perl-Filesys-Df perl-Getopt-Long perl-IO-String perl-IO-stringy perl-HTML-Parser perl-HTML-Tagset perl-Inline perl-IO-Zlib perl-Mail-DKIM perl-Mail-IMAPClient perl-Mail-SPF perl-MailTools perl-Net-CIDR perl-Net-DNS perl-Net-DNS-Resolver-Programmable perl-MIME-tools perl-Convert-TNEF perl-Net-IP perl-OLE-Storage_Lite perl-Pod-Escapes perl-Pod-Simple perl-Scalar-List-Utils perl-Storable perl-Pod-Escapes perl-Pod-Simple perl-Razor-Agent perl-Sys-Hostname-Long perl-Sys-SigAction perl-Test-Manifest perl-Test-Pod perl-Time-HiRes perl-TimeDate perl-URI perl-YAML pyzor re2c unrar tnef perl-Encode-Detect perl-LDAP perl-IO-Compress-Bzip2 p7zip p7zip-plugins perl-LWP-Protocol-https";

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

# 32 or 64 bit
MACHINE_TYPE=`uname -m`

# logging starts here
(
clear
echo;
echo "Installation results are being logged to mailscanner-install.log";
echo;
timewait 1

# install the basics
echo "Installing required base system utilities.";
echo "You can safely ignore 'No package available' errors.";
echo;
timewait 2

# install base packages
$YUM -y --skip-broken install $BASEPACKAGES $EPELOPTION

# install this separate in case it conflicts
if [ "x$MTAOPTION" != "x" ]; then
    $YUM -y install $MTAOPTION
    if [ $? != 0 ]; then
        echo "Error installing $MTAOPTION MTA"
        echo "This usually means an MTA is already installed."
    fi
    if [ $MTAOPTION = "sendmail" ]; then
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

# install required perl packages that are available via yum along
# with EPEL packages if the user elected to do so.
#
# some items may not be available depending on the distribution 
# release but those items will be checked after this and installed
# via cpan if the user elected to do so.
clear
echo;
echo "Installing available Perl packages, Clam AV (if elected), and ";
echo "Spamassassin (if elected) via yum. You can safely ignore any";
echo "subsequent 'No package available' errors."; echo;
timewait 3
$YUM -y --skip-broken install $TNEF $MOREPACKAGES $CAVOPTION $SAOPTION

# install missing tnef if the user elected to do so
if [ $TNEFOPTION == 1 ]; then
    # user elected to use tnef RPM option
    if [ ! -x '/usr/bin/tnef' ]; then
        cd /tmp
        rm -f tnef-1.4.12*
        clear
        echo;
        echo "Tnef missing. Installing via RPM ..."; echo;
        if [ $MACHINE_TYPE == 'x86_64' ]; then
            # 64-bit stuff here
            $CURL -O https://s3.amazonaws.com/msv5/rpm/tnef-1.4.12-1.x86_64.rpm
            if [ -f 'tnef-1.4.12-1.x86_64.rpm' ]; then
                $RPM -Uvh tnef-1.4.12-1.x86_64.rpm
            fi
        elif [ $MACHINE_TYPE == 'i686' ]; then
            # i686 stuff here
            $CURL -O https://s3.amazonaws.com/msv5/rpm/tnef-1.4.12-1.i686.rpm
            if [ -f 'tnef-1.4.12-1.i686.rpm' ]; then
                $RPM -Uvh tnef-1.4.12-1.i686.rpm
            fi
        elif [ $MACHINE_TYPE == 'i386' ]; then
            # i386 stuff here
            $CURL -O https://s3.amazonaws.com/msv5/rpm/tnef-1.4.12-1.i386.rpm
            if [ -f 'tnef-1.4.12-1.i686.rpm' ]; then
                $RPM -Uvh tnef-1.4.12-1.i686.rpm
            fi
        else
            echo "NOTICE: I cannot find a suitable RPM to install tnef (x86_64, i686, i386)";
            timewait 5
        fi
        
        # back to where i started
        rm -f tnef-1.4.12*
        cd "$THISCURRPMDIR"
    fi
fi

# install missing unrar if the user elected to do so
if [ $UNRAROPTION == 1 ]; then
    # user elected to use unrar RPM option
    if [ ! -x '/usr/bin/unrar' ]; then
        cd /tmp
        rm -f unrar-5.0.3*
        clear
        echo;
        echo "unrar missing. Installing via RPM ..."; echo;
        if [ $MACHINE_TYPE == 'x86_64' ]; then
            # 64-bit stuff here
            $CURL -O https://s3.amazonaws.com/msv5/rpm/unrar-5.0.3-1.x86_64.rpm
            if [ -f 'unrar-5.0.3-1.x86_64.rpm' ]; then
                $RPM -Uvh unrar-5.0.3-1.x86_64.rpm
            fi
        elif [ $MACHINE_TYPE == 'i686' ]; then
            # i686 stuff here
            $CURL -O https://s3.amazonaws.com/msv5/rpm/unrar-5.0.3-1.i686.rpm
            if [ -f 'unrar-5.0.3-1.i686.rpm' ]; then
                $RPM -Uvh unrar-5.0.3-1.i686.rpm
            fi
        elif [ $MACHINE_TYPE == 'i386' ]; then
            # i386 stuff here
            $CURL -O https://s3.amazonaws.com/msv5/rpm/unrar-5.0.3-1.i386.rpm
            if [ -f 'unrar-5.0.3-1.i386.rpm' ]; then
                $RPM -Uvh unrar-5.0.3-1.i386.rpm
            fi
        else
            echo "NOTICE: I cannot find a suitable RPM to install unrar (x86_64, i686, i386)";
            timewait 5
        fi
        
        # back to where i started
        rm -f unrar-5.0.3*
        cd "$THISCURRPMDIR"
    fi
fi

# install missing perl-Filesys-Df and perl-Sys-Hostname-Long on RHEL 7
if [ $DFOPTION == 1 ]; then
    # test to see if these are installed. if not install from RPM
    cd /tmp
    rm -f perl-Filesys-Df*
    rm -f perl-Sys-Hostname-Long*
        
    # perl-Filesys-Df
    perldoc -l Filesys::Df >/dev/null 2>&1
    if [ $? != 0 ]; then
        if [ $MACHINE_TYPE == 'x86_64' ]; then
            $CURL -O https://s3.amazonaws.com/msv5/rpm/perl-Filesys-Df-0.92-1.el7.x86_64.rpm
            if [ -f 'perl-Filesys-Df-0.92-1.el7.x86_64.rpm' ]; then
                rpm -Uvh perl-Filesys-Df-0.92-1.el7.x86_64.rpm
            fi
        fi
    fi
    
    # perl-Sys-Hostname-Long
    perldoc -l Sys::Hostname::Long >/dev/null 2>&1
    if [ $? != 0 ]; then
        $CURL -O https://s3.amazonaws.com/msv5/rpm/perl-Sys-Hostname-Long-1.5-1.el7.noarch.rpm
        if [ -f 'perl-Sys-Hostname-Long-1.5-1.el7.noarch.rpm' ]; then
            rpm -Uvh perl-Sys-Hostname-Long-1.5-1.el7.noarch.rpm
        fi
    fi
    
    # go back to where i started
    cd "$THISCURRPMDIR"
fi

# fix the stupid line in /etc/freshclam.conf that disables freshclam 
if [ $CAV == 1 ]; then
    COUT='#Example';
    if [ -f '/etc/freshclam.conf' ]; then
        perl -pi -e 's/Example/'$COUT'/;' /etc/freshclam.conf
    fi
    freshclam
fi

# Configure clamav if required
if [ $CONFCAV -eq 1 ]; then
    # Get clam version
    clamav_version=$(rpm -q --queryformat=%{VERSION} clamav-server)
    # Grab sample config if not present
    if [ ! -f /etc/clamd.d/clamd.conf ]; then
        cp /usr/share/doc/clamav-server-$clamav_version/clamd.conf /etc/clamd.d/clamd.conf
    fi
    # Enable config
    sed -i '/^Example/ c\#Example' /etc/clamd.d/clamd.conf
    # Create clam user if not present
    id -u clam >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        useradd -d /var/lib/clamav -c "Clam Anti Virus Checker" -G virusgroup,clamupdate -s /sbin/nologin -M clam
    fi
    # More config options
    sed -i '/^User <USER>/ c\User clam' /etc/clamd.d/clamd.conf
    sed -i '/#LocalSocket \/var\/run\/clamd.<SERVICE>\/clamd.sock/ c\LocalSocket /var/run/clamd.scan/clamd.sock' /etc/clamd.d/clamd.conf
    sed -i '/#LogFile \/var\/log\/clamd.<SERVICE>/ c\LogFile /var/log/clamd.scan/scan.log' /etc/clamd.d/clamd.conf
    # Log rotation if not present
    if [ ! -f /etc/logrotate.d/clamd.logrotate ]; then
        cp /usr/share/doc/clamav-server-$clamav_version/clamd.logrotate /etc/logrotate.d/
    fi
    # Filesystem/Permissions/SELinux
    chown -R clam:clam /etc/clamd.d
    mkdir -p /var/log/clamd.scan
    chown -R clam:clam /var/log/clamd.scan
    chcon -u system_u -r object_r -t antivirus_log_t /var/log/clamd.scan
    mkdir -p /var/run/clamd.scan
    chown -R clam:clam /var/run/clamd.scan
    chcon -u system_u -r object_r -t antivirus_var_run_t /var/run/clamd.scan
    echo "d /var/run/clamd.scan 0750 clam mtagroup -" > /etc/tmpfiles.d/clamd.conf
    echo "d /var/run/clamd.scan 0750 clam mtagroup -" > /etc/tmpfiles.d/clamd.scan.conf
    # sysconfig file
    if [ ! -f /etc/sysconfig/clamd ]; then
        cat > /etc/sysconfig/clamd << 'EOF'
CLAMD_CONFIGFILE=/etc/clamd.d/clamd.conf
CLAMD_SOCKET=/var/run/clamd.scan/clamd.sock
#CLAMD_OPTIONS=
EOF
    fi

    # Systemd services
    if [ ! -f /usr/lib/systemd/system/clam.freshclam.service ]; then
        cat > /usr/lib/systemd/system/clam.freshclam.service << 'EOF'
[Unit]
Description = freshclam scanner
After = network.target

[Service]
Type = forking
ExecStart = /usr/bin/freshclam -d -c 4
Restart = on-failure
PrivateTmp = true

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    if [ ! -f /usr/lib/systemd/system/clam.scan.service ]; then
        cat > /usr/lib/systemd/system/clam.scan.service << 'EOF'
[Unit]
Description = clamd scanner daemon
After = syslog.target nss-lookup.target network.target

[Service]
Type = forking
ExecStart = /usr/sbin/clamd -c /etc/clamd.d/clamd.conf
Restart = on-failure
PrivateTmp = true

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl enable clam.freshclam
    systemctl enable clam.scan
fi

# now check for missing perl modules and install them via cpan
# if the user elected to do so
clear; echo;
echo "Checking Perl Modules ... "; echo;
timewait 2
# used to trigger a wait if something this missing
PMODWAIT=0

# first try to install missing perl modules via yum
# using this trick
for i in "${ARMOD[@]}"
do
    perldoc -l $i >/dev/null 2>&1
    if [ $? != 0 ]; then
        echo "$i is missing. Trying to install via Yum ..."; echo;
        THING="perl($i)";
        $YUM -y install $THING
    fi
done

# CPAN automation invoked?
if [ -z "${arg_installCPAN+x}" ]; then
    AUTOCPAN=0
else
    if [ $CPANOPTION -eq 1 ]; then
        AUTOCPAN=1
        # Install cpanminus
        $YUM -y install cpanminus
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

if [ $CPANOPTION -eq 1 ]; then
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

# selinux
if [ $SELMODE == 1 ]; then
    OLDTHING='SELINUX=enforcing';
    NEWTHING='SELINUX=permissive';
        
    if [ -f '/etc/selinux/config' ]; then
        perl -pi -e 's/'$OLDTHING'/'$NEWTHING'/;' /etc/selinux/config
    else	
        clear
        echo;
        echo "WARNING: I was unable to find the SELinux configuration file to set";
        echo "the permissive mode. You will need to find the file and set this item";
        echo "manually. Press <return> to continue.";
        read foobar
    fi
fi

# Freshclam
if [ -f '/etc/init.d/clamd' ]; then
    chkconfig clamd on
fi
freshclam 2>/dev/null

# make sure in starting directory
cd "$THISCURRPMDIR"

clear
echo;
echo "Installing the MailScanner RPM ... ";

# install the mailscanner rpm

ABORT=0
# MailScanner version 4 will trigger an rpmsave during update
# MailScanner version 5 will not due to need to drop in a new MailScanner.conf
# during updating every time for comparison, so the following update process
# will cause MailScanner.conf to get overwritten in v5 if it is not moved first
mv /etc/MailScanner/MailScanner.conf /etc/MailScanner/MailScanner.conf.rpmsave >/dev/null 2>&1

# Pass #1 -- without scripts (bypasses prior pre and post uninstall scripts in older versions of mailscanner)
# This resolves two issues
# One is the presence of faulty pre and post scripts in v4 packages
# The second is the presence of a bug in earlier v5 packages during %post
$RPM -Uvh --noscripts $NODEPS MailScanner*noarch.rpm
if [ $? == 0 ]; then

    # Move rpmsaves around so that scripts can find them
    if [[ -e /etc/MailScanner/MailScanner.conf.rpmsave ]]; then 
        mv /etc/MailScanner/MailScanner.conf /etc/MailScanner/MailScanner.conf.rpmnew
        mv /etc/MailScanner/MailScanner.conf.rpmsave /etc/MailScanner/MailScanner.conf
    fi
    if [[ -e /etc/MailScanner/spam.assassin.prefs.conf.rpmsave ]]; then
        mv /etc/MailScanner/spam.assassin.prefs.conf.rpmsave /etc/MailScanner/spam.assassin.prefs.conf
    fi
    
    # Pass #2 -- with scripts
    $RPM -Uvh --force $NODEPS MailScanner*noarch.rpm
    [ $? != 0 ] && ABORT=1
else
    ABORT=1
fi

if [ $ABORT == 1 ]; then
    echo;
    echo '----------------------------------------------------------';
    echo 'Installation Error'; echo;
    echo 'The MailScanner RPM failed to install. Address the required';
    echo 'dependencies and run the installer again. Note that electing';
    echo 'to use EPEL and CPAN should resolve dependency errors.';
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
    
    # fix the clamav wrapper if the user does not exist
    if [ -f '/etc/freshclam.conf' ]; then
        if id -u clam >/dev/null 2>&1; then
            #clam is being used instead of clamav
            OLDCAVUSR='ClamUser="clamav"';
            NEWCAVUSR='ClamUser="clam"'

            if [ -f '/usr/lib/MailScanner/wrapper/clamav-wrapper' ]; then
                perl -pi -e 's/'$OLDCAVUSR'/'$NEWCAVUSR'/;' /usr/lib/MailScanner/wrapper/clamav-wrapper
            fi
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
