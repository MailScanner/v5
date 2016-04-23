#!/usr/bin/env bash

# MailScanner perl module checker
#
# This script will check for any missing perl modules.
#
# Jerry Benton <mailscanner@mailborder.com>
# 27 FEB 2015

# check for perldoc
if [ ! -x /usr/bin/perldoc ]; then
	clear
	echo;
	echo "The perldoc command cannot be found. I need this program to check your";
	echo "modules. Install it or edit this script to point to the correct location.";
	echo;
	exit 1
else
	PERLDOC='/usr/bin/perldoc';
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
ARMOD+=('Sys::Syslog'); 		ARMOD+=('Env'); 				ARMOD+=('File::ShareDir::Install');


# These are optional
ARMOD2=();
ARMOD2+=('Mail::SpamAssassin'); 	
ARMOD2+=('bignum');					ARMOD2+=('Business::ISBN');		ARMOD2+=('Business::ISBN::Data');
ARMOD2+=('Data::Dump');				ARMOD2+=('DB_File');			ARMOD2+=('DBD::SQLite');
ARMOD2+=('DBI');					ARMOD2+=('Digest');				ARMOD2+=('Encode::Detect');
ARMOD2+=('Error');					ARMOD2+=('ExtUtils::CBuilder');	ARMOD2+=('ExtUtils::ParseXS');
ARMOD2+=('Getopt::Long');			ARMOD2+=('Inline');				ARMOD2+=('IO::String');	
ARMOD2+=('IO::Zlib');				ARMOD2+=('IP::Country');		ARMOD2+=('Mail::SPF');
ARMOD2+=('Mail::SPF::Query');		ARMOD2+=('Module::Build');		ARMOD2+=('Net::CIDR::Lite');
ARMOD2+=('Net::DNS');				ARMOD2+=('Net::LDAP');			ARMOD2+=('Net::DNS::Resolver::Programmable');
ARMOD2+=('NetAddr::IP');			ARMOD2+=('Parse::RecDescent');	ARMOD2+=('Test::Harness');
ARMOD2+=('Test::Manifest');			ARMOD2+=('Text::Balanced');		ARMOD2+=('URI');	
ARMOD2+=('version');					

for i in "${ARMOD[@]}"
do
	$PERLDOC -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "WARNING: $i => Missing";
	else
		echo "$i => OK";
	fi
done

for i in "${ARMOD2[@]}"
do
	$PERLDOC -l $i >/dev/null 2>&1
	if [ $? != 0 ]; then
		echo "OPTIONAL: $i => Missing";
	else
		echo "$i => OK";
	fi
done
