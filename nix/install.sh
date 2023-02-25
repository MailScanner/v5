#!/bin/bash
#
# MailScanner installation script for NIX* based systems
# 
#
# Updated: Feb 24 2023
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
echo "WARNING: backup your custom MailScanner files before proceeding. They will be overwritten!";
echo;
echo "These items should be installed before proceeding: perl, perldoc, curl, wget, cpan, sudo,"
echo "tar, and essential perl build tools such as make.";
echo;
echo "It is necessary for you to generate your own cpan configuration for root and the sabuild"
echo "user before proceeding with cpan installation with this script, since your flavor of NIX"
echo "is not known and paths for various tooling differ."
echo "root can be autoconfigured by choosing yes by running cpan, but sabuild needs to be"
echo "manually configured (by saying no to auto config) and to use sudo while the rest of the"
echo "configuration can be defaults. If sabuild doesn't exist yet, create the user first."
echo;
echo "If you are using RHEL derivatives, Debian derivatives (including Ubuntu), or openSUSE"
echo "derivatives, use the appropriate package and not this method from tarball for a greater"
echo "chance of success."
echo;
echo "To install SpamAssassin 4.0, an unprivileged user 'sabuild' will be needed and granted";
echo "temporary sudo privileges. This is necessary to obtain a successful build. sudo privileges";
echo "will be removed after install, and you can optionally remove the 'sabuild' user at any time";
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
echo "WARNING: You must have perl, perldoc, curl, wget, cpan, sudo,"
echo "tar, and essential perl build tools such as make for this to work!"
echo;
echo "You must have a working cpan configuration for root (defaults) and"
echo "an sabuild user (sudo) for this to work!"
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
ARMOD+=('Archive::Tar');            ARMOD+=('Archive::Zip');                ARMOD+=('bignum');                
ARMOD+=('Carp');                    ARMOD+=('Compress::Zlib');              ARMOD+=('Compress::Raw::Zlib');    
ARMOD+=('Convert::BinHex');         ARMOD+=('Convert::TNEF');               ARMOD+=('Data::Dumper');        
ARMOD+=('Date::Parse');             ARMOD+=('DBD::SQLite');                 ARMOD+=('DBI');                    
ARMOD+=('Digest::HMAC');            ARMOD+=('Digest::MD5');                 ARMOD+=('Digest::SHA1');         
ARMOD+=('DirHandle');               ARMOD+=('ExtUtils::MakeMaker');         ARMOD+=('Fcntl');                
ARMOD+=('File::Basename');          ARMOD+=('File::Copy');                  ARMOD+=('File::Path');            
ARMOD+=('File::Spec');              ARMOD+=('File::Temp');                  ARMOD+=('FileHandle');            
ARMOD+=('Filesys::Df');             ARMOD+=('Getopt::Long');                ARMOD+=('Inline::C');            
ARMOD+=('IO');                      ARMOD+=('IO::File');                    ARMOD+=('IO::Pipe');            
ARMOD+=('IO::Stringy');             ARMOD+=('HTML::Entities');              ARMOD+=('HTML::Parser');        
ARMOD+=('HTML::Tagset');            ARMOD+=('HTML::TokeParser');            ARMOD+=('Mail::Field');            
ARMOD+=('Mail::Header');            ARMOD+=('Mail::IMAPClient');            ARMOD+=('Mail::Internet');        
ARMOD+=('Math::BigInt');            ARMOD+=('Math::BigRat');                ARMOD+=('MIME::Base64');        
ARMOD+=('MIME::Decoder');           ARMOD+=('MIME::Decoder::UU');           ARMOD+=('MIME::Head');            
ARMOD+=('MIME::Parser');            ARMOD+=('MIME::QuotedPrint');           ARMOD+=('MIME::Tools');            
ARMOD+=('MIME::WordDecoder');       ARMOD+=('Net::CIDR');                   ARMOD+=('Net::DNS');            
ARMOD+=('Net::IP');                 ARMOD+=('OLE::Storage_Lite');           ARMOD+=('Pod::Escapes');        
ARMOD+=('Pod::Simple');             ARMOD+=('POSIX');                       ARMOD+=('Scalar::Util');        
ARMOD+=('Socket');                  ARMOD+=('Storable');                    ARMOD+=('Test::Harness');        
ARMOD+=('Test::Pod');               ARMOD+=('Test::Simple');                ARMOD+=('Time::HiRes');            
ARMOD+=('Time::localtime');         ARMOD+=('Sys::Hostname::Long');         ARMOD+=('Sys::SigAction');        
ARMOD+=('Sys::Syslog');             ARMOD+=('Env');                         ARMOD+=('LWP::UserAgent');
ARMOD+=('Data::Dump');              ARMOD+=('DB_File');                     ARMOD+=('DBD::SQLite');
ARMOD+=('DBI');                     ARMOD+=('Digest');                      ARMOD+=('Encode::Detect');
ARMOD+=('Error');                   ARMOD+=('ExtUtils::CBuilder');          ARMOD+=('ExtUtils::ParseXS');
ARMOD+=('Getopt::Long');            ARMOD+=('Inline');                      ARMOD+=('IO::String');    
ARMOD+=('IO::Zlib');                ARMOD+=('IP::Country');                 ARMOD+=('Mail::SPF');
ARMOD+=('Mail::SPF::Query');        ARMOD+=('Module::Build');               ARMOD+=('Net::CIDR::Lite');
ARMOD+=('Net::DNS');                ARMOD+=('Net::LDAP');                   ARMOD+=('Net::DNS::Resolver::Programmable');
ARMOD+=('NetAddr::IP');             ARMOD+=('Parse::RecDescent');           ARMOD+=('Test::Harness');
ARMOD+=('Test::Manifest');          ARMOD+=('Text::Balanced');              ARMOD+=('URI');
ARMOD+=('version');                 ARMOD+=('IO::Compress::Bzip2');         ARMOD+=('Sendmail::PMilter');
ARMOD+=('Filesys::Df');             ARMOD+=('IO::Wrap');                    ARMOD+=('CPAN');                        
ARMOD+=('Razor2::Client::Agent');   ARMOD+=('File::ShareDir::Install');     ARMOD+=('Mail::DKIM');              
ARMOD+=('Math::Int64');             ARMOD+=('IP::Country::DB_File');        ARMOD+=('namespace::autoclean');     
ARMOD+=('Data::IEEE754');           ARMOD+=('Data::Printer');               ARMOD+=('Data::Validate::IP');     
ARMOD+=('List::AllUtils');          ARMOD+=('List::SomeUtils');             ARMOD+=('Net::DNS::Nameserver');     
ARMOD+=('List::UtilsBy');           ARMOD+=('MaxMind::DB::Metadata');       ARMOD+=('MaxMind::DB::Reader');     
ARMOD+=('Module::Runtime');         ARMOD+=('Moo');                         ARMOD+=('MooX::StrictConstructor');     
ARMOD+=('Role::Tiny');              ARMOD+=('strictures');                  ARMOD+=('DBD::mysql');     
ARMOD+=('Sub::Quote');              ARMOD+=('Math::Int128');                ARMOD+=('Net::Works::Network');     
ARMOD+=('MaxMind::DB::Reader::XS'); ARMOD+=('Geo::IP');                     ARMOD+=('GeoIP2::Database::Reader');     
ARMOD+=('HTTP::Date');              ARMOD+=('LWP::Protocol::https');        ARMOD+=('Net::DNS::Resolver::Programmable');
ARMOD+=('Net::LibIDN');             ARMOD+=('Net::LibIDN2');                ARMOD+=('Test::Perl::Critic');     
ARMOD+=('Devel::Cycle');            ARMOD+=('Perl::Critic::Policy');        ARMOD+=('Perl::Critic::Policy::TestingAndDebugging::ProhibitNoStrict');
ARMOD+=('TimeDate');                ARMOD+=('YAML');                        ARMOD+=('Perl::Critic::Policy::Perlsecret');
ARMOD+=('Path::Class');             ARMOD+=('Test::Fatal');                 ARMOD+=('Test::Number::Delta');
ARMOD+=('Data::Dumper::Concise');   ARMOD+=('DateTime');                    ARMOD+=('Test::Warnings');
ARMOD+=('autodie');                 ARMOD+=('Test::Requires');              ARMOD+=('Test::Tester');
ARMOD+=('Clone::PP');               ARMOD+=('File::HomeDir');               ARMOD+=('Sort::Naturally');
ARMOD+=('JSON::MaybeXS');           ARMOD+=('Test::LeakTrace');             ARMOD+=('Throwable');
ARMOD+=('Alien::Build');            ARMOD+=('Alien::Libxml2');              ARMOD+=('Alien::Build::Plugin::Download::GitLab');
ARMOD+=('BSD::Resource');           ARMOD+=('DBIx::Simple');                ARMOD+=('Email::Abstract');
ARMOD+=('Email::Address::XS');      ARMOD+=('Email::Date::Format');         ARMOD+=('Email::MessageID');
ARMOD+=('Email::MIME');             ARMOD+=('Email::MIME::ContentType');    ARMOD+=('Email::MIME::Encodings');
ARMOD+=('Email::Sender');           ARMOD+=('Email::Simple');               ARMOD+=('FFI::CheckLib');
ARMOD+=('File::chdir');             ARMOD+=('IO::Socket::INET6');           ARMOD+=('Mail::DMARC');
ARMOD+=('MIME::Types');             ARMOD+=('MooX::Types::MooseLike');      ARMOD+=('Net::IDN::Encode');
ARMOD+=('Net::IMAP::Simple');       ARMOD+=('Net::Patricia');               ARMOD+=('Net::SMTPS');
ARMOD+=('Regexp::Common');          ARMOD+=('Test::Exception');             ARMOD+=('Test::Output');
ARMOD+=('Test::Regexp');            ARMOD+=('XML::LibXML');                 ARMOD+=('XML::NamespaceSupport');
ARMOD+=('XML::SAX');                ARMOD+=('XML::SAX::Base');              ARMOD+=('MailTools');
ARMOD+=('Business::ISBN');          ARMOD+=('Config::YAML');                ARMOD+=('Test::Pod::Coverage');
ARMOD+=('Business::ISBN::Data');    ARMOD+=('HTML::TokeParser::Simple');    ARMOD+=('Test::Deep');
ARMOD+=('Algorithm::Diff');         ARMOD+=('B::Keywords');                 ARMOD+=('Capture::Tiny');
ARMOD+=('Config::Tiny');            ARMOD+=('Devel::Hide');                 ARMOD+=('File::Copy::Recursive');
ARMOD+=('Hook::LexWrap');           ARMOD+=('Importer');                    ARMOD+=('Lingua::EN::Inflect');
ARMOD+=('MIME::Charset');           ARMOD+=('Module::Pluggable');           ARMOD+=('Mozilla::CA');
ARMOD+=('PPI');                     ARMOD+=('PPIx::QuoteLike');             ARMOD+=('PPIx::Regexp');
ARMOD+=('PPIx::Utilities');         ARMOD+=('Perl::Critic');                ARMOD+=('Perl::Tidy');
ARMOD+=('Pod::Spell');              ARMOD+=('Readonly::XS');                ARMOD+=('Scope::Guard');
ARMOD+=('String::Format');          ARMOD+=('Sub::Info');                   ARMOD+=('Sub::Uplevel');
ARMOD+=('Task::Weaken');            ARMOD+=('Term::Size::Any');             ARMOD+=('Term::Size::Perl');
ARMOD+=('Term::Table');             ARMOD+=('Test::File');                  ARMOD+=('Test::File::ShareDir');
ARMOD+=('Test::NoWarnings');        ARMOD+=('Test::Object');                ARMOD+=('Test::SubCalls');
ARMOD+=('Test2::Suite');            ARMOD+=('Text::Diff');                  ARMOD+=('Text::Unidecode');
ARMOD+=('Unicode::LineBreak');      ARMOD+=('Getopt::Long::Descriptive');   ARMOD+=('Net::CIDR::Set');
ARMOD+=('Authen::SASL');            ARMOD+=('B::COW');                      ARMOD+=('Class::Tiny');
ARMOD+=('Clone');                   ARMOD+=('Encode');                      ARMOD+=('Encode::Locale');
ARMOD+=('ExtUtils::Config');        ARMOD+=('ExtUtils::Helpers');           ARMOD+=('ExtUtils::InstallPaths');
ARMOD+=('File::Listing');           ARMOD+=('File::Slurper');               ARMOD+=('HTTP::Cookies');
ARMOD+=('HTTP::Daemon');            ARMOD+=('HTTP::Message');               ARMOD+=('HTTP::Negotiate');
ARMOD+=('IO::Compress::Brotli');    ARMOD+=('IO::HTML');                    ARMOD+=('IO::Socket::SSL');
ARMOD+=('LWP::MediaTypes');         ARMOD+=('Module::Build::Tiny');         ARMOD+=('Net::HTTP');
ARMOD+=('Net::SSLeay');             ARMOD+=('PerlIO::utf8_strict');         ARMOD+=('Readonly');
ARMOD+=('Socket6');                 ARMOD+=('Test::FailWarnings');          ARMOD+=('Test::Needs');
ARMOD+=('Test::NoWarnings');        ARMOD+=('Test::Object');                ARMOD+=('Test::Output');
ARMOD+=('Test::RequiresInternet');  ARMOD+=('Time::Local');                 ARMOD+=('WWW::RobotRules');

# spamassassin and plugins
SAMOD=();
SAMOD+=('Mail::SpamAssassin');
SAMOD+=('Mail::SpamAssassin::Plugin::Rule2XSBody');		
SAMOD+=('Mail::SpamAssassin::Plugin::DCC');				
SAMOD+=('Mail::SpamAssassin::Plugin::Pyzor');

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
# since the NIX flavor is unknown, user needs to create their own cpan config
if [ $CPANOPTION == 1 ]; then
	# user elected to use CPAN option
	if [ ! -f '/root/.cpan/CPAN/MyConfig.pm' ]; then
		echo;
		echo "CPAN config missing for root, have you configured cpan?"
        echo "Hint: run cpan and answer yes to autoconfigure, then try again."
        echo;
        exit 1
	fi
fi

# once messed with freshclam here but this script doesn't install it so removed

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

# Set up for sudo build (SA 4.0+)
# Since the NIX flavor is unknown, user has to create sabuild and generate
# cpan config to use sudo
if [ $CPANOPTION -eq 1 ]; then
    id -u sabuild &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ! -f '/home/sabuild/.cpan/CPAN/MyConfig.pm' ]; then
            echo;
            echo "sabuild user present but cpan config missing!"
            echo "Have you configured cpan as sabuild?"
            echo "Hint: run cpan as sabuild, answer no to auto configure, choose sudo,"
            echo "and accept defaults for the rest (hit enter, many times)."
            echo;
            exit 1
        fi

        echo "sabuild    ALL=(ALL)    NOPASSWD: ALL" > /etc/sudoers.d/sabuild

        for i in "${SAMOD[@]}"
        do
            perldoc -l $i >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                clear
                echo "$i is missing or needs updated. Installing via CPAN ..."; echo;
                timewait 1
                su - sabuild -s /bin/bash -c "echo \"\\\n\" | perl -MCPAN -e \"CPAN::Shell->force(qw(install $i ));\""
            else
                echo "$i => OK";
            fi
        done

        # Cleanup, just revoke sudo privs
        rm -f /etc/sudoers.d/sabuild
    else
        echo "Unable to detect sabuild user, cannot install spamassassin"
        echo;
        exit 1
    fi
fi

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