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
  return sprintf("%05X%lX", int(rand 1000000)+1, int(rand 1000000)+1);
}

sub connect_callback
{
        my $ctx = shift;
        my $hostname = shift;
        my $sockaddr_in = shift;
        my ($port, $iaddr);
        my $message_ref = $ctx->getpriv();

        $message = $hostname

        if (defined $sockaddr_in)
        {
            ($port, $iaddr) = sockaddr_in($sockaddr_in);
            $message .= '[' . $iaddr . ']';
        }

        return SMFIS_CONTINUE;
}

sub helo_callback
{
        my $ctx = shift;
        my $helohost = shift;
        my $message_ref = $ctx->getpriv();
        my $message = "Received: from $helohost" . ' (' . $message . ')';
        # Watch for the second callback
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
        my $id = smtp_id;
        my $message_ref = $ctx->getpriv();
        my $datestring = strftime "%a %e %b %Y %T %z (%Z)", localtime;
        my $symbols = $ctx->{symbols};
  
        if (defined($symbols->{'H'}) && defined($symbols->{'H')->{'{tls_version}'}) && defined($symbols->{'H'}->{'{cipher}'}) && defined($symbols->'H'->{'{cipher_bits}'})) {
            ${$message_ref} .= '        (using ' . $symbols->{'H')->{'{tls_version}'} . ' with cipher ' . $symbols->{'H'}->{'{cipher}'} . '(' . $symbols->'H'->{'{cipher_bits}'} . '/' . $symbols->'H'->{'{cipher_bits}'} . ' bits))'
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
        my $queuehandle = new FileHandle;

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
        # Extract id from message efficiently
        while ($str =~ /([^\n]+\n?/g) {
            if ( $1 =~ m/^.*SMTP id / )
                $id = $1;
                $id =~ s/^.*SMTP id //;
                last;
            }
        }

        # Ok we have sufficient info to start writing to disk
        my $queuehandle = new FileHandle;
        my $file = "/var/spool/MailScanner/milter/$id";

        # Error checking needed here
        MailScanner::Lock::openlock($queuehandle,'>' . $file, 'w');

        # Write out to disk
        while ($str =~ /([^\n]+\n?/g) {
           $queuehandle->print($1);
        }

        MailScanner::Lock::unlockclose($queuehandle);

        $ctx->setpriv(undef);

        print "eom callback fired...\n";

        #Sendmail::PMilter::SMFIS_DISCARD;
        Sendmail::PMilter::SMFIS_CONTINUE;
}

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
$milter->setconn($conn);
$milter->register('mymilter',
                  \%my_callbacks,
                  Sendmail::PMilter::SMFI_CURR_ACTS
                 );
$< = $> = getpwnam 'postfix';
$milter->main(10,100);
