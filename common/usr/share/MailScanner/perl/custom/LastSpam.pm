#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: LastSpam.pm,v 1.1.2.1 2004/03/23 09:23:43 jkf Exp $
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
#my $tmpfilename = "/tmp/MailScanner.LastSpam.$$.conf"; # Temp MS.conf file
# Temp MS.conf file
# my($tmpfh, $tmpfilename) = tempfile("MailScanner.LastSpam.XXXXXX", TMPDIR => 1, UNLINK => 0);
my %modtime = (); # Time domain list magic word file was last changed
my %filename = (); # Map Config option to magic word file
my %magicwords = {}; # Map Config option --> domains --> magic words
my %rulesetmodtime = (); # Map option name to last file modification time
my %rulesetfilename = (); # Map Config option to ruleset file
my %ruleset = {}; # Map Config option --> domains --> 1

my %ReadConfDone = (); # Have we done the ReadConf for this option
# Do all the setup for any given configuration option with its filename
sub SetupMagicOption {
  my($option, $filename) = @_;

  $option = lc($option); # Just in case!

  print STDERR "Setting everything up for $option from $filename\n" if $Debug;

  # Set everything up for this configuration option
  $filename{$option} = $filename;
  $modtime{$option}  = (stat($filename))[9];
  $magicwords{$option} = ();
  MailScanner::Log::WarnLog("Reading magic word list for $option failed")
    unless CreateMagicWord($option);
}


# Read and store the magic word list for a given MailScanner.conf option
sub CreateMagicWord {
  my($optionname) = @_;

  my($domain2word, $filename);

  $optionname = lc($optionname); # Make sure upper/lower case is consistent

  # Read in the magic word list for this MailScanner.conf option
  MailScanner::Log::InfoLog("Initialising $optionname");
  $filename = $filename{$optionname};
  $domain2word = ReadWordList($filename);
  print STDERR "domain2word = $domain2word\n" if $Debug;
  return undef unless $domain2word;

  $magicwords{$optionname} = $domain2word;
  $filename{$optionname}   = $filename;

  PrintWordList($optionname) if $Debug;
  return 1; # Success
}

# Print out the contents of an option's magic word table
sub PrintWordList {
  my($option) = @_;

  my($key, $value, $hash);

  print STDERR "\nThe magic word table for $option is:\n";
  $hash = $magicwords{$option};
  while(($key, $value) = each %$hash) {
    print STDERR "$key\t$value\n";
  }
}

# Read the magic word table from a given filename and return a ref to it
sub ReadWordList {
  my($filename) = @_;

  my($handle, %magic, $domain, $magic, $counter);

  $handle = new FileHandle;
  unless ($handle->open("<$filename")) {
    print STDERR "Could not open $filename for reading magic word list\n"
      if $Debug;
    MailScanner::Log::WarnLog("Could not read magic word list $filename");
    return undef;
  }

  %magic = ();
  $counter = 0;
  while(<$handle>) {
    # Handle comments, leading/trailing space, blank lines and other rubbish
    chomp;
    print STDERR "Read \"$_\"\n" if $Debug;
    s/\#.*$//;
    s/^\s+//;
    s/\s+$//;
    next if $_ eq "";
    # Get the interesting bits
    ($domain, $magic) = split(" ", $_, 2);
    $domain = lc($domain);
    $magic  = lc($magic);
    # Check and store it
    print STDERR "Read magic \"$magic\" for domain \"$domain\"\n" if $Debug;
    $magic{"$domain"} = $magic;
    $counter++;
  }

  $handle->close;

  MailScanner::Log::InfoLog("Read $counter magic words from $filename");

  return \%magic;
}

# Check the last mod time of a file and re-read it if it has changed
sub UpdateMagicWords {
  my($option) = @_;

  my($lastmod);

  $option = lc($option);
  ($lastmod) = (stat $filename{$option})[9];
  print STDERR "Last mod date of $option is $lastmod\n" if $Debug;
  if ($lastmod != $modtime{$option}) {
    MailScanner::Log::InfoLog("Noticed update of magic list for $option");
    print STDERR "Update occurred for $option, from $modtime{$option} to $lastmod\n" if $Debug;
    CreateMagicWord($option);
    $modtime{$option} = $lastmod; # Update the stored modification time
    print STDERR "Updated $option\n" if $Debug;
  }
}

# Look up the magic words for a given option and email message
sub LookupMagic {
  my($option, $message) = @_;

  $option = lc($option);

  print STDERR "Looking up $option for message ".$message->{id}."\n" if $Debug;

  # If the magic word table has changed, read it and rebuild the tables
  UpdateMagicWords($option);

  # If there is no message and there is a default magic word then return it
  return $magicwords{$option}{'default'}
    if !$message && exists $magicwords{$option};
  # If there is no message and no default value then we failed the lookup
  return undef unless $message && exists $magicwords{$option};

  # Okay, we now know the relevant data structures exist
  my($todomain, @todomain, $magicword, %magichash, @magiclist);

  # Beware, there is a list of recipients, subject must end with any
  # combination of the magic words
  @todomain = @{$message->{todomain}};

  foreach $todomain (@todomain) {
    print STDERR "Looking up $option for $todomain\n" if $Debug;
    $magicword = "";
    $magicword = $magicwords{$option}{$todomain};
    # Use the default if needed, and if the default has been defined
    $magicword = $magicwords{$option}{'default'} if $magicword eq "";
    next if $magicword eq "";
    # Store it
    $magichash{$magicword} = 1;
    print STDERR "and found magic word \"$magicword\"\n" if $Debug;
  }
  @magiclist = keys %magichash;

  print STDERR "$option for message is " . join(',',@magiclist) . "\n"
    if $Debug;
  return @magiclist;
}

# Does this message end in any of the necessary magic words?
# Return 1 if it does, 0 or undef otherwise.
sub MatchSubject {
  my($message, @magicwords) = @_;

  my($word, @quotedwords);

  # If there are no magic words, must never find them
  return 0 unless @magicwords;

  foreach $word (@magicwords) {
    push @quotedwords, quotemeta($word);
  }

  my $regexp = '(' . join('|',@quotedwords) . ')';
  print STDERR "RegExp = $regexp\n" if $Debug;
  # Must never match an empty regexp
  return undef if $regexp eq '()';

  my $subject = $message->{subject};
  return undef if $subject eq "";

  print STDERR "Checking \"$subject\" against \"$regexp\"\n" if $Debug;
  if ($subject =~ /\s$regexp\s*$/i) {
    print STDERR "Found it!\n" if $Debug;
    MailScanner::Log::InfoLog("Found magic word in Subject: %s in %s",
                              $subject, $message->{id});
    return 1;
  } else {
    print STDERR "Did not find it\n" if $Debug;
    return 0;
  }
}

#
# Now for all the handling of rulesets as well
# We support list of domains which are yes, default yes/no
# and we assume 127.0.0.1 is no
#

sub SetupRecipient {
  my($option, $ruleset) = @_;

  $option = lc($option); # Just in case!

  print STDERR "Setting everything up for ruleset $option from $ruleset\n"
    if $Debug;

  # Set everything up for this configuration option
  $rulesetfilename{$option} = '/dev/null';
  $rulesetfilename{$option} = $ruleset if $ruleset;
  $rulesetmodtime{$option}  = (stat($ruleset))[9];
  $ruleset{$option} = ();
  MailScanner::Log::WarnLog("Reading rulset list for $option failed")
    unless CreateRuleset($option);
}

sub CreateRuleset {
  my($optionname) = @_;

  my($filename, $domain2one);

  $optionname = lc($optionname); # Make sure upper/lower case is consistent

  # Read in the magic word list for this MailScanner.conf option
  MailScanner::Log::InfoLog("Initialising ruleset for $optionname");
  $filename = $rulesetfilename{$optionname};

  # Read the ruleset for this file and option
  $domain2one = ReadRuleset($optionname, $filename);

  print STDERR "domain2one = $domain2one\n" if $Debug;
  return undef unless $domain2one;

  $ruleset{$optionname} = $domain2one;
  $rulesetfilename{$optionname}   = $filename;

  PrintRuleset($optionname) if $Debug;
  return 1; # Success
}

sub PrintRuleset {
  my($option) = @_;

  my($key, $value, $hash);

  print STDERR "\nThe ruleset for $option is:\n";
  $hash = $ruleset{$option};
  while(($key, $value) = each %$hash) {
    print STDERR "$key\t$value\n";
  }
}

sub ReadRuleset {
  my($option, $filename) = @_;

  # Just re-read the ruleset for this option
  #$rulesetfilename{$option} = $filename;
  SetupRuleset($option, $rulesetfilename{$option});

  # The rest of this is now totally redundant
  return 0;

  my($handle, %rules, $to, $domain, $value, $counter);

  $handle = new FileHandle;
  unless ($handle->open("<$filename")) {
    print STDERR "Could not open $filename for reading ruleset list\n"
      if $Debug;
    MailScanner::Log::WarnLog("Could not read ruleset list $filename");
    return undef;
  }

  %rules = ();
  $counter = 0;
  while(<$handle>) {
    # Handle comments, leading/trailing space, blank lines and other rubbish
    chomp;
    print STDERR "Read \"$_\"\n" if $Debug;
    s/\#.*$//;
    s/^\s+//;
    s/\s+$//;
    next if $_ eq "";
    # Get the interesting bits
    ($to, $domain, $value) = split(" ", $_, 3);
    $domain = lc($domain);
    $value  = lc($value);
    # Check and store it
    $domain =~ s/^.*\@//;
    $value  = ($value =~ /y/i)?1:0;
    print STDERR "Read value \"$value\" for domain \"$domain\"\n" if $Debug;
    $rules{"$domain"} = $value;
    $counter++;
  }

  $handle->close;

  MailScanner::Log::InfoLog("Read $counter rules from $filename");

  return \%rules;
}

# Check the last mod time of a file and re-read it if it has changed
sub UpdateRulesets {
  my($option) = @_;

  my($lastmod);

  $option = lc($option);
  ($lastmod) = (stat $rulesetfilename{$option})[9];
  print STDERR "Last mod date of ruleset for $option is $lastmod\n" if $Debug;
  if ($lastmod != $rulesetmodtime{$option}) {
    MailScanner::Log::InfoLog("Noticed update of ruleset for $option");
    print STDERR "Update occurred for ruleset $option, from " .
                 $rulesetmodtime{$option} . " to $lastmod\n" if $Debug;
    CreateRuleset($option);
    $rulesetmodtime{$option} = $lastmod; # Update the stored modification time
    print STDERR "Updated ruleset for $option\n" if $Debug;
  }
}

# Lookup the ruleset for a given message and option name
sub LookupRuleset {
  my($option, $message) = @_;
  
  $option = lc($option);

  print STDERR "Looking up ruleset $option for message " .
               $message->{id} . "\n" if $Debug;

  # If the ruleset has changed, read it and rebuild the tables
  UpdateRulesets($option);

  # All the rulesets have 127.0.0.1 --> 0
  return 1 unless $message;
  return 0 if $message->{clientip} =~ /^127\.0\.0/;

  # Just evaluate the ruleset
  my $E2I = MailScanner::Config::GetEtoI();
  # Get the old Custom Function name and delete it
  my $funcname = MailScanner::Config::GetCustomFunction($E2I->{$option});
  MailScanner::Config::SetCustomFunction($E2I->{$option}, undef);
  #print STDERR "About to lookup ruleset for $option (" . $E2I->{$option} . ")\n";
  my $rulesetresult = MailScanner::Config::Value($E2I->{$option}, $message);
  #print STDERR "The ruleset for $option (" . $E2I->{$option} . ") said $rulesetresult\n";
  # Restore the old Custom Function name
  MailScanner::Config::SetCustomFunction($E2I->{$option}, $funcname);
  return $rulesetresult;

  ###############################
  # The rest of this is redundant
  ###############################

  # Return the default value is there is no message
  return $ruleset{$option}{'default'}
    if !$message && exists $ruleset{$option};
  # If there is no message and no default value then we failed the lookup
  return undef unless $message && exists $ruleset{$option};

  # Okay, we now know the relevant data structures exist
  my($foundit, $result, $todomain, @todomain);

  # Beware, there is a list of recipients, any domain must say yes
  @todomain = @{$message->{todomain}};

  $result = 0;
  $foundit = 0;
  foreach $todomain (@todomain) {
    print STDERR "Looking up ruleset $option for $todomain\n" if $Debug;
    if (exists($ruleset{$option}{$todomain})) {
      $foundit = 1;
      $result = 1 if $ruleset{$option}{$todomain};
      print STDERR "Found a match, result = $result\n" if $Debug;
    }
  }

  # If we found a result, then return it
  print STDERR "Returning match \"$result\" as we found one\n"
    if $foundit && $Debug;
  return $result if $foundit;

  # We didn't find a result, so return the default
  $result = undef;
  $result = $ruleset{$option}{'default'};
  $result = 0 unless defined $result;
  print STDERR "No match found, returning \"$result\"\n" if $Debug;
  return $result;
}


############################################################################
############################################################################
############################################################################

#
#
# You need the following 3 functions for each MailScanner.conf configuration
# option which is getting the LastSpam.com treatment.
#
# The only bit you need to change is the value for "$option" in each function
# which should be the external name of the config option.
# The external name is the name that appears in MailScanner.conf but with
# nothing except a-z and 0-9, all lower-case.
#
#

############################################################################
#
# Virus Scanning =
#
sub InitLastSpamVirusScanning {
  my($filename, $ruleset) = @_;

  my $option = 'virusscanning';

  SetupMagicOption($option, $filename);
  SetupRecipient($option, $ruleset);
}

sub LastSpamVirusScanning {
  my($message) = @_;

  my $option = 'virusscanning';

  unless ($ReadConfDone{$option}) {
    SetupRuleset($option);
    $ReadConfDone{$option} = 1;
  }

  return 0 if MatchSubject($message, LookupMagic($option, $message));
  return LookupRuleset($option, $message);
}

sub EndLastSpamVirusScanning {

  my $option = 'virusscanning';

  MailScanner::Log::InfoLog("Shutting down LastSpam $option");
}

############################################################################
#
# Dangerous Content Checks =
#
sub InitLastSpamDangerousContent {
  my($filename, $ruleset) = @_;

  my $option = 'dangerouscontentscanning';

  SetupMagicOption($option, $filename);
  SetupRecipient($option, $ruleset);
}

sub LastSpamDangerousContent {
  my($message) = @_;

  my $option = 'dangerouscontentscanning';

  unless ($ReadConfDone{$option}) {
    SetupRuleset($option);
    $ReadConfDone{$option} = 1;
  }

  return 0 if MatchSubject($message, LookupMagic($option, $message));
  return LookupRuleset($option, $message);
}

sub EndLastSpamDangerousContent {

  my $option = 'dangerouscontentscanning';

  MailScanner::Log::InfoLog("Shutting down LastSpam $option");
}

############################################################################
#
# Spam Checks =
#
sub InitLastSpamSpamChecks {
  my($filename, $ruleset) = @_;

  my $option = 'spamchecks';

  SetupMagicOption($option, $filename);
  SetupRecipient($option, $ruleset);
}

sub LastSpamSpamChecks {
  my($message) = @_;

  my $option = 'spamchecks';

  unless ($ReadConfDone{$option}) {
    SetupRuleset($option);
    $ReadConfDone{$option} = 1;
  }

  return 0 if MatchSubject($message, LookupMagic($option, $message));
  return LookupRuleset($option, $message);
}

sub EndLastSpamSpamChecks {

  my $option = 'spamchecks';

  MailScanner::Log::InfoLog("Shutting down LastSpam $option");
}

#=======================================================================
#
# Create and read the MailScanner.conf file for this command-line option
#

sub SetupRuleset {
  my($opkeyword) = @_;

  # my $fh = new FileHandle;
  # $fh->open("> $tmpfilename") or die "$!";
  my($fh, $tmpfilename) = tempfile("MailScanner.LastSpam.XXXXXX", TMPDIR => 1, UNLINK => 0);
  my $rf = $rulesetfilename{$opkeyword};
  #print STDERR "RF = $rf\n";
  #print STDERR $opkeyword . " = $rf\n";
  print $fh $opkeyword . " = $rf\n";
  $fh->close;

  MailScanner::Config::SetFileValue($opkeyword, undef);
  # Must ensure the ruleset for this option is empty before we start reading
  MailScanner::Config::ReadData($tmpfilename);
  unlink $tmpfilename;
}


# This file must end with the following line
no strict;
1;

