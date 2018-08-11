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
use strict 'refs';
no strict 'subs';

use File::Basename;
use File::Copy;
use IO::File;
use IO::Pipe;
use Sendmail::PMilter;
use Socket;
use Unix::Syslog qw(:macros :subs);

use MailScanner::Lock;
use MailScanner::Config;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4694 $, 10;

#
#  Each of these callbacks is actually called with a first argument
#  that is blessed into the pseudo-package Sendmail::Milter::Context. You can
#  use them like object methods of package Sendmail::Milter::Context.
#
#  $ctx is a blessed reference of package Sendmail::Milter::Context to something
#  yucky, but the Mail Filter API routines are available as object methods
#  (sans the smfi_ prefix) from this
#

sub connect_callback
{
        my $ctx = shift;        # Some people think of this as $self
        my $hostname = shift;
        my $sockaddr_in = shift;
        my ($port, $iaddr);

        print "my_connect:\n";
        print "   + hostname: '$hostname'\n";

        if (defined $sockaddr_in)
        {
                ($port, $iaddr) = sockaddr_in($sockaddr_in);
                print "   + port: '$port'\n";
                print "   + iaddr: '" . inet_ntoa($iaddr) . "'\n";
        }

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub helo_callback
{
        my $ctx = shift;
        my $helohost = shift;

        print "my_helo:\n";
        print "   + helohost: '$helohost'\n";

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub envfrom_callback
{
        my $ctx = shift;
        my @args = @_;
        my $message = "";

        print "my_envfrom:\n";
        print "   + args: '" . join(', ', @args) . "'\n";

        $ctx->setpriv(\$message);
        print "   + private data allocated.\n";

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub envrcpt_callback
{
        my $ctx = shift;
        my @args = @_;

        print "my_envrcpt:\n";
        print "   + args: '" . join(', ', @args) . "'\n";

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub header_callback
{
        my $ctx = shift;
        my $headerf = shift;
        my $headerv = shift;

        print "my_header:\n";
        print "   + field: '$headerf'\n";
        print "   + value: '$headerv'\n";

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub eoh_callback
{
        my $ctx = shift;

        print "my_eoh:\n";
        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub body_callback
{
        my $ctx = shift;
        my $body_chunk = shift;
        my $len = shift;
        my $message_ref = $ctx->getpriv();

        # Note: You don't need $len to have a good time.
        # But it's there if you like.

        print "my_body:\n";
        print "   + chunk len: $len\n";

        ${$message_ref} .= $body_chunk;

        $ctx->setpriv($message_ref);

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub eom_callback
{
        my $ctx = shift;
        my $message_ref = $ctx->getpriv();
        my $chunk;

        print "my_eom:\n";
        print "   + adding line to message body...\n";

        # Let's have some fun...
        # Note: This doesn't support messages with MIME data.

        # Pig-Latin, Babelfish, Double dutch, soo many possibilities!
        # But we're boring...

        ${$message_ref} .= "---> Append me to this message body!\r\n";

        if (not $ctx->replacebody(${$message_ref}))
        {
                print "   - write error!\n";
                last;
        }

        $ctx->setpriv(undef);
        print "   + private data cleared.\n";

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub abort_callback
{
        my $ctx = shift;

        print "my_abort:\n";

        $ctx->setpriv(undef);
        print "   + private data cleared.\n";

        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

sub close_callback
{
        my $ctx = shift;

        print "my_close:\n";
        print "   + callback completed.\n";

        Sendmail::PMilter::SMFIS_CONTINUE;
}

my %my_callbacks =
(
        'connect' => \&connect_callback,
        'helo' =>    \&helo_callback,
        'envfrom' => \&envfrom_callback,
        'envrcpt' => \&envrcpt_callback,
        'header' =>  \&header_callback,
        'eoh' =>     \&eoh_callback,
        'body' =>    \&body_callback,
        'eom' =>     \&eom_callback,
        'abort' =>   \&abort_callback,
        'close' =>   \&close_callback,
);

my $conn = 'inet:33333@127.0.0.1';
$ENV{PMILTER_DISPATCHER} = 'prefork';
my $milter = Sendmail::PMilter->new();
$milter->setconn($conn);
$milter->register('mymilter',
                  \%my_callbacks,
                  Sendmail::PMilter::SMFI_CURR_ACTS
                 );
openlog 'mymilter', 'pid', Unix::Syslog::LOG_MAIL();
$< = $> = getpwnam 'nobody';
syslog LOG_INFO, "Starting up: $$";

END { closelog }

$milter->main(10,100);
