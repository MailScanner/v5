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

# Pseudo short postfix ids for now
sub smtp_id {
  # Cannot access Config in callback, use ms-peek
  my $type = `/usr/sbin/ms-peek "MSMail Queue Type" /etc/MailScanner/MailScanner.conf`;
  $type = s/\n//;
  if ($type eq "long") {
        # Long queue IDs
        my $seconds=0;
        my $microseconds=0;
        use Time::HiRes qw( gettimeofday );
        ($seconds, $microseconds) = gettimeofday;
        my $microseconds_orig=$microseconds;
        my @BASE52_CHARACTERS = ("0","1","2","3","4","5","6","7","8","9",
                                "B","C","D","F","G","H","J","K","L","M",
                                "N","P","Q","R","S","T","V","W","X","Y",
                                "Z","b","c","d","f","g","h","j","k","l",
                                "m","n","p","q","r","s","t","v","w","x","y","z");
        my $encoded='';
        my $file_out;
        my $count=0;
        while ($count < 6) {
                $encoded.=$BASE52_CHARACTERS[$seconds%52];
                $seconds/=52;
                $count++;
        }
        $file_out=reverse $encoded;
        $encoded='';
        $count=0;
        while ($count < 4) {
                $encoded.=$BASE52_CHARACTERS[$microseconds%52];
                $microseconds/=52;
                $count++;
        }
        $file_out.=reverse $encoded;

        # We check the generated ID...
        if ($file_out !~ /[A-Za-z0-9]{12,20}/) {
                # Something has gone wrong, back to short ID for safety
                MailScanner::Log::WarnLog("Milter:  ERROR generating long queue ID");
                $file_out = sprintf("%05X%lX", int(rand 1000000)+1, int(rand 1000000)+1);
        }
     return $file_out;
  } else {
      return sprintf("%05X%lX", int(rand 1000000)+1, int(rand 1000000)+1);
  }
}

sub connect_callback
{
        my $ctx = shift;
        my $hostname = shift;
        my $sockaddr_in = shift;
        my ($port, $iaddr);
        my $ip;
        my $message_ref = $ctx->getpriv();

        my $message = $hostname;

        if (defined $sockaddr_in)
        {
            ($port, $iaddr) = sockaddr_in($sockaddr_in);
            $ip = inet_ntoa($iaddr);
            $message .= ' [' . $ip . ']';
        }

        ${$message_ref} = $message;
      
        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub helo_callback
{
        my $ctx = shift;
        my $helohost = shift;
        my $message_ref = $ctx->getpriv();
        my $message = "Received: from $helohost";
        # Watch for the second callback
        if ( $message ne substr(${$message_ref}, 0, length($message)) ) {
            ${$message_ref} = $message . ' (' . ${$message_ref} . ')' ."\n";
        }

        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub envrcpt_callback
{
        my $ctx = shift;
        my @args = @_;
        my $id = smtp_id;
        my $message_ref = $ctx->getpriv();
        my $datestring = strftime "%a, %e %b %Y %T %z (%Z)", localtime;
        my $symbols = $ctx->{symbols};
  
        # Todo?
        # display ssl certs if client provided them maybe...
        if (defined($symbols->{'H'}) && defined($symbols->{'H'}->{'{tls_version}'}) && defined($symbols->{'H'}->{'{cipher}'}) && defined($symbols->{'H'}->{'{cipher_bits}'})) {
            ${$message_ref} .= '        (using ' . $symbols->{'H'}->{'{tls_version}'} . ' with cipher ' . $symbols->{'H'}->{'{cipher}'} . ' (' . $symbols->{'H'}->{'{cipher_bits}'} . '/' . $symbols->{'H'}->{'{cipher_bits}'} . ' bits))' . "\n";
        }
        if (!defined($symbols->{'H'}->{'{cert_subject}'})) {
            ${$message_ref} .= '        (no client certificate requested)' . "\n";
        }
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

        ${$message_ref} .= $headerf . ': ' . $headerv . "\n";
        $ctx->setpriv($message_ref);

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub eoh_callback
{
        my $ctx = shift;
        my $message_ref = $ctx->getpriv();

        # Signal the end of the header here
        ${$message_ref} .= "\n";

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
        my $id ='';
        my $buffer='';
        # Extract id from message efficiently
        while (${$message_ref} =~ /([^\n]+)\n?/g) {
            $id = $1;
            $buffer .= $1 . "\n";
            if ( $id =~ m/^.*SMTP id / ) {
                $id =~ s/^.*SMTP id //;
                last;
            }
        }

        # Ok we have sufficient info to start writing to disk
        my $queuehandle = new FileHandle;
        # Cannot access config values inside of this callback, use ms-peek
        my $incoming = `/usr/sbin/ms-peek "Incoming Queue Dir" /etc/MailScanner/MailScanner.conf`;
        $incoming =~ s/\n//;
        if ($incoming eq '') {
            MailScanner::Log::WarnLog("Milter:  Unable to determine incoming queue!");
            Sendmail::PMilter::SMFIS_TEMPFAIL;
            return;
        }
        my $file = "$incoming/$id";

        # Error checking needed here
        MailScanner::Lock::openlock($queuehandle,'>' . $file, 'w');
        if (!defined($queuehandle)) {
            MailScanner::Log::WarnLog("Milter:  Unable to to open queue file for writing!");
            Sendmail::PMilter::SMFIS_TEMPFAIL;
            return;
        }

        # Write out to disk
        $queuehandle->print($buffer);
        while (${$message_ref} =~ /(.*)\n?/g) {
           $queuehandle->print($1 . "\n");
        }

        $queuehandle->flush();
        MailScanner::Lock::unlockclose($queuehandle);

        $ctx->setpriv(undef);

        Sendmail::PMilter::SMFIS_DISCARD;
}


my $pid = fork;

if (!defined($pid)) {
    MailScanner::Log::WarnLog("MailScanner: Milter:  Unable to fork!");
}
if ($pid == 0) {
    my %my_callbacks =
    (
        'connect' => \&connect_callback,
        'helo' =>    \&helo_callback,
        'envrcpt' => \&envrcpt_callback,
        'header' =>  \&header_callback,
        'eoh' =>     \&eoh_callback,
        'body' =>    \&body_callback,
        'eom' =>     \&eom_callback,
    );
    
    my $conn = 'inet:33333@127.0.0.1';
    $ENV{PMILTER_DISPATCHER} = 'prefork';
    my $milter = Sendmail::PMilter->new();
    $milter->register('mymilter',
                  \%my_callbacks,
                  Sendmail::PMilter::SMFI_CURR_ACTS
                 );
    $milter->setconn($conn);
    $< = $> = getpwnam('postfix');
    $( = $) = getgrnam('mtagroup');
    $0 = "MailScanner: Milter Process";
    $milter->main(10,100);
}

1;
