#!/usr/bin/perl

# (c) 2018 MailScanner Project <https://www.mailscanner.info>
#          Version 0.1
#
#     This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#    Contributed by Shawn Iverson for MailScanner <shawniverson@efa-project.org>

package MailScanner::Milter;

use strict 'vars';
no strict 'refs';
no strict 'subs';

use File::Basename;
use File::Copy;
use IO::File;
use IO::Pipe;
use Sendmail::PMilter;
use Socket;
use POSIX qw(strftime);
use Sys::Hostname;
use Time::HiRes qw( gettimeofday );

use MailScanner::Lock;
use MailScanner::Log;
use MailScanner::Config;
use MailScanner::Sendmail;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4694 $, 10;

# Encodes string length in postfix queue format
sub encode_length
{
    my ($length) = @_;
    my $lcode = "";

    return chr(0) if $length==0;

    while ($length > 0) {
        if ($length > 127) {
            $lcode .= chr(255);
            $length -= 127;
        } else {
            $lcode .= chr($length);
            $length = 0;
        }
    }

    return $lcode;
}

sub smtp_id
{
    #
    # Alvaro Marin alvaro@hostalia.com - 2016/08/25
    # Adapted for MailScanner Milter
    #
    # Support for Postfix's long queue IDs format (enable_long_queue_ids).
    # The name of the file created in the outgoing queue will be the queue ID.
    # We'll generate it like Postfix does. From src/global/mail_queue.h :
    #
    # The long non-repeating queue ID is encoded in an alphabet of 10 digits,
    # 21 upper-case characters, and 21 or fewer lower-case characters. The
    # alphabet is made "safe" by removing all the vowels (AEIOUaeiou). The ID
    # is the concatenation of:
    #
    # - the time in seconds (base 52 encoded, six or more chars),
    #
    # - the time in microseconds (base 52 encoded, exactly four chars),
    #
    my $seconds=0;
    my $microseconds=0;
    ($seconds, $microseconds) = gettimeofday;
    my $microseconds_orig=$microseconds;
    my @BASE52_CHARACTERS = ("0","1","2","3","4","5","6","7","8","9",
                                "B","C","D","F","G","H","J","K","L","M",
                                "N","P","Q","R","S","T","V","W","X","Y",
                                "Z","b","c","d","f","g","h","j","k","l",
                                "m","n","p","q","r","s","t","v","w","x","y","z");
    my $encoded='';
    my $id_out;
    my $count=0;
    while ($count < 6) {
           $encoded.=$BASE52_CHARACTERS[$seconds%52];
           $seconds/=52;
           $count++;
    }
    $id_out=reverse $encoded;
    $encoded='';
    $count=0;
    while ($count < 4) {
            $encoded.=$BASE52_CHARACTERS[$microseconds%52];
            $microseconds/=52;
            $count++;
    }
    $id_out.=reverse $encoded;

    return $id_out;
}

sub connect_callback
{
        my $ctx = shift;        # Some people think of this as $self
        my $hostname = shift;
        my $sockaddr_in = shift;
        my ($port, $iaddr);
        my $message = "";

        # Initialize Message Reference
        $ctx->setpriv(\$message);
        my $message_ref = $ctx->getpriv();

        ($port, $iaddr) = sockaddr_in($sockaddr_in);

        # Begin building message buffer
        ${$message_ref} = "($hostname [" . inet_ntoa($iaddr) . "])";

        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub helo_callback
{
        my $ctx = shift;
        my $helohost = shift;
        my $message_ref = $ctx->getpriv();
        my $message = "Received: from $helohost";
        # Watch for a duplicate callback
        if ( $message ne substr(${$message_ref}, 0, length($message)) ) {
            ${$message_ref} = $message . ' ' . ${$message_ref} . "\n";
        }

        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub envrcpt_callback
{
        my $ctx = shift;
        my @args = @_;
        my $message_ref = $ctx->getpriv();
        my $datestring = strftime "%a %e %b %Y %T %z (%Z)", localtime;
        my $id = smtp_id;

        ${$message_ref} .= '        by ' . hostname . ' (MailScanner Milter) with SMTP id ' . $id . "\n" . '        for ' . join(', ', @args) . '; ' . $datestring . "\n";

        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub header_callback
{
        my $ctx = shift;
        my $headerf = shift;
        my $headerv = shift;
        my $message_ref = $ctx->getpriv();
        my $queuehandle = new FileHandle;

        ${$message_ref} .= $headerf . ': ' . $headerv . "\n";
        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}


sub body_callback
{
        my $ctx = shift;
        my $body_chunk = shift;
        my $len = shift;
        my $message_ref = $ctx->getpriv();

        ${$message_ref} .= $body_chunk;

        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub eom_callback
{
        my $ctx = shift;
        my $message_ref = $ctx->getpriv();
        # Extract id from message
        # Split message for processing
        # This is grossly inefficient and doubles mem usage, refactor
        # Good enough for testing, though....
        my @lines = split /\n/, ${$message_ref};
        my $id = @lines[1];
        $id =~ s/^.*SMTP id //;

        # Ok we have sufficient info to start writing to disk
        # Refactoring required before release
        my $queuehandle = new FileHandle;
        my $file = "/var/spool/MailScanner/milter/$id";

        # Error checking needed here
        MailScanner::Lock::openlock($queuehandle,'>' . $file, 'w');

        # Generate pseudo queue file readable by MailScanner
        # Not a real postfix queue file, but has sufficient structure
        # for MailScanner to process in its entirety
        # Magic sauce at work here

        # Build metadata for queue file
        my $length=0;
        my $metalength=0;
        my $buffer="";
        my $str='';
        my $lcode='';
        my $numrcpts=-1;

        # S record
        foreach my $line (@lines) {
           if ( $line =~ m/From: / ) {
               $str = $line;
               $str =~ s/^From: //;
               $str =~ s/^.*<//;
               $str =~ s/>.*$//;
           }
        }
        $length = length($str);
        $metalength += $length;
        $lcode = encode_length($length);
        $metalength += length($lcode) + 1;
        $buffer="S" . $lcode . $str;

        # O record
        $str='';
        foreach my $line (@lines) {
            if ( $line =~ m/^To: / ) {
                print $line . "\n";
                $line =~ s/^To: //;
                my @rcpts = split /,/, $line;
                foreach my $to (@rcpts) {
                    if (length($str) > 0) {
                        $str .= ',';
                    }
                    $to =~ s/^.*<//;
                    $to =~ s/>.*$//;
                    if ( length($to) > 0 ) {
                        $str .= $to;
                        $numrcpts++;
                    }
                }
            }
        }
        $length = length($str);
        $metalength += $length;
        $lcode = encode_length($length);
        $metalength += length($lcode) + 1;
        $buffer .= "O" . $lcode . $str;

        # Build C record now that we know metalength
        # C record (size, data offset, # recipients)
        # pad remainder of record (unused by MailScanner)
        my $msgsize=int(length(${$message_ref}));
        my $sizedigits=length("$msgsize");
        my $padding=15-$sizedigits;
        # msg size
        $queuehandle->print('C' . chr(95) . " "x$padding . "$msgsize");
        # data offset
        # This is the size of this record plus the rest of the metadata
        my $dataoffset=$metalength + 96;
        $sizedigits=length("$dataoffset");
        $padding=16-$sizedigits;
        $queuehandle->print(" "x$padding . "$dataoffset");
        # number of recipients
        $sizedigits=length("$numrcpts");
        $padding=16-$sizedigits;
        $queuehandle->print(" "x$padding . "$numrcpts");
        #Pad
        $padding=48;
        $queuehandle->print(" "x$padding);

        # Write rest of meta now and signal of beginning of message
        $queuehandle->print($buffer . "M" . chr(0));

        # Skip T records, A records (unused by mailscanner)
        # Skip R records (placing all in O record, mailscanner doesn't care
        
        # Todo: Signal start of Body record and end of header record (split and refactor)!

        # N records (message chunks)
        foreach my $line (@lines) {
            $length=length($line);
            $lcode=encode_length($length);
            $queuehandle->print("N" . $lcode . $line);
        }
        
        # Todo: Signal end of message and add an X record!

        MailScanner::Lock::unlockclose($queuehandle);

        $ctx->setpriv(undef);

        print "eom callback fired...\n";

        Sendmail::PMilter::SMFIS_DISCARD;
}

my %my_callbacks =
(
        'connect' => \&connect_callback,
        'helo' =>    \&helo_callback,
        'envrcpt' => \&envrcpt_callback,
        'header' =>  \&header_callback,
        'body' =>    \&body_callback,
        'eom' =>     \&eom_callback,
);

my $conn = 'inet:33333@127.0.0.1';
$ENV{PMILTER_DISPATCHER} = 'prefork';
my $milter = Sendmail::PMilter->new();
$milter->setconn($conn);
$milter->register('mymilter',
                  \%my_callbacks,
                  Sendmail::PMilter::SMFI_CURR_ACTS
                 );
# Refactor for posix
$< = $> = getpwnam 'postfix';
$milter->main(10,100);
