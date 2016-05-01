#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: MyExample.pm,v 1.1.2.1 2004/03/23 09:23:43 jkf Exp $
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#      https://www.mailscanner.info
#

package MailScanner::CustomConfig;

use FileHandle;
use File::Temp qw(tempfile tempdir);

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 1.1.2.1 $, 10;

my $Debug = 0; # Set to 1 to enable debug output to STDERR
#my $tmpfilename = "/tmp/MailScanner.$$.conf"; # Temp MS.conf file



############################################################################
############################################################################
############################################################################

#
# This is an example of how to make a Custom Function for an setting call
# a ruleset for that setting, so you can have a Custom Function which
# may (if necessary in your application) call a ruleset to work out its value.
#

# The only bit you need to change is the value for "$option" in each function
# which should be the external name of the config option.
# The external name is the name that appears in MailScanner.conf but with
# nothing except a-z and 0-9, all lower-case.

############################################################################
#
# Virus Scanning =
#
sub InitVirusScanning {
  my($ruleset) = @_;

  my $option = 'virusscanning'; # External (MailScanner.conf-version)

  # Make the temporary 1-line MailScanner.conf file, use it and delete it
  my($fh, $tmpfilename) = tempfile("MailScanner.XXXXXX", TMPDIR => 1, UNLINK => 0);
  print $fh $option . " = $ruleset\n";
  $fh->close;

  MailScanner::Config::SetFileValue($option, undef);
  # Must ensure the ruleset for this option is empty before we start reading.
  # It is vital the string in the next line is exactly 'nodefaults'.
  MailScanner::Config::ReadData($tmpfilename, 'nodefaults');
  unlink $tmpfilename;
}

sub VirusScanning {
  my($message) = @_;

  my $option = 'virusscanning';

  return LookupRuleset($option, $message);
}

sub EndVirusScanning {

  my $option = 'virusscanning';

  MailScanner::Log::InfoLog("Shutting down $option");
}

# Lookup the ruleset for a given message and option name
# (external name as in MailScanner.conf but all lower-case
# and no spaces or punctuation).
sub LookupRuleset {
  my($option, $message) = @_;
  
  $option = lc($option);

  print STDERR "Looking up ruleset $option for message " .
               $message->{id} . "\n" if $Debug;

  # All the rulesets have 127.0.0.1 --> 0
  return 1 unless $message;
  return 0 if $message->{clientip} =~ /^127\.0\.0/;

  # Just evaluate the ruleset
  my $E2I = MailScanner::Config::GetEtoI();
  # The E2I entry doesn't exist if E == I
  my $Ioption = $option;
  $Ioption = $E2I->{$option} if $E2I->{$option};
  # Get the old Custom Function name and delete it
  my $funcname = MailScanner::Config::GetCustomFunction($Ioption);
  MailScanner::Config::SetCustomFunction($Ioption, undef);
  print STDERR "About to lookup ruleset for $option ($Ioption)\n" if $Debug;
  my $rulesetresult = MailScanner::Config::Value($Ioption, $message);
  print STDERR "The ruleset for $option ($Ioption) said $rulesetresult\n" if $Debug;
  # Restore the old Custom Function name
  MailScanner::Config::SetCustomFunction($Ioption, $funcname);
  return $rulesetresult;
}



# This file must end with the following line
no strict;
1;

