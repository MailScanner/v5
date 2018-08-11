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
use strict 'subs';

use File::Basename;
use File::Copy;
use IO::File;
use IO::Pipe;
use Sendmail::PMilter;
use Socket;

use MailScanner::Lock;
use MailScanner::Config;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4694 $, 10;

my $conn = 'local:/var/run/mymilter.sock';
my $milter = Sendmail::PMilter->new();
$milter->setconn($conn);
$milter->register('mymilter',
                  {}
                  Sendmail::PMilter::SMFI_CURR_ACTS
                 );
$< = $> = getpwnam 'nobody';
$milter->main()