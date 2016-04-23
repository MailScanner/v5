#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: Config.pm 5071 2010-11-25 15:12:04Z sysjkf $
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

package MailScanner::Config;

use Net::CIDR;
use Socket;
use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5071 $, 10;

# Load modules needed for methods/functions within this package
require FileHandle;
require MailScanner::ConfigSQL;

#1 exception to general rule of forming replies to Config::Value()
#is %Config::ScannerCmds
#This maps the virus scanner name to the command used to execute it
#and is all defined in 1 config file (virus.scanners.conf).

# Needs to provide method called Value which takes
# Value(<variablename> [, <msg-list>])
# and returns the value for this case
#
# Simple variables won't need a <msg-list>.

# Locking definitions for flock() which is used to lock the config files
my($LOCK_SH) = 1;
my($LOCK_EX) = 2;
my($LOCK_NB) = 4;
my($LOCK_UN) = 8;

# This is global within this package to save passing them all over the place
my(%File, %LineNos, %ItoE, %EtoI);
my(%StaticScalars, %ScannerCmds, %SpamLists);
my(%KeywordCategory, %KeywordType);
my(%NFilenameRules, %NFiletypeRules);
my(%AFilenameRules, %AFiletypeRules);
my(%LanguageStrings, %YesNoItoE, %YesNoEtoI, %HardCodedDefaults);
my(%RuleScalars, %Defaults, $DefaultAddressRegexp, $DefaultVirusRegexp);
my(%CustomFunctions, %CustomFunctionsParams);
my(%PercentVars); # For putting substituted variables in all settings
my($RequireLDAPDone);
use vars qw(%PhishingWhitelist); # Whitelist of hostnames for Phishing Net
use vars qw(%PhishingBlacklist); # Blacklist of hostnames for Phishing Net
use vars qw($LDAP $LDAPserver $LDAPbase $LDAPsite); # LDAP connection info

$RequireLDAPDone = 0; # Have we done the "require Net::LDAP"?

%KeywordCategory = (); # These store the type of rule for every keyword

%StaticScalars = (); # Need to work out defaults for sendmail2 somewhere!

%RuleScalars = (); # These are the ones created from rulesets

%CustomFunctions = (); # These are names of user-written functions
%CustomFunctionsParams = (); # and their parameters passed to Init and End

# This is what the RuleToRegexp function produces when given
# either "*@*" or "default".
$DefaultAddressRegexp = '^.*\@.*\.?$';
$DefaultVirusRegexp = '.*';

# Need to read in a filename/ruleset whose value is the location of
# filename.rules.conf files. Check every rule of every ruleset in
# turn, stopping with the result of the first rule that matches.
# If nothing matches, then allow the filename.

# 3 little accessor functions for reading package-local variables from
# inside Custom Functions, so you can make a configuration option act
# as a Function and a Ruleset at the same time :-)
sub GetFileValue {
  my($name) = @_;
  return $File{$name};
}
sub SetFileValue {
  my($name, $value) = @_;
  if (defined $value) {
    $File{$name} = $value;
  } else {
    delete $File{$name};
  }
}
sub GetItoE {
  return \%ItoE;
}
sub GetEtoI {
  return \%EtoI;
}
sub SetCustomFunction {
  my($func, $value) = @_;
  if (defined $value) {
    $CustomFunctions{$func} = $value;
  } else {
    delete $CustomFunctions{$func};
  }
}
sub GetCustomFunction {
  my($func) = @_;
  return $CustomFunctions{$func};
}

# Tiny little accessor function to force a configuration variable to be a
# value. The opposite of Value(). Useful in MailScanner --lint.
sub SetValue {
  my($name, $value) = @_;
  $StaticScalars{$name} = $value;
}

#
# Given a keyword name (in lowercase) and optionally a message,
# work out the value of the keyword.
# It is designed to produce a result very fast when there is no ruleset,
# as most people will only use rulesets in a couple of places.
#
sub Value {
  my($name, $msg) = @_;
  my($funcname, $result);

  #$name = lc($name);

  # Debug output
  #print STDERR "Looking up config value $name => " .
  #             $StaticScalars{$name} . "\n"
  #  if $name eq 'spamwhitelist'; #$StaticScalars{$name};

  #print STDERR "*** 1 $name\n" if $name eq 'spamwhitelist';

  # Make this as fast as possible in simple situations
  return $StaticScalars{$name} if exists $StaticScalars{$name};

  # User custom-written functions are easy to spot too
  $funcname = $CustomFunctions{$name};
  if ($funcname) {
    my $param = "";
    $funcname = 'MailScanner::CustomConfig::' . $funcname;
    no strict 'refs';
    if ($param = $CustomFunctionsParams{$name}) {
      $param =~ s/^\(//; # Trim the brackets
      $param =~ s/\)$//;
      $param =~ s/\"//g; # and quotes
      my @params = split(/,/, $param);
      $result = &$funcname($msg, \@params); # Call with a ref-->list of params
    } else {
      $result = &$funcname($msg);
    }
    use strict 'refs';
    #print STDERR "It was a CF\n" if $name eq 'spamwhitelist';
    return $result;
  }

  #print STDERR "*** 2 $name\n" if $name eq 'languagestrings';

  #
  # Must be a check against a ruleset
  #

  # If it's a ruleset, and they didn't supply a message to test against,
  # then the only thing we can do is return the default value.
  return $Defaults{$name} unless $msg;

  #
  # They have supplied a message, so check all its addresses against the rules
  #

  #print STDERR "*** 3 $name\n" if $name eq 'spamwhitelist';

  my($category, $rulelist, $rule);
  my($direction, $iporaddr, $regexp2, $value);
  my(@addresses);

  $category = $KeywordCategory{$name};
  $rulelist = $RuleScalars{$name};

  #print STDERR "Evaluating ruleset for $name\n";

  # They might want the behaviour that when there are multiple recipients
  # in the same domain, only the rule that matches *@domain.com (the
  # literal character "*") is used. When there are multiple recipients
  # in different domains, only the rule that matches *@* is used. If no
  # specific rule for \*@\* is specified, then naturally the default value
  # is used, as that would match *@* anyway.
  # The switch that controls this behaviour is a "simple" switch, so as
  # not to make this function too recursive and for speed.
  my $tooverride;
  $tooverride = undef;
  #print STDERR "*** 4 $name\n" if $name eq 'spamwhitelist';

  if ($StaticScalars{'usedefaultswithmanyrecips'}) {
    my(%recipdomains, $recip);

    # This only applies with multiple recipients
    if (scalar(@{$msg->{to}}) > 1) {
      # Get a list of all the domains into keys(%recipdomains)
      foreach $recip (@{$msg->{to}}) {
        $recipdomains{lc($1)} = 1 if $recip =~ m/\@(.*)$/;
      }
      if (scalar(%recipdomains) =~ /^1\//) {
        # There was just 1 domain, so use *@domain.com
        my $domain = (keys %recipdomains)[0];
        # Protect domain name against evil SMTP clients
        $domain =~ s/\s//g;
        $tooverride = '*@' . $domain;
      } else {
        # There were many domains, so look up *@* which would *normally*
        # be the default value
        $tooverride = '*@*';
      }
    }
  }

  #print STDERR "*** 5 $name\n" if $name eq 'languagestrings';

    #return '/usr/share/MailScanner/reports/cz/languages.conf' if $name eq 'languagestrings';
  my($directiona, $iporaddra, $regexp2a, $valuea, @results);
  if ($category =~ /first/i) {

  #  print STDERR "*** 6 First $name\n" if $name eq 'spamwhitelist';

    #
    # It's a first-match rule
    #

    #print STDERR "$name first-match rule\n";

    # If there is no ruleset either, then return the default
    #print STDERR "There are rules for languagestrings\n" if $name eq 'languagestrings';
    #return '/usr/share/MailScanner/reports/cz/languages.conf' if $name eq 'languagestrings';
    return $Defaults{$name} unless $RuleScalars{$name};

    foreach $rule (@{$rulelist}) {
      ($direction, $iporaddr, $regexp2, $value) = split(/\0/, $rule, 4);
      if ($value =~ /\0/) {
        # The value is actually another "and" condition
        # Let's only allow 1 "and" at the moment
        ($directiona, $iporaddra, $regexp2a, $valuea) = split(/\0/, $value);
        # Do first condition and bail out if it failed
        $result = FirstMatchValue($direction, $iporaddr, $regexp2, $valuea,
                                  $name, $msg, $tooverride);
        #print STDERR "1st half result is $result\n";
        next if $result eq "CoNfIgFoUnDnOtHiNg";
        # Condition matched, so do 2nd half
        $result = FirstMatchValue($directiona, $iporaddra, $regexp2a,
                                  $valuea, $name, $msg, $tooverride);
        #print STDERR "2nd half result is $result\n";
        return $result unless $result eq "CoNfIgFoUnDnOtHiNg";
      } else {
        # It's a simple rule with no "and" in it
        #print STDERR "Matching against $direction $iporaddr /$regexp/\n";
        $result = FirstMatchValue($direction, $iporaddr, $regexp2, $value,
                                  $name, $msg, $tooverride);
        return $result unless $result eq "CoNfIgFoUnDnOtHiNg";
      }
    }
    # No rule matched, so return the default
    #print STDERR "Returning default as nothing matched.\n";
    return $Defaults{$name};

  } else {

    #
    # It's an all-matches rule
    #

    #print STDERR "all-match rule\n" if $name eq 'spamwhitelist';

    # If there is no ruleset either, then return the default
    #print STDERR "RuleScalars = " . $RuleScalars{$name} . "\n";
    #print STDERR "Default is " . $Defaults{$name} . "\n\n";
    return $Defaults{$name} unless $RuleScalars{$name};

    foreach $rule (@{$rulelist}) {
      ($direction, $iporaddr, $regexp2, $value) = split(/\0/, $rule, 4);
      if ($value =~ /\0/) {
        # The value is actually another "and" condition
        # Let's only allow 1 "and" at the moment
        ($directiona, $iporaddra, $regexp2a, $valuea) = split(/\0/, $value);
        # Do first condition and bail out if it failed
        $result = AllMatchesValue($direction, $iporaddr, $regexp2, $valuea,
                                  $name, $msg, $tooverride);
        next if $result eq "CoNfIgFoUnDnOtHiNg";
        # Condition matched, so do 2nd half
        $result = AllMatchesValue($directiona, $iporaddra, $regexp2a, $valuea,
                                  $name, $msg, $tooverride);
        next if $result eq "CoNfIgFoUnDnOtHiNg";
        push @results, $result;
      } else {
        # It's a simple rule with no "and" in it
        #print STDERR "Matching against $direction $iporaddr /$regexp/\n";
        $result = AllMatchesValue($direction, $iporaddr, $regexp2, $value,
                                  $name, $msg, $tooverride);
        next if $result eq "CoNfIgFoUnDnOtHiNg";
        push @results, $result;
      }
    }
    # Return the results if there were any, else the defaults
    return join(" ", @results) if @results;
    return $Defaults{$name};
  }
}

# Get the SMTP client hostname from the $msg->{clientip}.
# Do some spoof checking here for good measure.
# spoofcheck = h ==> do anti-spoof checking.
# spoofcheck = H ==> do no anti-spoof checking.
sub GetClientHostname {
  my($msg, $spoofcheck) = @_;

  my($fromname, $claimed_hostname);

  if ($spoofcheck eq 'h') {
    # Have we cached the checked hostname?
    $fromname = $msg->{clienthostname};
    return $fromname if defined $fromname;
  } else {
    # Have we cached the unchecked hostname?
    $fromname = $msg->{clienthostnamenocheck};
    return $fromname if defined $fromname;
  }

  # Do forward and reverse DNS check to protect against spoofing
  $claimed_hostname = gethostbyaddr(inet_aton($msg->{clientip}), AF_INET);

  # They may not want the anti-spoof protection!
  if ($spoofcheck eq 'H') {
    $fromname = defined($claimed_hostname)?$claimed_hostname:"";
    $msg->{clienthostnamenocheck} = $fromname;
    return $fromname;
  }

  # From now on we are doing the version with spoof-checking

  # If there is a hostname (PTR record) then check it matches the A record
  if ($claimed_hostname) {
    my @name_lookup = gethostbyname($claimed_hostname);
    #                    or die "Could not reverse $claimed_hostname: $!\n";
    if (@name_lookup) {
      my @resolved_ips = map { inet_ntoa($_) } @name_lookup[4..$#name_lookup];
      my $might_spoof = !grep { $msg->{clientip} eq $_ } @resolved_ips;
      $fromname = $might_spoof?"_SPOOFED_":lc($claimed_hostname);
    } else {
      $fromname = "";
    }
  } else {
    $fromname = "";
  }
  $msg->{clienthostname} = $fromname; # Ensure cache is defined
  return $fromname;
}

sub FirstMatchValue {
  my($direction, $iporaddr, $regexp2, $value, $name, $msg, $tooverride) = @_;

  #print STDERR "Params are: $direction, $iporaddr, $regexp2, $value, $name, $msg, $tooverride\n";
  my($regexp, $misses, $to);

  # Pre-compile $regexp2 and include case-insensitivity flag
  $regexp = qr/$regexp2/i;

  if ($iporaddr eq 't') {
    # It is a virus name matching rule.
    if ($direction =~ /v/) {
      # Look through the reports and match substrings.
      # This is for first-matching rules only.
      # Don't return anything unless we find a match.
      my($file, $text);
      while(($file, $text) = each %{$msg->{allreports}}) {
        return $value if $text =~ /$regexp/;
      }
    } elsif ($direction =~ /b/) {
      # It's a text address-based rule
      # Match against all the To addresses and the From address
      $misses = 0;
      $misses++ unless $msg->{from} =~ /$regexp/;
      if (defined $tooverride) {
        $misses++ unless $tooverride =~ /$regexp/;
      } else {
        foreach $to (@{$msg->{to}}) {
          $misses++,last unless $to =~ /$regexp/;
        }
      }

      return $value if $misses == 0;
    } else {
      # Match against any of From and/or To addresses
      if ($direction =~ /f/) {
        # Match against the From address
        #print STDERR "From " . $msg->{from} . " against $regexp\n";
        return $value if $msg->{from} =~ /$regexp/;
        #print STDERR "Miss\n";
      }
      if ($direction =~ /t/) {
        # Match against every To address
        if (defined $tooverride) {
          return $value if $tooverride =~ /$regexp/;
        } else {
          foreach $to (@{$msg->{to}}) {
            #print STDERR "To " . $to . " against $regexp\n";
            #print STDERR "Resulting value would be $value\n";
            return $value if $to =~ /$regexp/;
            #print STDERR "Miss\n";
          }
        }
      }
    }
  } elsif ($iporaddr eq 'd') {
    #
    # It is an all-digits rule
    #
    # It is a virus name matching rule.
    if ($direction =~ /v/) {
      # Look through the reports and match substrings.
      # This is for first-matching rules only.
      # Don't return anything unless we find a match.
      my($file, $text);
      while(($file, $text) = each %{$msg->{allreports}}) {
        return $value if $text =~ /$regexp/;
      }
    } elsif ($direction =~ /f/) {
      # It's a numeric ip-number-based rule
      # Can only check these with From:, not To: addresses
      # Match against the SMTP Client IP address
      #print STDERR "Matching IP " . $msg->{clientip} . " against $regexp\n";
      if ($regexp =~ /\d+\\\.\d+\\\.\d+\\\.\d+\)*$/) {
        # It's a complete IPv4 address so it's a total string match, not a re
        #print STDERR "Got a match\n";
        return $value if $msg->{clientip} =~ /^$regexp$/;
      } else {
        # It's not a complete IPv4 address so substring match it
        #print STDERR "Got no match\n";
        return $value if $msg->{clientip} =~ /$regexp/;
      }
    }
    if ($direction =~ /[tb]/) {
      # Don't know the target IP address
      MailScanner::Log::WarnLog("Config Error: Cannot match against " .
        "destination IP address when resolving configuration option " .
        " \"%s\"", $name);
    }
  } elsif ($iporaddr eq 'h' || $iporaddr eq 'H') {
    # 'h' ==> hostname, 'H' ==> hostname without spoof protection
    # It's a hostname or domain name
    if ($direction =~ /v/) {
      MailScanner::Log::WarnLog("Config Error: Given a virus name match ".
        "with a hostname or domain name \"%s\"", $name);
      return "CoNfIgFoUnDnOtHiNg"; # Caller will work out the default value now
    }
    if ($direction =~ /[tb]/) {
      # Don't know the target IP address
      MailScanner::Log::WarnLog("Config Error: Cannot match against " .
        "destination hostname or domain name when resolving configuration " .
        "option \"%s\"", $name);
      return "CoNfIgFoUnDnOtHiNg"; # Caller will work out the default value now
    }
    # It's a hostname or domain name and it's a "From:" match on {clientip}.
    # Convert $msg->{clientip} into a hostname
    #print STDERR "Clientip = " . $msg->{clientip} . " and hostname = ";
    my $fromname = GetClientHostname($msg, $iporaddr);
    $fromname = '.' . $fromname if $fromname && $fromname ne "_SPOOFED_";
    #print STDERR $fromname . "\n";
    #print STDERR "Fromname = \"$fromname\" and regexp = \"$regexp\"\n";
    #print STDERR "Matched!\n" if $fromname =~ /$regexp/; # Initial test in case from=''
    return $value if $fromname =~ /$regexp/; # Initial test in case from=''
    #print STDERR "Initial test didn't match\n";
    while ($fromname ne '' && $fromname ne '_SPOOFED_') {
      #print STDERR "Testing $fromname against $regexp\n";
      #print STDERR "Matches!\n" if $fromname =~ /$regexp/i;
      return $value if $fromname =~ /$regexp/i;
      $fromname =~ s/^\.[^.]+//; # Knock off next word, could be last
      #$fromname = substr $fromname, 1; # And the . separator
    }
    #while ($fromname ne '') {
    #  print STDERR "Testing $fromname against $regexp\n";
    #  print STDERR "Matches!\n" if $fromname =~ /$regexp/i;
    #  return $value if $fromname =~ /$regexp/i;
    #  $fromname =~ s/^[^.]+(.*)$/$1/; # Knock off next word, could be last
    #  $fromname = substr $fromname, 1; # And the . separator
    #}
    #print STDERR "Found nothing matches $regexp\n";
    return "CoNfIgFoUnDnOtHiNg";
  } else {
    #
    # It is a CIDR (network/netmask) rule
    #
    # It is a virus name matching rule.
    if ($direction =~ /v/) {
      # Look through the reports and match substrings.
      # This is for first-matching rules only.
      # Don't return anything unless we find a match.
      my($file, $text);
      while(($file, $text) = each %{$msg->{allreports}}) {
        return $value if $text =~ /$regexp/;
      }
    } elsif ($direction =~ /f/) {
      # Can only check these with From:, not To: addresses
      # Match against the SMTP Client IP address
      my(@cidr) = split(',', $regexp2);
      #print STDERR "Matching IP " . $msg->{clientip} .
      #             " against " . join(',',@cidr) . "\n";
      return $value if Net::CIDR::cidrlookup($msg->{clientip}, @cidr);
    }
    if ($direction =~ /[tb]/) {
      # Don't know the target IP address
      MailScanner::Log::WarnLog("Config Error: Cannot match against " .
        "destination IP address when resolving configuration option " .
        " \"%s\"", $name);
    }
  }

  # Nothing matched, so return the default value
  #print STDERR "Nothing matched, so returning default value: " .
  #             $Defaults{$name} . "\n";
  #return $Defaults{$name};
  return "CoNfIgFoUnDnOtHiNg"; # Caller will work out the default value now
}


sub AllMatchesValue {
  my($direction, $iporaddr, $regexp2, $value, $name, $msg, $tooverride) = @_;

  my($regexp, $misses, $to, @matches);

  # Pre-compile $regexp2 and include case-insensitivity flag
  $regexp = qr/$regexp2/i;

  if ($iporaddr eq 't') {
    # We may be over-riding the "to" addresses we are looking up with
    # an over-riding address if there are multiple recipients.

    if ($direction =~ /v/) {
      # It is a virus name matching rule.
      # Look through the reports and match substrings.
      # This is for first-matching rules only.
      # Don't return anything unless we find a match.
      my($file, $text);
      #print STDERR "Value eq $value\n";
      #print STDERR "Regexp = $regexp\n";
      #print STDERR "Matches keys = " . join(" ",@matches) . "\n";
      while(($file, $text) = each %{$msg->{allreports}}) {
      #print STDERR "File is $file and text is $text\n";
        push @matches, split(" ",$value) if $text =~ /$regexp/;
      }
    } elsif ($direction =~ /b/) {
      # It's a text address-based rule
      # Match against the From and every To
      $misses = 0;
      $misses++ unless $msg->{from} =~ /$regexp/;
      if (defined $tooverride) {
        $misses++ unless $tooverride =~ /$regexp/;
      } else {
        foreach $to (@{$msg->{to}}) {
          $misses++,last unless $to =~ /$regexp/;
        }
      }
      push @matches, split(" ",$value) if $misses == 0;
    } else {
      if ($direction =~ /f/) {
        # Match against the From address
        push @matches, split(" ",$value) if $msg->{from} =~ /$regexp/;
      }
      if ($direction =~ /t/) {
        # Match against every To address
        if (defined $tooverride) {
          push @matches, split(" ",$value) if $tooverride =~ /$regexp/;
        } else {
          foreach $to (@{$msg->{to}}) {
            push @matches, split(" ",$value) if $to =~ /$regexp/;
          }
        }
      }
    }
  } elsif ($iporaddr eq 'd') {
    if ($direction eq 'v') {
      # It is a virus name matching rule.
      # Look through the reports and match substrings.
      # This is for first-matching rules only.
      # Don't return anything unless we find a match.
      my($file, $text);
      while(($file, $text) = each %{$msg->{allreports}}) {
        push @matches, split(" ",$value) if $text =~ /$regexp/;
      }
    } elsif ($direction eq 'f') {
      # It's a numeric ip-number-based rule
      # Can only check these with From:, not To: addresses
      # Match against the SMTP Client IP address
      if ($regexp =~ /\d+\\\.\d+\\\.\d+\\\.\d+\)*$/) {
        # It's a complete IPv4 address so it's a total string match, not a re
        push @matches, split(" ",$value) if $msg->{clientip} =~ /^$regexp$/;
      } else {
        # It's not a complete IPv4 address so substring match it
        push @matches, split(" ",$value) if $msg->{clientip} =~ /$regexp/;
      }
    } else {
      # Don't know the target IP address
      MailScanner::Log::WarnLog("Cannot match against destination " .
        "IP address when resolving configuration option \"%s\"", $name);
    }
  } elsif ($iporaddr eq 'h' || $iporaddr eq 'H') {
    # It's a hostname or domain name
    if ($direction =~ /v/) {
      MailScanner::Log::WarnLog("Config Error: Given a virus name match ".
        "with a hostname or domain name \"%s\"", $name);
    } elsif ($direction =~ /[tb]/) {
      # Don't know the target IP address
      MailScanner::Log::WarnLog("Config Error: Cannot match against " .
        "destination hostname or domain name when resolving configuration " .
        "option \"%s\"", $name);
    } else {
      # It's a hostname or domain name and it's a "From:" match on {clientip}.
      # Convert $msg->{clientip} into a hostname
      #print STDERR "Clientip = " . $msg->{clientip} . " and hostname = ";
      my $fromname = GetClientHostname($msg, $iporaddr);
      $fromname = '.' . $fromname if $fromname && $fromname ne "_SPOOFED_";
      #print STDERR $fromname . "\n";
      #my $fromname = $msg->{clienthostname};
      #if (!defined $fromname) {
      #  $fromname = gethostbyaddr(inet_aton($msg->{clientip}), AF_INET);
      #  $msg->{clienthostname} = $fromname || ""; # Ensure cache is defined
      #}
      #print STDERR $fromname . "\n";
      #print STDERR "Fromname = \"$fromname\" and regexp = \"$regexp\"\n";
      #print STDERR "Matched!\n" if $fromname =~ /$regexp/i; # Initial test in case from=''
      # Initial test in case from=''
      if ($fromname =~ /$regexp/) {
        push @matches, split(" ",$value);
        #print STDERR "Initial test matched\n";
      } else {
        while ($fromname ne '' && $fromname ne '_SPOOFED_') {
          #print STDERR "Testing $fromname against $regexp\n";
          #print STDERR "Matches!\n" if $fromname =~ /$regexp/i;
          push @matches, split(" ",$value) if $fromname =~ /$regexp/i;
          $fromname =~ s/^\.[^.]+//; # Knock off next word, could be last
        }
      }
      #print STDERR "Found nothing matches $regexp\n";
    }
  } else {
    #
    # It is a CIDR (network/netmask) rule
    #
    if ($direction eq 'v') {
      # It is a virus name matching rule.
      # Look through the reports and match substrings.
      # This is for first-matching rules only.
      # Don't return anything unless we find a match.
      my($file, $text);
      while(($file, $text) = each %{$msg->{allreports}}) {
        push @matches, split(" ",$value) if $text =~ /$regexp/;
      }
    } elsif ($direction =~ /f/) {
      # Can only check these with From:, not To: addresses
      # Match against the SMTP Client IP address
      my(@cidr) = split(',', $regexp2);
      #print STDERR "Matching IP " . $msg->{clientip} .
      #             " against " . join(',',@cidr) . "\n";
      push @matches, split(" ",$value)
        if Net::CIDR::cidrlookup($msg->{clientip}, @cidr);
    }
    if ($direction =~ /[tb]/) {
      # Don't know the target IP address
      MailScanner::Log::WarnLog("Config Error: Cannot match against " .
        "destination IP address when resolving configuration option " .
        " \"%s\"", $name);
    }

  }

  # Return the concatenation of all the matching rules
  my($results);
  $results = join(" ", @matches);
  #print STDERR "Result is \"$results\"\n";
  return $results if @matches; # JKF $results ne "";
  # Nothing matched, so return the default value
  #print STDERR "Nothing matched, so returning default\n";
  #return $Defaults{$name};
  return "CoNfIgFoUnDnOtHiNg";
}


#
# Is this value just a simple yes/no value, or is it pointing to a ruleset?
#
sub IsSimpleValue {
  my($name) = @_;

  return 1 if exists $StaticScalars{$name};
  return 0;
}

#
# Substitute Percent Variables into a line of text
#
sub DoPercentVars {
  my($string) = @_;
  $string =~ s/\%([^%\s]+)\%/$PercentVars{lc($1)}/g;
  $string =~ s/\\n/\n/g;
  $string;
}

#
# Read all the CustomConfig.pm files in the Custom Config Dir
#
sub initialise {
  my($dir) = @_;

  my($dirh,$filename,$fullfile);

  $dirh = new DirHandle;
  unless ($dirh->open($dir)) {
    MailScanner::Log::WarnLog("Could not read Custom Functions directory %s",
                              $dir);
    return;
  }

  while(defined($filename = $dirh->read)) {
    # Only process files ending with .pm or .pl
    # Skip all dot files and rpmnew files
    next if $filename =~ /^\./ || $filename =~ /\.(rpmnew|dpkg-dist|dpkg-new|dpkg-old)$/i;
    unless ($filename =~ /\.p[lm]$/i) {
      MailScanner::Log::NoticeLog("Skipping Custom Function file %s as its name does not end in .pm or .pl", $filename);
      next;
    }
    $fullfile = "$dir/$filename";
    $fullfile =~ /^(.*)$/; # Simple untaint
    $fullfile = $1;
    next unless -f $fullfile and -s $fullfile;
    eval { require $fullfile; };
    if ($@) {
      MailScanner::Log::WarnLog("Could not use Custom Function code %s, " .
                                "it could not be \"require\"d. Make sure " .
                                "the last line is \"1;\" and the module " .
                                "is correct with perl -wc (Error: %s)",
                                $fullfile, $@);
    } # else {
      # MailScanner::Log::InfoLog("Using Custom Function file %s", $fullfile);
      # }
  }
}


#
# Set one of the %percentvars%.
#
sub SetPercent {
  my($percent, $value) = @_;
  $PercentVars{$percent} = $value;
}

#
# Hack quickly through the config file looking for a keyword.
# Cannot use MailScanner::Log here at all, as it hasn't started yet.
#
my %QPConfFilesSeen = ();
sub QuickPeek {
  my($filename, $target, $notifldap) = @_;
  %QPConfFilesSeen = ();
  return QuickPeek2($filename, $target, $notifldap);
}

# This is the one that actually does the work now!
sub QuickPeek2 {
  my($filename, $target, $notifldap) = @_;

  my($fh, $key, $value, $targetfound, $targetvalue, $savedline);
  my($ldapserver, $ldapsite, $ldapbase);

  $target = lc($target);
  my($dbtarget) = $target;
  $target =~ s/[^%a-z0-9]//g; # Leave % vars intact

  $fh = new FileHandle;
  $fh->open("<$filename") or die "Cannot open config file $filename, $!";
  flock($fh, $LOCK_SH);

  while(<$fh>) {
    chomp;
    s/#.*$//;
    s/^\s*//g;
    s/\s*$//g;
    next if /^$/;
    $savedline = $_;

    # Implement "include" files
    if ($savedline =~ /^include\s+([^=]*)$/i) {
      my $wildcard = $1;
      my @newfiles = map { m/(.*)/ } glob($wildcard);
      if (@newfiles) {
        # Go through each of the @newfiles reading conf from them.
        for my $newfile (sort @newfiles) {
          # Have we seen it before?
          #print STDERR "Checking $newfile\n";
          unless ($QPConfFilesSeen{$newfile}) {
            # No, so read it.
            my $ret = QuickPeek2($newfile, $target, $notifldap);
            if (defined $ret) {
              $targetfound = 1;
              $targetvalue = $ret;
            }
          }
        }
      }
      # And don't do any more processing on the "include" line.
      next;
    }

    $_ = $savedline;
    $key = undef;   # Don't carry over values from previous iteration
    $value = undef;
    /^(.*?)\s*=\s*(.*)$/;
    ($key,$value) = ($1,$2);

    # Allow %var% = value lines with $VAR in value
    $value =~ s/\%([^%]+)\%/$PercentVars{lc($1)}/g;
    $value =~ s/\$\{?(\w+)\}?/$ENV{$1}/g;
    $value =~ s/\\n/\n/g;
    if ($key =~ /^\%([^%]+)\%$/) {
      # 20090826 Always use the most recent value of %variable%
      #$PercentVars{lc($1)} = $value unless exists $PercentVars{lc($1)};
      $PercentVars{lc($1)} = $value;
      #next; -- Store the percentvars in the key{value} hash as well.
    }

    $key = lc($key);
    $key =~ s/[^%a-z0-9]//g; # Leave numbers and letters only -- leave % vars
    $ldapserver = $value if $key =~ /ldapserver/i;
    $ldapsite   = $value if $key =~ /ldapsite/i;
    $ldapbase   = $value if $key =~ /ldapbase/i;
    if ($key =~ /^$target$/i) {
      $targetfound = 1;
      $targetvalue = $value;
    }

    # Allow %% on left hand side
  }

  # Unlock and close
  flock($fh, $LOCK_UN);
  $fh->close();

  #
  # Try and override the value with settings from DBI
  #
  if($dbtarget !~ /sqlquickpeek/) {
   my($db_result) = MailScanner::ConfigSQL::QuickPeek($filename, $dbtarget);
   if(defined($db_result) && $db_result) {
    $targetfound = 1;
    $targetvalue = $db_result;
   }
  }

  # Now do the stuff if $noldap is set, so we don't actually
  if ($ldapserver && $notifldap) {
    return undef;
  }

  #
  # Now try and over-ride the value with the setting from LDAP
  #

  #print STDERR "About to QuickPeek into LDAP for $target\n";
  if ($ldapserver) {
    my($connection, $binding);
    my($result, $searchfor, $number, $entr, $attr, $attr2);

    # Load all the LDAP code
    require 'Net/LDAP.pm' unless $RequireLDAPDone;
    $RequireLDAPDone = 1;

    # Connect and bind
    $connection = Net::LDAP->new($ldapserver, onerror=>'warn') or
      print STDERR "Making LDAP connection error: $@\n";
    # Change for JPK $binding = $connection->bind($ldapbase, anonymous=>1);
    $binding = $connection->bind();
    $binding->code and
      print STDERR "LDAP binding error: $@\n";

    # Build the search string 1 bit at a time. Gets syntax right that way.
    $searchfor = "(objectClass=mailscannerconfmain)";
    $searchfor = "(&$searchfor(mailScannerSite=$ldapsite))";
    $searchfor = "(&$searchfor(mailScannerConfBranch=main))";
  
    $result = $connection->search(
                           base => $ldapbase,
                           scope => 'sub',
                           filter => $searchfor
                                 );
    $result->code and print STDERR "LDAP search for configuration option " .
                    "$target returned error: " . $result->error . "\n";
    $number = 0;
    while (defined($entr = $result->entry($number))) {
      #print STDERR "Fetched Entry $number\n";
      #print STDERR "DN: ", $entr->dn, "\n";
      foreach $attr (sort $entr->attributes) {
        next if $attr =~ /;binary$/;
        $attr2 = lc($attr);
        #next if $attr2 eq 'mailscannerconfbranch';
        #$attr2 =~ s/^mailscannerconf//i or next;
        if ($attr2 =~ /^$target$/i) {
          $targetfound = 1;
          $targetvalue = join(' ',@{$entr->get_value($attr, asref=>1)});
          #print STDERR "$attr2 : $targetvalue\n";
          #print STDERR "QuickPeek LDAP found $attr2 : $targetvalue\n";
          last;
        }
      }
      $number++;
    }
    # Disconnect LDAP server again
    $connection->unbind();
  }

  #
  # If we found the target key in either the conf file or LDAP, return it
  #
  if ($targetfound) {
    #print STDERR "QuickPeek returning $targetvalue\n";
    return $targetvalue;
  } else {
    #print STDERR "QuickPeek returning undef\n";
    return undef;
  }
  #warn "Cannot find definition of $target in config file $filename"
  #  unless $key =~ /$target/i;
}


#
# Allow external code to over-ride values of config variables
# if they are currently ""
#
sub Default {
  my($keyword, $value) = @_;
  if (Value($keyword) eq "") {
    # Remove whitespace if it is a mail header
    $value =~ s/\s+/-/g if $keyword =~ /header$/i && $value =~ /:$/;
    $StaticScalars{$keyword} = $value;
  }
}

#
# Translate external <--> internal keyword names
#
sub ItoE {
  my($val) = @_;
  lc($ItoE{$val}) or lc($val);
}
sub EtoI {
  my($val) = @_;
  lc($EtoI{$val}) or lc($val);
}


# Process and setup the configuration
sub Read {
  my($filename) = @_;

  # Save the configuration filename and directory for later potential use
  # in Custom Functions.
  $MailScanner::Config::ConfFile = $filename;

  # Initially, assume we are never running "file -i" on anything
  $MailScanner::Config::UsingFileICommand = 0;

  # Read the main data, without the $nodefaults flag set.
  # Sorry the logic is upside down.
  ReadData($filename, 0);

  # Read all the filename rules. The "Value" of filenamerules is a list
  # of filenames, each of which contains a list of allow/deny rules.
  # We will have to construct a list of allow/deny rules from the list of
  # matching filenames. We need to build a hash mapping filename to a list
  # of rules.
  ReadFilenameRules('filenamerules',  \%NFilenameRules);
  ReadFilenameRules('afilenamerules', \%AFilenameRules);

  #print STDERR "Finished reading filename rules files\n";

  # Read all the filetype rules. The "Value" of filetyperules is a list
  # of filenames, each of which contains a list of allow/deny rules.
  # We will have to construct a list of allow/deny rules from the list of
  # matching filenames. We need to build a hash mapping filename to a list
  # of rules.
  ReadFiletypeRules('filetyperules',  \%NFiletypeRules);
  ReadFiletypeRules('afiletyperules', \%AFiletypeRules);

  #print STDERR "Finished reading filename rules files\n";

  # Read all the language strings to provide multi-lingual output of
  # all data that goes to the end user.
  # The "value" of languagestrings is a filename, which contains a list
  # of language translation strings.
  ReadLanguageStrings('languagestrings');

  #print STDERR "Finished reading language strings files\n";

  # Read the name/glob/list-name of incoming queue dirs,
  # remove it from the config data, and replace it with
  # a list of incoming queue dirs.
  my($list) = $StaticScalars{inqueuedir};
  delete $StaticScalars{inqueuedir};
  ReadInQueueDirs($list);

  # Read all the virus scanner definitions.
  # These map a scanner name onto a filename.
  %ScannerCmds = ReadDefinitions(Value('virusscannerdefinitions'));

  # Read all the spam list definitions.
  # These map a spam list name onto a DNS domain
  %SpamLists = ReadDefinitions(Value('spamlistdefinitions'));

  # Read in the Phishing Net whitelist.
  # This lists all the hostnames of places to ignore when phishing.
  %PhishingWhitelist = ReadPhishingWhitelist(Value('phishingwhitelist'));
  %PhishingBlacklist = ReadPhishingBlacklist(Value('phishingblacklist'));

  # Call all the user's custom initialisation functions
  my($key, $param, $custom, $fn);
  foreach $key (keys %CustomFunctions) {
    $custom = $CustomFunctions{$key};
    next unless $custom;
    $param = $CustomFunctionsParams{$key};
    MailScanner::Log::InfoLog("Config: calling custom init function %s%s",
                              $custom, $param);
    $fn = 'MailScanner::CustomConfig::Init' . $custom . $param;
    no strict 'refs';
    eval ($fn);
    if ($@) {
      MailScanner::Log::WarnLog("Could not use Custom Function code %s, " .
                                "it could not be \"eval\"ed. Make sure " .
                                "the module " .
                                "is correct with perl -wc (Error: %s)",
                                $fn, $@);

      $StaticScalars{$key} = $Defaults{$key}; # Over-ride if function broken
    }
    use strict 'refs';
  }

  # Read the list of second-level country domain codes that exist
  %MailScanner::Config::SecondLevelDomainExists = ();
  ReadCountryDomainList(MailScanner::Config::Value('secondlevellist'))
    unless MailScanner::Config::IsSimpleValue('strictphishing') &&
           MailScanner::Config::Value('strictphishing');

  # Debug output
  #PrintDefinitions(%ScannerCmds);
  #PrintDefinitions(%SpamLists);

  # Over-ride for EnableSpamBounce option
  $StaticScalars{'enablespambounce'}
    if exists $StaticScalars{'enablespambounce'};
  $Defaults{'enablespambounce'} = 0;
}

# If they have specified --inqueuedir=<string> on the command-line, then I
# need to over-ride the list of incoming queue directories with what they
# specified. Doing it this way allows them to put a directory name, a glob
# or even a text file listing directory names and globs on the command-line,
# i.e. everything they could put in the MailScanner.conf file.
#
# Ideally, we would have a way of over-riding any arbitrary setting in the
# MailScanner.conf file, but I haven't been bothered to write all that code.
#
# Pass in the string they put on the command-line.
sub OverrideInQueueDirs {
  my($newdir) = @_;

  $newdir =~ s/\/$//; # Delete any trailing / character
  delete $StaticScalars{inqueuedir};
  ReadInQueueDirs($newdir);
}


# Read the list of hostnames to be ignored when doing phishing tests.
# Pass in the filename. Return the hash.
#
# In the code for this, it's a direct copy of the ReadPhishingWhitelist() sub,
# so the white and black names are reversed from what would seem logical.
sub ReadPhishingBlacklist {
  my($filename) = @_;

  my($fname, $fh, %whitelist, @blacklist, $counter);

  %whitelist = ();

  # Skip this if they have findphishing = no
  return if MailScanner::Config::IsSimpleValue('findphishing') &&
            !MailScanner::Config::Value('findphishing');

  $filename =~ s/^\s*//g;
  $filename =~ s/\s*$//g;
  return () unless $filename;

  $counter = 0;
  foreach $fname (split(" ", $filename)) {
    next unless $fname;
    $fh = new FileHandle;
    unless (open($fh, "<$fname")) {
      MailScanner::Log::WarnLog("Could not read phishing blacklist file %s", $fname);
      next;
    }

    while(<$fh>) {
      chomp;
      s/^#.*$//;   # Remove comments
      s/^\s*//g;   # Remove leading white space
      s/\s*$//g;   # Remove trailing white space
      s/\s+.*$//g; # Leave only the 1st word
      next if /^$/;
      # Entries in the list starting with "REMOVE " in capitals cause the entry
      # to be forcibly removed from the phishing whitelist.
      if (/^REMOVE\s+(\S+)/i) {
        delete $whitelist{$1};
        push @blacklist, $1;
      } else {
        $whitelist{$_} = 1;
        $counter++;
      }
    }

    # Now process the blacklist
    foreach (@blacklist) {
      delete $whitelist{$_};
    }

    close $fh;
  }
  MailScanner::Log::InfoLog("Read %d hostnames from the phishing blacklists",
                            $counter);

  return %whitelist;
}


# Read the list of hostnames to be ignored when doing phishing tests.
# Pass in the filename. Return the hash.
sub ReadPhishingWhitelist {
  my($filename) = @_;

  my($fname, $fh, %whitelist, @blacklist, $counter);

  %whitelist = ();

  # Skip this if they have findphishing = no
  return if MailScanner::Config::IsSimpleValue('findphishing') &&
            !MailScanner::Config::Value('findphishing');

  $filename =~ s/^\s*//g;
  $filename =~ s/\s*$//g;
  return () unless $filename;

  $counter = 0;
  foreach $fname (split(" ", $filename)) {
    $fh = new FileHandle;
    unless (open($fh, "<$fname")) {
      MailScanner::Log::WarnLog("Could not read phishing whitelist file %s", $fname);
      next;
    }

    while(<$fh>) {
      chomp;
      s/^#.*$//;   # Remove comments
      s/^\s*//g;   # Remove leading white space
      s/\s*$//g;   # Remove trailing white space
      s/\s+.*$//g; # Leave only the 1st word
      next if /^$/;
      # Entries in the list starting with "REMOVE " in capitals cause the entry
      # to be forcibly removed from the phishing whitelist.
      if (/^REMOVE\s+(\S+)/i) {
        delete $whitelist{$1};
        push @blacklist, $1;
      } else {
        $whitelist{$_} = 1;
        $counter++;
      }
    }
  
    # Now process the blacklist
    foreach (@blacklist) {
      delete $whitelist{$_};
    }

    close $fh;
  }
  MailScanner::Log::InfoLog("Read %d hostnames from the phishing whitelist",
                            $counter);

  return %whitelist;
}

# Give all the user's custom functions a chance to clear up
# and neatly shutdown, log totals, close databases, etc.
sub EndCustomFunctions {
  my($custom, $key, $param, $fn);
  foreach $key (keys %CustomFunctions) {
    $custom = $CustomFunctions{$key};
    next unless $custom;
    $param = $CustomFunctionsParams{$key};
    MailScanner::Log::InfoLog("Config: calling custom end function %s%s",
                              $custom, $param);
    $fn = 'MailScanner::CustomConfig::End' . $custom . $param;
    no strict 'refs';
    eval($fn);
    use strict 'refs';
  }
}

# Read the list of second-level domains. We don't check top-level domains
# as you cannot hide much in there.
sub ReadCountryDomainList {
  my ($filename) = @_;

  %MailScanner::Config::SecondLevelDomainExists = ();

  my $fh = new FileHandle;
  unless ($fh->open("< $filename")) {
    MailScanner::Log::WarnLog("Could not read list of country code second-level domain names from %s, \"Use Stricter Phishing Net = no\" will not work properly", $filename);
    return;
  }

  while(<$fh>) {
    chomp;
    s/^#.*$//;   # Remove comments
    s/^\s*//g;   # Remove leading white space
    s/\s*$//g;   # Remove trailing white space
    s/\s+.*$//g; # Leave only the 1st word
    next if /^$/;

    # Only allow 2 dots at most
    if (/\..*\..*\./) {
      # There were at least 3 dots
      MailScanner::Log::WarnLog("Domain name \"%s\" in %s  is deeper than third-level, ignoring it", $_, $filename);
      next;
    }
    $MailScanner::Config::SecondLevelDomainExists{"$_"} = 1;
  }

  $fh->close;
}


# Return a ref to a list of all the filename-rules for a message
# This is done completely separately from the Value() function
# as that will just return the list of filename rules, not the
# rules themselves.
sub NFilenameRulesValue {
  my($message) = @_;
  return FilenameRulesValue($message, \%NFilenameRules, 'filenamerules');
}
sub AFilenameRulesValue {
  my($message) = @_;
  return FilenameRulesValue($message, \%AFilenameRules, 'afilenamerules');
}
sub FilenameRulesValue {
  my($message, $Rules, $keyword) = @_;

  my($list,@filenamelist,$file,$listref,@totallist);

  # Get the list of filenames and split it
  $list = Value($keyword, $message);
  @filenamelist = split(" ", $list);
  return undef unless @filenamelist;

  # Now construct a list containing the concatenation of all the allow-deny
  # rules
  #print STDERR "Filename rulesets are " . join(', ', @filenamelist) . "\n";
  foreach $file (@filenamelist) {
    if (!exists($Rules->{$file})) {
      #print STDERR "Could not find filenamerules $file, forcing a re-read.\n";
      # This filename has not been seen before, so compile it now.
      # Skip the file if it didn't exist, error already generated.
      next unless $Rules->{$file} = ReadOneFilenameRulesFile($file);
    }
    $listref = $Rules->{$file};
    #print STDERR "listref = $listref\n";
    #print STDERR "listref = " . @{$listref} . "\n";
    push @totallist, @{$listref} if defined $listref;
  }

  #print STDERR "Filename rules for message are\n" . join("\n",@totallist) .
  #             "Filename rules for message ends.\n";
  return \@totallist;
}


# Return a ref to a list of all the filetype-rules for a message
# This is done completely separately from the Value() function
# as that will just return the list of filetype rules, not the
# rules themselves.
sub NFiletypeRulesValue {
  my($message) = @_;
  return FiletypeRulesValue($message, \%NFiletypeRules, 'filetyperules');
}
sub AFiletypeRulesValue {
  my($message) = @_;
  return FiletypeRulesValue($message, \%AFiletypeRules, 'afiletyperules');
}
sub FiletypeRulesValue {
  my($message, $Rules, $keyword) = @_;

  my($list,@filetypelist,$file,$listref,@totallist);

  # Get the list of filenames and split it
  $list = Value($keyword, $message);
  @filetypelist = split(" ", $list);
  return undef unless @filetypelist;

  # Now construct a list containing the concatenation of all the allow-deny
  # rules
  #print STDERR "Filetype rulesets are " . join(', ', @filenamelist) . "\n";
  foreach $file (@filetypelist) {
    if (!exists($Rules->{$file})) {
      # This filename has not been seen before, so compile it now.
      # Skip the file if it didn't exist, error already generated.
      next unless $Rules->{$file} = ReadOneFilenameRulesFile($file);
    }
    $listref = $Rules->{$file};
    #print "listref = $listref\n";
    push @totallist, @{$listref} if defined $listref;
  }

  #print STDERR "Filetype rules for message are\n" . join("\n",@totallist) .
  #             "Filetype rules for message ends.\n";
  return \@totallist;
}


# Return a string which is the input string translated into the correct
# language for this particular message.
sub LanguageValue {
  my($message, $string) = @_;

  my $filename = Value('languagestrings', $message);
  #print STDERR "Looking up $string in $filename\n";
  #print STDERR "Answer is " . $LanguageStrings{$filename}{$string} . "\n";
  if (exists $LanguageStrings{$filename}{$string}) {
    return $LanguageStrings{$filename}{$string};
  } else {
    MailScanner::Log::WarnLog('Looked up unknown string %s in language ' .
                              'translation file %s', $string, $filename);
    # As a special case, automatically capitalise my name!
    $string = "MailScanner" if $string eq "mailscanner";
    return $string;
  }
}


# Read all the possible filename-rules files.
# Store them each in a hash of list of \0-separated fields.
sub ReadFilenameRules {
  my($keyword,$Rules) = @_;

  my($rule, $ruleset, $direction, $iporaddr, $regexp, $filename, $namelist,
     %donefile);

  #print STDERR "About to read in all the possible filename rules\n";

  # Do the static filename list if there is one
  $namelist = $StaticScalars{$keyword};
  #print STDERR "Filename-rules: keyword is $keyword, filename is $namelist\n";
  foreach $filename (split(" ", $namelist)) {
    $donefile{"$filename"} = 1;
    $Rules->{$filename} = ReadOneFilenameRulesFile($filename);
    #print STDERR "Storing: $filename is " . $FilenameRules{$filename} . "\n";
  }

  # Do the default filename list if there is one
  $namelist = $Defaults{$keyword};
  #print STDERR "Filename-rules: default keyword is $keyword, filename is $namelist\n";
  if (defined $namelist) {
    foreach $filename (split(" ", $namelist)) {
      $donefile{"$filename"} = 1;
      $Rules->{$filename} = ReadOneFilenameRulesFile($filename);
      #print STDERR "Storing: $filename is " . $FilenameRules{$filename} . "\n";
    }
  }

  # Iterate through every possible rule containing a filename
  $ruleset = $RuleScalars{$keyword};
  #print STDERR "ruleset is $ruleset\n";
  #foreach $rule (split(" ", @{$ruleset})) {
  foreach $rule (@{$ruleset}) {
    ($direction, $iporaddr, $regexp, $namelist) = split(/\0/, $rule, 4);
    # Handle rules with an "and" in them
    if ($namelist =~ /\0/) {
      ($direction, $iporaddr, $regexp, $namelist) = split(/\0/, $namelist, 4);
    }

    #print STDERR "Filename rules are $direction $iporaddr $regexp $namelist\n";

    # Each value in the list can itself be a list of filename-rules files
    foreach $filename (split(" ", $namelist)) {
      # Skip this allow/deny filename if we've read it already
      next if $donefile{"$filename"};
      $donefile{"$filename"} = 1;

      # This builds a hash of filename-->ref-to-list-of-rules
      $Rules->{$filename} = ReadOneFilenameRulesFile($filename);
      #print STDERR "Storing: $filename is " . $FilenameRules{$filename} . "\n";
    }
  }
}

# Read all the possible filetype-rules files.
# Store them each in a hash of list of \0-separated fields.
sub ReadFiletypeRules {
  my($keyword,$Rules) = @_;

  my($rule, $ruleset, $direction, $iporaddr, $regexp, $filename, $namelist,
     %donefile);

  #print STDERR "About to read in all the possible filetype rules\n";

  # Do the static filename list if there is one
  $namelist = $StaticScalars{$keyword};
  #print STDERR "Filetype-rules: keyword is $keyword, filename is $namelist\n";
  foreach $filename (split(" ", $namelist)) {
    $donefile{"$filename"} = 1;
    $Rules->{$filename} = ReadOneFilenameRulesFile($filename);
    #print STDERR "Storing: $filename is " . $FiletypeRules{$filename} . "\n";
  }

  # Do the default filename list if there is one
  $namelist = $Defaults{$keyword};
  #print STDERR "Filetype-rules: default keyword is $keyword, filename is $namelist\n";
  if (defined $namelist) {
    foreach $filename (split(" ", $namelist)) {
      $donefile{"$filename"} = 1;
      $Rules->{$filename} = ReadOneFilenameRulesFile($filename);
      #print STDERR "Storing: $filename is " . $FiletypeRules{$filename} . "\n";
    }
  }

  # Iterate through every possible rule containing a filename
  $ruleset = $RuleScalars{$keyword};
  #print STDERR "ruleset is $ruleset\n";
  #foreach $rule (split(" ", @{$ruleset})) {
  foreach $rule (@{$ruleset}) {
    ($direction, $iporaddr, $regexp, $namelist) = split(/\0/, $rule, 4);
    # Handle rules with an "and" in them
    if ($namelist =~ /\0/) {
      ($direction, $iporaddr, $regexp, $namelist) = split(/\0/, $namelist, 4);
    }

    #print STDERR "Filename rules are $direction $iporaddr $regexp $namelist\n";

    # Each value in the list can itself be a list of filename-rules files
    foreach $filename (split(" ", $namelist)) {
      # Skip this allow/deny filename if we've read it already
      next if $donefile{"$filename"};
      $donefile{"$filename"} = 1;

      # This builds a hash of filename-->ref-to-list-of-rules
      $Rules->{$filename} = ReadOneFilenameRulesFile($filename);
      #print STDERR "Storing: $filename is " . $FiletypeRules{$filename} . "\n";
    }
  }
}


# Read all the possible language-strings files.
# Store them each in a hash of a hash of key/value pairs.
sub ReadLanguageStrings {
  my($keyword) = @_;

  my($rule, $ruleset, $direction, $iporaddr, $regexp, $filename, $namelist,
     %donefile);

  #print STDERR "About to read in all the possible language strings\n";

  # Do the static filename list if there is one
  $namelist = $StaticScalars{$keyword};
  foreach $filename (split(" ", $namelist)) {
    $donefile{"$filename"} = 1;
    $LanguageStrings{$filename} = ReadOneLanguageStringsFile($filename);
    #print STDERR "Storing: $filename is " . $LanguageStrings{$filename} . "\n";
  }

  ## Do the default filename list if there is one
  #$namelist = $Defaults{$keyword};
  ##print STDERR "Language-strings: default keyword is $keyword, filename is $namelist\n";
  #foreach $filename (split(" ", $namelist)) {
  #  $donefile{"$filename"} = 1;
  #  $LanguageStrings{$filename} = ReadOneLanguageStringsFile($filename);
  #  print STDERR "Storing: $filename is " . $LanguageStrings{$filename} . "\n";
  #}

  # Iterate through every possible rule containing a filename
  $ruleset = $RuleScalars{$keyword};
  #print STDERR "ruleset is $ruleset\n";
  #foreach $rule (split(" ", @{$ruleset})) {
  foreach $rule (@{$ruleset}) {
    ($direction, $iporaddr, $regexp, $namelist) = split(/\0/, $rule, 4);
    # Handle rules with an "and" in them
    if ($namelist =~ /\0/) {
      ($direction, $iporaddr, $regexp, $namelist) = split(/\0/, $namelist, 4);
    }

    #print STDERR "Language string rules are $direction $iporaddr " .
    #             "$regexp $namelist\n";

    # Each value in the list can itself be a list of language-strings files
    foreach $filename (split(" ", $namelist)) {
      # Skip this allow/deny filename if we've read it already
      next if $donefile{"$filename"};
      $donefile{"$filename"} = 1;

      # This builds a hash of filename-->ref-to-list-of-rules
      #print STDERR "Reading Language Strings file $filename\n";
      $LanguageStrings{$filename} = ReadOneLanguageStringsFile($filename);
      #print STDERR "Storing: $filename is " . $LanguageStrings{$filename} .
      #             "\n";
    }
  }

  $namelist = $Defaults{$keyword};
  if ($namelist) {
    #print STDERR "Namelist is $namelist\n";

    # Each value in the list can itself be a list of language-strings files
    foreach $filename (split(" ", $namelist)) {
      # Skip this allow/deny filename if we've read it already
      next if $donefile{"$filename"};
      $donefile{"$filename"} = 1;

      # This builds a hash of filename-->ref-to-list-of-rules
      #print STDERR "Reading Language Strings file $filename\n";
      $LanguageStrings{$filename} = ReadOneLanguageStringsFile($filename);
      #print STDERR "Storing: $filename is " . $LanguageStrings{$filename} .
      #             "\n";
    }
  }
}


# Read one of the lists of filename rules.
# Now locks the filename rules file.
sub ReadOneFilenameRulesFile {
  my($filename) = @_;

  my(@AllowDenyList, $result);

  # If the rulesfilename ends in ".FileRule" and doesn't contain any '/'
  # characters, then it's an LDAP ruleset.
  if ($LDAP && $filename !~ /\// && $filename =~ /\.FileRule$/) {
    my($searchfor, $linecounter, $default, $error, $errors);
    my($number, $entr, $attr, $attr2);
    my($rulenum, $ruleaction, $rulematch, $rulelog, $rulereport, @ruleset);

    $searchfor = "(objectClass=mailscannerfileruleObject)";
    $searchfor = "(&$searchfor(mailScannerFileRuleName=$filename))";
    $searchfor = "(&$searchfor(mailScannerSite=$LDAPsite))";

    $result = $LDAP->search(
                     base => $LDAPbase,
                     scope => 'sub',
                     filter => $searchfor,
                     attrs => [ 'mailScannerFileRuleNum',
                                'mailScannerFileRuleAction',
                                'mailScannerFileRuleMatch',
                                'mailScannerFileRuleLog',
                                'mailScannerFileRuleReport' ]
                           );
    $result->code and MailScanner::Log::WarnLog("LDAP search for ruleset " .
                      "%s returned error: %s", $filename, $result->error);

    $number = 0;
    while (defined($entr = $result->entry($number))) {
      #print STDERR "Fetched Entry $number\n";
      #print STDERR "DN: ", $entr->dn, "\n";
      foreach $attr (sort $entr->attributes) {
        #print STDERR "Filename/type attribute is $attr\n";
        next if $attr =~ /;binary$/;
        $attr = lc($attr);
        $rulenum = $entr->get_value($attr) if $attr =~ /rulenum/i;
        $ruleaction = $entr->get_value($attr) if $attr =~ /ruleaction/i;
        $rulematch = $entr->get_value($attr) if $attr =~ /rulematch/i;
        $rulelog = $entr->get_value($attr) if $attr =~ /rulelog/i;
        $rulereport = $entr->get_value($attr) if $attr =~ /rulereport/i;
      }
      $ruleset[$rulenum] = Store1FilenameRule(
              join("\t", $ruleaction, $rulematch, '', $rulelog, $rulereport),
              $number, $filename);
      #print STDERR "Filename/type rule is " . $ruleset[$rulenum] . "\n";
      $number++;
    }

    #print STDERR "Filename/type rule set is 0.." . $#ruleset . "\n";
    foreach $rulenum (0..$#ruleset) {
      push @AllowDenyList, $ruleset[$rulenum] if $ruleset[$rulenum] ne "";
    }
    #foreach $rulenum (@AllowDenyList) {
      #print STDERR "Filename/type rule is $rulenum\n";
    #}
    return \@AllowDenyList;
  }

  #
  # It's not an LDAP rule, so must be a normal file based rule
  #
  my($fileh, $linenum);

  # Open and lock the filename rules to ensure they can't be updated
  # and read simultaneously
  $fileh = new FileHandle;
  unless ($fileh->open("<$filename")) {
    MailScanner::Log::WarnLog("Cannot open filename-rules file %s, skipping",
                              $filename);
    return undef;
  }
  flock($fileh, $LOCK_SH);

  $linenum = 0;
  while(<$fileh>) {
    chomp;
    s/^#.*$//;
    s/^\s*//g;
    s/\s*$//g;
    $linenum++;
    next if /^$/;
    $result = Store1FilenameRule($_, $linenum, $filename);
    push @AllowDenyList, $result if $result ne "";
  }

  # Unlock and close
  flock($fileh, $LOCK_UN);
  $fileh->close();

  return \@AllowDenyList;
}

sub Store1FilenameRule {
  my($line, $linenum, $filename) = @_;

  my($allow, $regexp, $iregexp, $logtext, $usertext);

  ($allow, $regexp, $iregexp, $logtext, $usertext) = split(/\t+/, $line, 5);
  if ($usertext eq "") {
    # They didn't specify the iregexp so set it to "-"
    # and push the rest along by 1.
    $usertext = $logtext;
    $logtext  = $iregexp;
    $iregexp  = '-';
  }
  unless ($allow && $regexp && $iregexp && $logtext && $usertext) {
    MailScanner::Log::WarnLog("Possible syntax error on line %d of %s",
                              $linenum, $filename);
    MailScanner::Log::WarnLog("Remember to separate fields with tab " .
                              "characters!");
    return "";
  }

  # 3 possibilities are something like "allow", "deny", "denyanddelete".
  my $origallow = $allow;
  $allow = lc($allow);
  $allow =~ s/^[ ,]*//g;
  $allow =~ s/[ ,]*$//g;
  if ($allow eq 'allow' || $allow eq 'rename') {
    # Simple 'allow' or 'rename' to the default rename pattern
    ;
  } elsif ($allow =~ /^rename /) {
    # 'rename' with a replacement string, which may start with a space.
    # Remove the ' to ' if they put it in.
    # But keep the original case of the replacement string.
    $origallow =~ s/^rename (to )?/rename /i;
    $allow = $origallow;
  } elsif ($allow =~ /^deny[^@]*$/) {
    if ($allow =~ /delete/) {
      $allow = 'denydelete';
    } else {
      $allow = 'deny';
    }
  } elsif ($allow =~ /@/) {
    my @allowlist = split(/[, ]+/, lc($allow));
    $allow = join(',', @allowlist);
  } else {
    MailScanner::Log::WarnLog("Possible syntax error in first keyword " .
                              "on line %d of %s", $linenum, $filename);
  }

  # OLD $allow = ($allow =~ /allow/i)?'allow':'deny';
  $regexp  =~ s/^\/(.*)\/$/$1/;
  $iregexp =~ s/^\/(.*)\/$/$1/;
  $logtext  = "" if $logtext  eq '-';
  $usertext = "" if $usertext eq '-';
  $iregexp  = "" if $iregexp  eq '-';

  # If we have *any* iregexps then we must run the "file -i" command.
  $MailScanner::Config::UsingFileICommand = 1 if $iregexp ne "";

  return join("\0", $allow, $regexp, $iregexp, $logtext, $usertext);
}


# Read one of the lists of language strings.
# Now locks the language strings file.
sub ReadOneLanguageStringsFile {
  my($filename) = @_;

  my($fileh, $key, $value, $linenum);
  my(%Store);

  # Open and lock the filename rules to ensure they can't be updated
  # and read simultaneously
  $fileh = new FileHandle;
  unless ($fileh->open("<$filename")) {
    MailScanner::Log::WarnLog("Cannot open language-strings file %s, skipping",
                              $filename);
    return undef;
  }
  flock($fileh, $LOCK_SH);

  $linenum = 0;
  while(<$fileh>) {
    chomp;
    s/^#.*$//;
    s/^\s*//g;
    s/\s*$//g;
    $linenum++;
    next if /^$/;
    ($key, $value) = split(/\s*=\s*/, $_, 2);
    $value =~ s/\%([^%]+)\%/$PercentVars{lc($1)}/g;
    $value =~ s/\$\{?(\w+)\}?/$ENV{$1}/g;
    $value =~ s/\\n/\n/g;
    #unless ($key && $value) {
    unless (/=/) {
      MailScanner::Log::WarnLog("Possible syntax error on line %d of %s",
                                $linenum, $filename);
      MailScanner::Log::WarnLog("Remember to separate fields with an = " .
                                "sign!");
      next;
    }
    #print STDERR "Storing $value in $key\n";
    $Store{lc($key)} = $value;
  }

  # Unlock and close
  flock($fileh, $LOCK_UN);
  $fileh->close();

  return \%Store;
}


# Construct the list of incoming queue dirs.
# Take any one of 1. directory name
#                 2. directory name glob (contains * or ?)
#                 3. name of file containing directory names
sub ReadInQueueDirs {
  my($taintedname) = @_;

  my(@list, $listh, $dir, $name);
  
  # We trust the admin to only put sensible names in
  # config file, so untaint it:
  $taintedname =~ /(.*)/;
  $name = $1;
  $name =~ s/\%([^%]+)\%/$PercentVars{lc($1)}/g;
  $name =~ s/\$\{?(\w+)\}?/$ENV{$1}/g;

  if ($name =~ /[\?\*]/) {
    # It's a glob so contains directory names
    @list = map { m/(.*)/ } glob($name);
    #print STDERR "Adding list of inq's " . join(', ', @list) . "\n";
    push @{$StaticScalars{inqueuedir}}, @list;
    return;
  }
  if (-d $name) {
    # It's a simple directory name
    #print STDERR "Adding simple dir name $name\n";
    push @{$StaticScalars{inqueuedir}}, $name;
    return;
  }
  if (-l $name) {
    # It's a soft link to somewhere
    MailScanner::Log::WarnLog("For the incoming queue directory %s, please " .
      "supply the absolute path not including any links", $name);
    MailScanner::Log::WarnLog("I am assuming that %s points to a directory" ,
                              $name);
    push @{$StaticScalars{inqueuedir}}, $name;
    return;
  }

  # Open and lock the list file
  $listh = new FileHandle;
  $listh->open("<$name")
    or MailScanner::Log::WarnLog("File containing list of incoming queue dirs" .
                                " (%s) does not exist", $name),return;
  flock($listh, $LOCK_SH);

  while(<$listh>) {
    chomp;
    s/^#.*$//;
    s/^\s*//g;
    s/\s*$//g;
    /^(.*)$/;
    # Untaint as well as check for empty string (it's coming
    # from a file only the admin should be able to access)
    next if $1 eq "";
    $dir = $1;
    $dir =~ s/\%([^%]+)\%/$PercentVars{lc($1)}/g;
    $dir =~ s/\$\{?(\w+)\}?/$ENV{$1}/g;
    if ($dir =~ /[\?\*]/) {
      # It's a glob so contains directory names
      @list = map { m/(.*)/ } glob($dir);
      push @{$StaticScalars{inqueuedir}}, @list;
      next;
    }
    unless (-d $dir) {
      MailScanner::Log::WarnLog("Incoming queue dir %s does not exist " .
                      "(listed in directory list file %s)", $dir, $name);
      next;
    }
    #print STDERR "Adding dir $dir to list of incoming queues\n";
    push @{$StaticScalars{inqueuedir}}, $dir;
  }
  # Unlock and close
  flock($listh, $LOCK_UN);
  $listh->close();
}


# Read all the definitions of the virus scanner. 2 fields per line,
# separated by whitespace. 1st field is scanner name, 2nd field is
# scanner command. This may be a direct binary, or it may be a script.
sub ReadDefinitions {
  my($filename) = @_;

  #print STDERR "Reading virus scanner definitions from $filename\n";

  my($fileh, $linenum, $key, $value, %hash);

  $fileh = new FileHandle;
  $fileh->open("<$filename")
    or MailScanner::Log::DieLog("Cannot read definitions from %s, %s",
                                $filename, $!);
  flock($fileh, $LOCK_SH);

  $linenum = 0;
  while(<$fileh>) {
    chomp;
    s/^#.*$//;
    s/^\s*//g;
    s/\s*$//g;
    $linenum++;
    next if /^$/;

    $key   = "";
    $value = "";
    if (/^(\S+)\s+(\S+)\s+(.+)$/) {
      # There are 3 words, so separate last 2 with commas
      $key = lc($1);
      $value = $2 . ',' . $3;
    } else {
      /^(\S+)\s+(.+)$/;
      $key   = lc($1);
      $value = $2;
    }

    if ($key && $value) {
      $hash{"$key"} = "$value";
    } else {
      MailScanner::Log::DieLog("Syntax error in definitions file %s",
                               $filename);
    }
  }

  # Unlock and close
  flock($fileh, $LOCK_UN);
  $fileh->close();

  #print STDERR "Finished reading definitions\n";
  return %hash;
}

# Print out the translation table referred to by the hash-ref passed in.
sub PrintDefinitions {
  my(%hash) = @_;

  my($key,$value);

  #print STDERR "\nHere is a definitions file:\n";
  while(($key,$value) = each %hash) {
    #print STDERR "$key\t\t$value\n";
  }
  #print STDERR "End of definition file.\n\n";
}


# Tiny access function:
# Return the value of a virus scanner command
sub ScannerCmds {
  my($key) = @_;
  return $ScannerCmds{$key};
}


# Tiny access function:
# Return the value of an RBL list
sub SpamLists {
  my($key) = @_;
  return $SpamLists{lc($key)};
}

#
# Read the LDAP configuration.
# Just read the basic settings, don't worry about rulesets yet.
#
#$base = "o=fsl";
#$sitename = "default";
sub ReadConfBasicLDAP {
  my($LDAP, $LDAPbase, $LDAPsite) = @_;

  my($result, $searchfor, $number, $entr, $attr, $attr2);

  # Build the search string 1 bit at a time. Gets syntax right that way.
  $searchfor = "(objectClass=mailscannerconfmain)";
  $searchfor = "(&$searchfor(mailScannerSite=$LDAPsite))";
  $searchfor = "(&$searchfor(mailScannerConfBranch=main))";

  $result = $LDAP->search(
                   base => $LDAPbase,
                   scope => 'sub',
                   filter => $searchfor
                         );
  $result->code and MailScanner::Log::WarnLog("LDAP search for basic " .
                    "configuration returned error: %s", $result->error);

  $number = 0;
  while (defined($entr = $result->entry($number))) {
    #print STDERR "Fetched Entry $number\n";
    #print STDERR "DN: ", $entr->dn, "\n";
    foreach $attr (sort $entr->attributes) {
      next if $attr =~ /;binary$/;
      $attr2 = lc($attr);
      next if $attr2 eq 'confserialnumber';
      next if $attr2 eq 'description';
      next if $attr2 eq 'mailscannerconfbranch';
      next if $attr2 eq 'mailscannersite';
      next if $attr2 eq 'mschildren';
      next if $attr2 eq 'objectclass';
      #$attr2 =~ s/^mailscannerconf//i or next;
      $File{$attr2} = join(' ',@{$entr->get_value($attr, asref=>1)});
      #print STDERR "$attr2 : " . $File{$attr2} . "\n";
    }
    $number++;
  }

  # SF - Read the rest of the LDAP config
  MailScanner::Config::LDAPUpdated();
}


#
# Read the configuration file. Doesn't allow includes yet...
#
my %ConfFilesSeen = ();

sub ReadConfFile {
  my($filename) = @_;

  # Slurp the whole file into a big hash.
  # Complain if we see the same keyword more than once.
  my($fileh, $linecounter, $origkey, $key, $value, $ErrorsSeen, $ErrorReport);
  my($savedline);

  # We have seen this config file!
  $ConfFilesSeen{$filename} = 1;
  MailScanner::Log::InfoLog("Reading configuration file %s", $filename);

  $fileh = new FileHandle;
  $fileh->open("<$filename")
    or MailScanner::Log::DieLog("Could not read configuration file %s, %s",
                                $filename, $!);
  flock($fileh, $LOCK_SH);

  $linecounter = 0;
  $ErrorsSeen  = 0;
  while(<$fileh>) {
    $linecounter++;
    chomp;
    s/#.*$//;
    s/^\s+//;
    s/\s+$//;
    next if /^$/;
    $savedline = $_;

    if ($savedline =~ /^include\s+([^=]*)$/i) {
      #print STDERR "Saved line is $savedline\n";
      my $wildcard = $1;
      #print STDERR "Wildcard is \"$wildcard\"\n";
      my @newfiles = map { m/(.*)/ } glob($wildcard);
      #print STDERR "Glob is " . join(', ', @newfiles) . "\n";
      if (@newfiles) {
        # Go through each of the @newfiles reading conf from them.
        for my $newfile (sort @newfiles) {
          # Have we seen it before?
          #print STDERR "Checking $newfile\n";
          if (! -r $newfile) {
            MailScanner::Log::WarnLog("Configuration: Could not read configuration file %s, skipping.", $newfile);
          } elsif ($ConfFilesSeen{$newfile}) {
            MailScanner::Log::WarnLog("Configuration: Seen configuration file %s before, skipping.", $newfile);
          } else {
            # No, so read it.
            #print STDERR "Reading $newfile\n";
            my $errors = ReadConfFile($newfile);
            MailScanner::Log::DieLog("Found configuration file error in %s, terminating.", $newfile) if $errors;
          }
        }
      } else {
        MailScanner::Log::WarnLog("Configuration: Failed to find any configuration files like %s, skipping them.", $wildcard);
      }
      # And don't do any more processing on the "include" line.
      next;
    }

    $_ = $savedline;
    undef $origkey;
    undef $key;
    undef $value;
    /^(.*?)\s*=\s*(.*)$/;
    ($origkey,$value) = ($1,$2);

    # Allow %var% = value lines
    $value =~ s/\%([^%]+)\%/$PercentVars{lc($1)}/g;
    $value =~ s/\$\{?(\w+)\}?/$ENV{$1}/g;
    $value =~ s/\\n/\n/g;
    if ($origkey =~ /^\%([^%]+)\%$/) {
      # Always use the first definition of the %variable%
      # $PercentVars{lc($1)} = $value unless exists $PercentVars{lc($1)};
      # 20090826 Always use the most recent definition of the %variable%
      $PercentVars{lc($1)} = $value;
      next;
    }

    $key = lc($origkey);
    $key =~ s/[^a-z0-9]//g; # Leave numbers and letters only

    # Translate the value to the internal (shorter) version of it
    $key = EtoI($key);

    if ($key eq "") {
      # Invalid line
      $ErrorReport .= "Error in line $linecounter of $filename, " .
                      "line does not make sense. ";
      $ErrorsSeen = 1;
    # 20090811 Added include files so must allow re-setting a variable
    #}
    #elsif (defined $File{$key}) {
    #  # We've seen this keyword before.
    #  $ErrorReport .= "Error in line $linecounter of $filename, " .
    #                  "setting value of ". $origkey ." twice! ";
    #  $ErrorsSeen = 1;
    } else {
      $File{$key} = $value;
      #print STDERR "Defining $key = $value\n";
      # Save where the value was stored
      $LineNos{$key} = "$linecounter of $filename";
    }
  }
  flock($fileh, $LOCK_UN);
  $fileh->close();

  # If we have seen any errors, we can't trust the line numbers in
  # %LineNos, so bail out.
  #
  # Error messages are grouped and reported together, otherwise
  # The reference to 'these errors' in the last message doesn't make
  # sense.
  if ($ErrorsSeen) {
    $ErrorReport .= "Can't continue processing configuration file " .
                    "until these errors have been corrected.";
    MailScanner::Log::WarnLog("%s", $ErrorReport);
    MailScanner::Log::DieLog("Failed to read configuration file %s", $filename);
  }
  return $ErrorsSeen;
}


sub ReadData {
  my($filename, $nodefaults) = @_;

  # Fetch all the configuration setup.
  require 'MailScanner/ConfigDefs.pl'
    or die "Could not read ConfigDefs.pl, $!";

  #print STDERR "In ReadData\n";
  # Now go through the different types of config variable,
  # reading them from *DATA.
  my($category, $type, $keyword, %values, $line, $ConfigFileRead);
  $ConfigFileRead = 0;
  seek(DATA,0,0);
  while(<DATA>) {
    chomp;
    #print STDERR "In ReadData, data is '$_'\n";
    s/#.*$//;
    s/^\s+//;
    s/\s+$//;
    next if /^$/;

    $line = $_;

    # Handle section headings
    #print STDERR "In processing of $category, $type\n";
    if ($line =~ s/^\[(.*)\]$/$1/) {
      $line = lc($line);
      ($category, $type) = split(/\s*,\s*/, $line, 2);
      #print STDERR "About to process $category, $type\n";
      next;
    }

    # Ignore any lines above the top heading
    next unless $category && $type;

    # Store the internal<-->external name translation tables
    if ($category =~ /translation/i) {
      $line = lc($line);
      my($int, $ext);
      ($int, $ext) = split(/\s*=\s*/, $line, 2);
      $ItoE{$int} = $ext;
      $EtoI{$ext} = $int;
      #print STDERR "Translation from e $ext to i $int\n";
      next;
    }

    # At this point, the translation table has been read.
    # So now go and read their mailscanner.conf file!
    unless ($ConfigFileRead) {
      #print STDERR "Reading ConfFile\n";
      %ConfFilesSeen = (); # Reset the list of config files seen and read.
      ReadConfFile($filename);

      unless ($nodefaults) {
        # Override with values from SQL
        MailScanner::ConfigSQL::ReadConfBasic($filename,\%File);
        my($k,$v);
        # Override existing %vars% with ones from SQL
        while (($k,$v) = each %MailScanner::ConfigSQL::PercentVars) {
          $PercentVars{$k} = $v;
        }
        # %PercentVars = %MailScanner::ConfigSQL::PercentVars;

        # Setup LDAP Connection
        ($LDAP, $LDAPserver, $LDAPbase, $LDAPsite) = ConnectLDAP();
        #print STDERR "Made LDAP connection to $LDAP, $LDAPbase, $LDAPsite\n";
        ReadConfBasicLDAP($LDAP, $LDAPbase, $LDAPsite)
          if $LDAP;
      }

      $ConfigFileRead = 1;
    }

    #
    # Read in all the possible configuration values
    #
    #print STDERR "$category, $type\n";
    if ($type =~ /yesno/i) {
      ProcessYesNo($line, $category, $nodefaults);
    } elsif ($type =~ /file/i) {
      ProcessFile($line, $category, $nodefaults);
    } elsif ($type =~ /command/i) {
      ProcessCommand($line, $category, $nodefaults);
    } elsif ($type =~ /dir/i) {
      ProcessDir($line, $category, $nodefaults);
    } elsif ($type =~ /number/i) {
      ProcessNumber($line, $category, $nodefaults);
    } else {
      #print STDERR "line is $line category $category\n" if $line =~ /tnef/i;
      ProcessOther($line, $category, $nodefaults);
    }

  }

  # We have now processed all the valid keywords, so anything left
  # in %File is a syntax error.
  delete $File{""}; # Just in case!
  my(@leftovers, $leftover);
  @leftovers = keys %File;
  if (@leftovers) {
    MailScanner::Log::WarnLog("Syntax error(s) in configuration file:");
    #print STDERR "Syntax error(s) in configuration file:\n";
    foreach $leftover (sort @leftovers) {
      MailScanner::Log::WarnLog("Unrecognised keyword \"%s\" at line %d",
                                ItoE($leftover), $LineNos{$leftover});
      #print STDERR "Unrecognised keyword \"" . ItoE($leftover) .
      #             "\" at line " . $LineNos{$leftover} . "\n";
    }
    MailScanner::Log::WarnLog("Warning: syntax errors in %s.",
                             $filename);
  }
}

# Connect to the LDAP server
sub ConnectLDAP {
  my($ldapserver, $connection, $binding, $site, $dns);

  $ldapserver = $File{'ldapserver'};
  return unless $ldapserver;
  $site = $File{'ldapsite'};
  $dns  = $File{'ldapbase'};

  MailScanner::Log::InfoLog("Using LDAP server %s", $ldapserver);
  $connection = Net::LDAP->new($ldapserver, onerror=>'warn') or
    MailScanner::Log::WarnLog("Making LDAP connection error: %s", $@);
  $binding = $connection->bind($dns, anonymous=>1);
  $binding->code and
    MailScanner::Log::WarnLog("LDAP binding error: %s", $@);

  return ($connection, $ldapserver, $dns, $site);
}

# Disconnect from the LDAP server
sub DisconnectLDAP {
  $LDAP->unbind() if $LDAP;
}

# Knock out a keyword from the config file once it has been processed,
# so anything left at the end must be syntax errors.
# Passed an internal keyword.
sub KeywordDone {
  my($keyword) = @_;

  delete $File{$keyword};
}


#
# Read in a email address rule and turn it into a regexp for fast
# matching against an address later. Allowed forms of input are:
# *@*                (or the keyword "default")
# *@domain.com       (or just "domain.com")
# *@*.domain.com     (or just "*.domain.com")
# user@*             (or just "user@")
# user@*.domain.com
# user@domain.com
# user*@*
# user*@*.domain.com
# user*@domain.com
# 152.78.
# /any-regular-expression/
# host:hostname.domain.com
# host:domain.com
# host:/any-regular-expression/
#
# If the regular expression does not contain any letters, then it
# will be matched against the IP number. If it contains any letters
# then it will be matched against the sender or recipient addresses.
#
# Returns a tuple of (d|t, regexp) where
#     d => digits, ie. IP number
#     t => text, ie. sender or recipient address
#     c => cidr, ie. Range or network/netmask of IP numbers
#     h => hostname, ie. hostname or domain name
#
sub RuleToRegexp {
  my($rule, $type, $nestinglevel) = @_;

  # If the rule starts with / but doesn't end in / then it is a filename
  # which contains a list of regexps (which could in turn include more
  # filenames.
  if ($rule =~ m#^/.*[^/]$#) {
    # $rule is a filename.
    my($file, $line, @result);
    if ($nestinglevel>4) {
      MailScanner::Log::WarnLog("You have nested address pattern list " .
        "files to a depth of at least 4, which probably is not what you " .
        "intended to do. Ignoring the current address pattern list file %s",
        $rule);
      return ();
    }

    $file = new FileHandle;
    $file->open("<$rule")
      or MailScanner::Log::WarnLog("Could not open ruleset's address pattern list file %s, %s", $rule, $!),return;
    flock($file, $LOCK_SH);

    MailScanner::Log::DebugLog("Reading ruleset's address pattern list file %s", $rule);

    while(defined($line=<$file>)) {
      chomp $line;
      $line =~ s/#.*$//;
      $line =~ s/^\s+//;
      $line =~ s/\s+$//;
      next if $line =~ /^$/;
      push @result, RuleToRegexp($line, $type, $nestinglevel+1);
    }
    # Unlock and close rules file
    flock($file, $LOCK_UN);
    $file->close();
    return(@result);
  }

  # Setup variables for handling errors and reproducing
  # their rule expression and not the compiled regexp.
  my($theirrule, $evalok, $compiledre);
  $theirrule = $rule;

  # Treat rules starting with host: as hostnames or domain names
  # Can have * in them as wildcard, or /regexp/ syntax.
  my $rulecopy = $rule;
  if ($rule =~ /^host(-nocheck)?:(.*)$/i) {
    $rule = $2;
    my $nocheck = 0;
    $nocheck = 1 if $rulecopy =~ /^host-nocheck:/i;
    # Look for regexps
    if ($rule =~ /^\/(.*)\/$/) {
      return (($nocheck?'H':'h'),$1);
    }
    # Look for empty matches (that match against there being no hostname)
    if ($rule eq '') {
      return (($nocheck?'H':'h'),'^$');
    }
    # Replace . with \.
    $rule =~ s/\./\\./g;
    # Replace * with .*
    $rule =~ s/\*/.*/g;
    # Anchor it to the end of the name
    $rule .= '$';
    # Add a '.' on the front of their rule if there isn't already one
    $rule = '\.' . $rule unless $rule =~ /^\./;
    #print STDERR "Compiled rule is \"$rule\"\n";
    # Test their rule
    eval { $compiledre = qr/$rule/i; };
    if ($@) {
      MailScanner::Log::WarnLog("Invalid expression in rule \"%s\". " .
                                "Compiler said \"%s\"", $theirrule, $@);
      $rule = '/^\xff$/'; # This should never match anything
    }
    #print STDERR "Compiled rule is \"$rule\"\n";
    return (($nocheck?'H':'h'),$rule);
  }

  # Handle entirely numeric strings as netblocks (and allow IPv6 addresses!)
  if ($rule =~ /^[.:\dabcdef]+$/) {
    # Replace . with \.
    $rule =~ s/\./\\./g;
    # And anchor it to the start of the IP number
    $rule = '^' . $rule;
    # Test their rule
    eval { $compiledre = qr/$rule/i; };
    if ($@) {
      MailScanner::Log::WarnLog("Invalid expression in rule \"%s\". " .
                                "Compiler said \"%s\"", $theirrule, $@);
      $rule = '/^$/'; # This should never match anything
    }
    return ('d',$rule);
  }

  # Handle non-alphabetic regexps as IP number tests.
  # These must not contain any letters.
  if ($rule ne '/^$/' && $rule =~ s#^/([^a-z]+)/$#$1#) {
    # Test their rule
    eval { $compiledre = qr/$rule/i; };
    if ($@) {
      MailScanner::Log::WarnLog("Invalid expression in rule \"%s\". " .
                                "Compiler said \"%s\"", $theirrule, $@);
      $rule = '/^$/'; # This should never match anything
    }
    return ('d',$rule);
  }

  # Could be a CIDR or network range or network/netmask pair
  if ($rule =~ /^([.:\da-f]+)\s*\/\s*([.:\da-f]+)$/) {
    # It's a CIDR, e.g. 152.78/16
    my($network, $bits, $count);
    ($network,$bits) = ($1,$2);
    $count = split(/\./, $network);
    $network .= '.0' x (4-$count);
    return ('c',"$network/$bits");
  }
  ## Could be a CIDR or network range or network/netmask pair
  #if ($rule =~ /^[.:\da-f]+\s*\/\s*[.:\da-f]+$/) {
  #  # It's a CIDR, e.g. 152.78/16
  #  $rule =~ s/\s*//g; # Remove whitespace
  #  return ('c',$rule);
  #}
  if ($rule =~ /^[.:\da-f]+\s*-\s*[.:\da-f]+$/) {
    # It's a network range, e.g. 152.78.0.0-152.78.255.255
    my(@cidr);
    $rule =~ s/\s*//g; # Remove whitespace
    @cidr = Net::CIDR::range2cidr($rule);
    return ('c',join(',',@cidr));
  }

  # Otherwise they are address rules
  $rule = lc($rule);

  # If it is surrounded with '/', then it is an arbitrary regexp
  if ($rule =~ s#^/(.*)/$#$1#) {
    # Test their rule
    eval { $compiledre = qr/$rule/i; };
    if ($@) {
      MailScanner::Log::WarnLog("Invalid expression in rule \"%s\". " .
                                "Compiler said \"%s\"", $theirrule, $@);
      $rule = '/^$/'; # This should never match anything
    }
    return ('t',$rule);
  }

  if ($type =~ /[fbt]/i) {
    # If it is "default" or "*", then make it *@*
    if ($rule eq 'default' || $rule eq '*') {
      $rule = '*@*';
    }
    # If it doesn't contain @
    if ($rule !~ /@/) {
      if ($rule =~ /^\*/) {
        # If it starts with *, then make it *@*.domain.com
        $rule = '*@' . $rule;
      } else {
        # If it doesn't contain a *, then make it *@domain.com
        $rule = '*@' . $rule;
      }
    }
    # Prepend * if leading @
    $rule = '*' . $rule if $rule =~ /^\@/;
    # Append  * if traiing @
    $rule = $rule . '*' if $rule =~ /\@$/;

    # Now it's got an @ sign and something both sides of it
    # Change . into \., @ into \@, * into .*
    $rule =~ s/\@/\\@/g;
    $rule =~ s/\./\\./g;
    $rule =~ s/\+/\\+/g;
    $rule =~ s/\*/.*/g;
    # and tack on the optional "." at the end
    $rule .= '\.?';
    # and tack on the start+end anchors
    $rule = '^' . $rule . '$';
    # Test their rule
    eval { $compiledre = qr/$rule/i; };
    if ($@) {
      MailScanner::Log::WarnLog("Invalid expression in rule \"%s\". " .
                                "Compiler said \"%s\"", $theirrule, $@);
      $rule = '/^$/'; # This should never match anything
    }
    return ('t',$rule);
  } elsif ($type =~ /v/) {
    #print STDERR "Compiling $type $rule\n";
    # It is a virus pattern
    # If it is "default" or "*", then make it *@*
    if ($rule eq 'default') {
      $rule = '*';
    }
    $rule =~ s#\/#\\/#g;
    $rule =~ s#\-#\\-#g;
    $rule =~ s/\./\\./g;
    $rule =~ s/\*/.*/g;
    #$rule = '^' . $rule . '$';
    # Test their rule
    eval { $compiledre = qr/$rule/i; };
    if ($@) {
      MailScanner::Log::WarnLog("Invalid expression in rule \"%s\". " .
                                "Compiler said \"%s\"", $theirrule, $@);
      $rule = '/^$/'; # This should never match anything
    }
    return ('t',$rule);
  } else {
    # Error
    MailScanner::Log::WarnLog("Invalid rule of type %s, rule is \"%s\"",
                              $type, $theirrule);
    return ('t','/^$/');
  }
}




#
# Read in a complete ruleset for 1 keyword.
# Ignore numbered netblocks for now, I'll write them later.
# Turn every pattern into a complete regexp to match against the target
# address, and store them in a list together with From/To flags
# and possibly some type information (to cope with netblocks).
# $ScalarRules{$keyword}[] = join("\0", FromTo, Type, Regexp, Value).
#
sub ReadRuleset {
  my($keyword, $rulesfilename, $rulesettype, $nodefaults, %values) = @_;

  #print STDERR "Keyword is $keyword, filename is $rulesfilename\n";

  # If the rulesfilename ends in ".RuleSet" and doesn't contain any '/'
  # characters, then it's an LDAP ruleset.
  #if ($LDAP && $rulesfilename !~ /\// && $rulesfilename =~ /\.RuleSet$/) {
  if ($LDAP && $rulesfilename =~ /customi[sz]e/) {
    my($searchfor, $linecounter, $default, $error, $errors);
    my($number, $entr, $attr, $attr2, $result);
    my($rulenum, $ruledir, $ruleaddr, $ruleresult, @ruleset);

    $searchfor = "(objectClass=mailscannerRuleSetObject)";
    #$searchfor = "(&$searchfor(mailScannerRuleSetName=$rulesfilename))";
    #$searchfor = "(&$searchfor(mailScannerSite=$LDAPsite))";
    $searchfor = "(&$searchfor(mailScannerRuleSetName=$keyword))";

    $result = $LDAP->search(
                     base => $LDAPbase,
                     scope => 'sub',
                     filter => $searchfor,
                     attrs => [ 'mailScannerRuleSetNum',
                                'mailScannerRuleSetDirection',
                                'mailScannerRuleSetMatch',
                                'mailScannerRuleSetResult' ]
                           );
    $result->code and MailScanner::Log::WarnLog("LDAP search for ruleset " .
    #                  "%s returned error: %s", $rulesfilename, $result->error);
                      "%s returned error: %s", $keyword, $result->error);

    $number = 0;
    while (defined($entr = $result->entry($number))) {
      #print STDERR "Fetched Entry $number\n";
      #print STDERR "DN: ", $entr->dn, "\n";
      foreach $attr (sort $entr->attributes) {
        next if $attr =~ /;binary$/;
        $attr = lc($attr);
        $rulenum = $entr->get_value($attr) if $attr =~ /rulesetnum/i;
        $ruledir = $entr->get_value($attr) if $attr =~ /rulesetdirection/i;
        $ruleaddr = $entr->get_value($attr) if $attr =~ /rulesetmatch/i;
        $ruleresult = $entr->get_value($attr) if $attr =~ /rulesetresult/i;
      }
      $ruleset[$rulenum] = join("\t", $ruledir, $ruleaddr, $ruleresult);
      $number++;
    }

    $RuleScalars{$keyword} = []; # Delete any old inherited rulesets
    foreach $rulenum (0..$#ruleset) {
      #($error, $default) = Store1Rule($ruleset[$rulenum], $rulesfilename,
      ($error, $default) = Store1Rule($ruleset[$rulenum], $keyword,
                                      $rulenum, $rulesettype,
                                      $RuleScalars{$keyword}, %values);
      if ($default) {
        $default =~ s/\s+/-/g if $keyword =~ /header$/i && $default =~ /:$/;
        $Defaults{$keyword} = $default;
      }
      $errors += $error;
    }
    # If the default value was defined and there was only 1 rule,
    # then that single rule must be defining the default value,
    # so it can actually be treated as a simple scalar value and
    # not a ruleset at all.
    if ($#ruleset==0 && defined($default)) {
      $default =~ s/\s+/-/g if $keyword =~ /header$/i && $default =~ /:$/;
      $StaticScalars{$keyword} = $default unless $nodefaults;
    }
    
    MailScanner::Log::WarnLog("Found syntax errors in %s.", $keyword)
      if $errors;
    return;
  }

  # Get the ruleset from the database
  if (((my $rulesetname) = $rulesfilename =~ /(.+)\.customi[sz]e/)) {
   MailScanner::Log::InfoLog('Reading ruleset %s for keyword %s',$rulesetname,$keyword);
   # Read rows from the database
   my($rows) = MailScanner::ConfigSQL::ReadRuleset($rulesetname);
   my($count) = scalar(@$rows);
   my($error, $errors, $default);
   $RuleScalars{$keyword} = []; # Delete any old inherited rulesets

   while(my $row = (shift @$rows)) {
    if($MailScanner::ConfigSQL::debug) {
     eval {
      MailScanner::Log::InfoLog("Read rule %s (%s) from database for keyword %s",$row->{'num'},$row->{'rule'},$keyword);
     };
     if($@) {
      print STDERR "Read rule ".$row->{'num'}." (".$row->{'rule'}.") from database for keyword ".$keyword."\n";
     }
    }
    ($error, $default) = Store1Rule($row->{'rule'}, $keyword, $row->{'num'}, $rulesettype, $RuleScalars{$keyword}, %values);
    $Defaults{$keyword} = $default if defined($default);
    $errors += $error;
    if($error) {
     eval {
      MailScanner::Log::InfoLog("Syntax error in database ruleset %s (num=%s rule=%s)", $keyword, $row->{'num'}, $row->{'rule'});
     };
     if($@) {
      print STDERR "Syntax error in database ruleset $keyword (num=".$row->{'num'}." rule=".$row->{'rule'}."\n";
     }
    }
   }

   # Clear memory
   $rows = undef;

   # If the default value was defined and there was only 1 rule,
   # then that single rule must be defining the default value,
   # so it can actually be treated as a simple scalar value and
   # not a ruleset at all.
   $StaticScalars{$keyword} = $default if $count==0 && defined($default);

   # Report any errors
   if ($errors) {
    eval {
     MailScanner::Log::WarnLog("Found syntax errors in database ruleset %s", $keyword);
    };
    if($@) {
     print STDERR "Found syntax errors in database ruleset ".$keyword."\n";
    }
   }
   return;
  }
 
  #
  # It is a normal filename ruleset.
  #
  my($rulesfh,$errors,$linecounter, $default, $error);

  $rulesfh = new FileHandle;
  $rulesfh->open("<$rulesfilename")
    or MailScanner::Log::WarnLog('Cannot open ruleset file %s, %s',
                                 $rulesfilename, $!), return;
  flock($rulesfh, $LOCK_SH);

  $RuleScalars{$keyword} = []; # Set up empty ruleset
  $linecounter = 0;
  $errors      = 0;
  while(<$rulesfh>) {
    $linecounter++;
    ($error, $default) = Store1Rule($_, $rulesfilename, $linecounter,
                                    $rulesettype, $RuleScalars{$keyword},
                                    %values);
    #print STDERR "Store1Rule returned $error, $default\n";
    if (defined($default)) {
      $default =~ s/\s+/-/g if $keyword =~ /header$/i && $default =~ /:$/;
      $Defaults{$keyword} = $default;
    }
    $errors += $error;
  }

  # Unlock and close rules file
  flock($rulesfh, $LOCK_UN);
  $rulesfh->close();

  MailScanner::Log::WarnLog("Found syntax errors in %s.", $rulesfilename)
    if $errors;
}



sub Store1Rule {
  $_ = shift;
  my($filename, $linecounter, $settype, $StoreIn, %values) = @_;

  my($line, $fromto, $rule, $value, $errors, $firstword);
  my($ruletype, $regexp, $direction, $DefaultValue);

  chomp;
  s/#.*$//;
  s/^\s+//;
  s/\s+$//;
  next if /^$/;

  $fromto = undef;
  $rule   = undef;
  $value  = undef;
  #print STDERR "Line is \"$_\"\n";
  #if (/^(\S+)\s+(\S+)(\s+(\S+))?$/) {
  #  ($direction, $rule, $value) = ($1, $2, $4);
  if (/^(\S+)\s+(\S+)(\s+(.*))?$/) {
    ($direction, $rule, $value) = ($1, $2, $4);
    #print STDERR "Dir = $direction, Rule = $rule, Value = $value\n";
  } else {
    #print STDERR "value is \"$_\"\n";
    MailScanner::Log::WarnLog('Syntax error in line %d of ruleset %s',
                              $linecounter, $filename);
    $errors = 1;
    next;
  }

  #print STDERR "Fields are \"$fromto\", \"$rule\", \"$value\"\n";

  # Syntax check and shorten fromto
  $fromto = '';
  if ($direction =~ /and/i) {
    $fromto = 'b'; # b = both from AND to at the same time
  } else {
    $fromto .= 'f' if $direction =~ /from/i;
    $fromto .= 't' if $direction =~ /to/i;
    $fromto =  'v' if $direction =~ /virus/i;
  }
  if ($fromto eq '') {
    MailScanner::Log::WarnLog('Syntax error in first field in line ' .
      '%d of ruleset %s', $linecounter, $filename);
    $errors = 1;
    next;
  }

  #
  # Look for 2-part conditions with an "and" at the start of the value
  #
  my($direction2, $rule2, $fromto2);
  $fromto2 = '';
  #if ($value =~ /^and\s+(\S+)\s+(\S+)(\s+(\S+))?$/i) {
  # This should fix bug with "and" with multi-value rule results
  if ($value =~ /^and\s+(\S+)\s+(\S+)(\s+(.+))?$/i) {
    ($direction2, $rule2, $value) = ($1, $2, $4);
    $fromto2 = '';
    if ($direction2 =~ /and/i) {
      $fromto2 = 'b'; # both from and to
    } else {
      $fromto2 .= 'f' if $direction2 =~ /from/i;
      $fromto2 .= 't' if $direction2 =~ /to/i;
      $fromto2 =  'v' if $direction2 =~ /virus/i;
    }
    if ($fromto2 eq '') {
      MailScanner::Log::WarnLog('Syntax error in 4th field in line ' .
        '%d of ruleset %s', $linecounter, $filename);
      $errors = 1;
      next;
    }
  }

  # Substitute %% variables
  $value =~ s/\%([^%]+)\%/$PercentVars{lc($1)}/g;
  $value =~ s/\$\{?(\w+)\}?/$ENV{$1}/g;
  $value =~ s/\\n/\n/g;

  # Syntax check the value
  #print STDERR "Config: $keyword has rule value " . $File{$keyword} .
  #             " = " . $values{$value} . "\n";
  # Is it a valid value?
  my $internalvalue = undef;
  $internalvalue = InternalDataValue('unknown', $settype, $value, %values);

  # Convert the rule into a regexp.
  # Pass it the keyword so it can set the default value if there is one.
  #($ruletype, $regexp) = RuleToRegexp($rule);
  my(@ruledata, @ruledata2, $ruletype2, $regexp2);
  @ruledata  = RuleToRegexp($rule, $fromto, 0);
  @ruledata2 = RuleToRegexp($rule2, $fromto2, 0) if $fromto2 ne '';

  while(@ruledata) {
    $ruletype  = shift @ruledata;
    $regexp    = shift @ruledata;
    $ruletype2 = shift @ruledata2;
    $regexp2   = shift @ruledata2;

    # 0 might be a valid value!
    if (defined $internalvalue || $settype eq 'other') {
      # Update the default value if this is it
      #print STDERR "Ruleset: Is \"$regexp\" and \"$regexp2\" the default rule?\n";
      if (($regexp  eq $DefaultAddressRegexp ||
           $regexp  eq $DefaultVirusRegexp)  &&
          $fromto2 ne '' &&
          ($regexp2 eq $DefaultAddressRegexp ||
           $regexp2 eq $DefaultVirusRegexp)) {
        # Don't store it in the main ruleset as it will always match,
        # whereas we want it to be used only if nothing else matches.
        #print STDERR "Ruleset: Storing Defaults = $internalvalue\n";
        #$Defaults{$keyword} = $internalvalue;
        $DefaultValue = $internalvalue;
        next;
      } elsif (($regexp  eq $DefaultAddressRegexp ||
                $regexp  eq $DefaultVirusRegexp)
               && $fromto2 eq '') {
        # Don't store it in the main ruleset as it will always match,
        # whereas we want it to be used only if nothing else matches.
        #print STDERR "Ruleset: Storing Defaults = $internalvalue\n";
        #$Defaults{$keyword} = $internalvalue;
        $DefaultValue = $internalvalue;
        next;
      }

      # It is a valid value, so use it and store it
      my($record);
      if ($fromto2) {
        $record = join("\0", $fromto,  $ruletype,  $regexp,
                             $fromto2, $ruletype2, $regexp2, $internalvalue);
        #print STDERR "Storing long rule $record\n";
      } else {
        $record = join("\0", $fromto, $ruletype, $regexp, $internalvalue);
        #print STDERR "Storing short rule $record\n";
      }
      push @{$StoreIn}, $record;
      #print STDERR "Storing data: for $record\n";
      #print STDERR "Storing data: " . join(',',@{$StoreIn}) . "\n";
    } else {
      # It is an invalid value
      MailScanner::Log::WarnLog("Syntax error in line %d of ruleset file " .
        "%s", $linecounter, $filename);
      $errors = 1;
    }
  }
  return ($errors, $DefaultValue);
}


# Given a ruleset type, a value to check, and a hash defining
# all the possible valid values and their internal representations.
sub InternalDataValue {
  my($keyword, $rulesettype, $value, %validvalues) = @_;

  my(@words, $word, $word2, $internal);
  $internal = "";

  @words = split(" ", $value);

  if ($rulesettype =~ /other/i) {
    # Other rules can contain anything
    # They might have passed in a comma-separated list,
    # so delete any trailing comma
    $value =~ s/,$//;
    $internal .= $value;
    return "$internal"; # if $internal ne "";
    #return undef;
  }

  foreach $word (@words) {
    if ($rulesettype =~ /yesno/i) {
      # YesNo rules can contain words and/or email addresses
      # They might also have put in a comma-separated list rather than space
      $word2 = lc($word); # Allow upper+lower case
      $word2 =~ s/,$//; # Delete any trailing comma
      if (defined($validvalues{$word2})) {
        # It is a valid keyword
        $internal .= ' ' if $internal ne "";
        $internal .= $validvalues{$word2};
      } elsif ($word2 =~ /\@/) {
        # It is an email address
        $internal .= ' ' if $internal ne "";
        $internal .= $word2;
      } else {
        # It is invalid
        return undef;
      }
    } elsif ($rulesettype =~ /file/i) {
      # File rules can only contains filenames which must exist
      # To let them use /dev/null, we just say it exists and isn't a dir
      if (lc($keyword) ne 'pidfile') { # The pidfile is optional, I create it
        unless ((-e $word && !-d $word) ||
                ($LDAP && $word !~ /\//)) {
          MailScanner::Log::WarnLog("Could not read file %s", $word);
          return undef;
        }
      }
      $internal .= ' ' if $internal ne "";
      $internal .= $word;
    } elsif ($rulesettype =~ /dir/i) {
      # Dir rules can only contains directories which must exist
      $word =~ s/\/$//g; # Delete any trailing '/'
      unless (-d $word) {
        MailScanner::Log::WarnLog("Could not read directory %s", $word);
        return undef;
      }
      $internal .= ' ' if $internal ne "";
      $internal .= $word;
    } elsif ($rulesettype =~ /number/i) {
      # Number rules can only contain digits and dots and _ and -
      #print STDERR "Word is \"$word\"\n";
      return undef unless $word =~ /^([\d._-]+)([kmgKMG]?)/;
      $word = $1;
      my $multiplier = lc $2;
      #print STDERR "Multiplier = $multiplier, Word = $word\n";
      $internal .= ' ' if $internal ne "";
      $word =~ s/_//g;
      $word = $word * 1000       if $multiplier eq 'k';
      $word = $word * 1000000    if $multiplier eq 'm';
      $word = $word * 1000000000 if $multiplier eq 'g';
      $internal .= $word;
      #print STDERR "Word = \"$word\"\n";
    } elsif ($rulesettype =~ /command/i) {
      # Command rules must contain executable as first
      # element, then anything
      unless (-x $words[0]) {
        MailScanner::Log::WarnLog("Could not read executable %s", $words[0]);
        return undef;
      }
      $internal .= ' ' if $internal ne "";
      $internal .= $word;
    } else {
      # It's unknown, so warn and return something sensible
      MailScanner::Log::WarnLog('Error: Unknown ruleset type %s in ' .
                                'InternalDataValue(%s)',$rulesettype,$keyword);
      $internal .= ' ' if $internal ne "";
      $internal .= $word;
    }
  }

  return "$internal" if $internal ne "";
  #print STDERR "OOPS! Returning undef.\n";
  return undef;
}

sub ReadYesNoValue {
  my($keyword, $RulesAllowed, $nodefaults, %values) = @_;

  my($first, $isfile, $isrules);
  $first = $File{$keyword};
  $isfile = 1 if $first =~ /^\//; # Filenames start with '/'
  $isrules = 1 if $isfile && $first !~ /(txt|html)$/; # Rules ain't called .txt
  $isrules = 1 if $LDAP && $first =~ /customi[sz]e|\.RuleSet$/; # LDAP ruleset
  $isrules = 1 if $first =~ /customi[sz]e|\.RuleSet$/; # DB or LDAP ruleset

  # It might be a function name
  if ($first =~ /^&/) {
    $first =~ s/^&//;
    $CustomFunctionsParams{$keyword} = $CustomFunctions{$keyword} = $first;
    $CustomFunctions{$keyword} =~ s/\(.*//;
    $CustomFunctionsParams{$keyword} =~ s/^[^\(]+//;
    return;
  } else {
    # Do not delete the Custom Function if it's defined from a RulesetFunction
    unless ($nodefaults eq 'nodefaults') {
      delete $CustomFunctions{$keyword};
      delete $CustomFunctionsParams{$keyword};
    }
  }

  delete $RuleScalars{$keyword};
  delete $StaticScalars{$keyword};

  if ($isrules) {
    # It's a ruleset so try to read it in if we're allowed to
    #print STDERR "Config: $keyword has a ruleset $isrules\n";
    if (!$RulesAllowed) {
      MailScanner::Log::WarnLog("Value of %s cannot be a ruleset, only a " .
                                "simple value", $keyword);
    }
    ReadRuleset($keyword, $first, 'yesno', $nodefaults, %values);
  } else {
    # It's a simple value
    #print STDERR "Config: $keyword has simple value " . $File{$keyword} .
    #             " = " . $values{$File{$keyword}} . "\n";
    my $internal = InternalDataValue($keyword, 'yesno', $File{$keyword},
                                     %values);

    if ($internal ne "") {
      # It is a valid value
      #print STDERR "Config: Setting scalar " . $keyword .
      #             " = $internal\n";
      $StaticScalars{$keyword} = $internal unless $nodefaults;
    } else {
      # It is an invalid value
      MailScanner::Log::WarnLog("Syntax error in line %d, value \"%s\" " .
        "for %s is not one of allowed values \"%s\"", $LineNos{$keyword},
        $File{$keyword}, $keyword, join("\",\"", keys %values));
    }
  }
}

#
# Handle YesNo values
#

sub ProcessYesNo {
  my($line, $category, $nodefaults) = @_;

  my($keyword, $default, %values, $rules);

  undef $keyword;
  undef $default;
  undef %values;

  ($keyword, $default, %values) = split(" ", lc($line));
  $KeywordCategory{$keyword} = $category;
  $KeywordType{$keyword} = 'yesno';
  $HardCodedDefaults{$keyword} = $default;
  # Save the %values for when needed to do internal to external conversion
  $YesNoEtoI{$keyword} = \%values;
  $YesNoItoE{$keyword} = ();
  my($key,$value);
  while (($key,$value) = each %values) {
    $YesNoItoE{$keyword}{$value} = $key;
  }
  #$keyword = EtoI($keyword);
  #print STDERR "Config: YesNo keyword \"$keyword\" default \"$default\" " .
  #             "values are \"". %values . "\"\n"; # if $keyword =~ /spamwhite|definitelynot/i;
  if (exists $File{$keyword}) {
    #print STDERR "About to read the ReadYesNoValue\n"; # if $keyword =~ /spamwhite|definitelynot/i;
    ReadYesNoValue($keyword, ($category !~ /simple/i), $nodefaults, %values);
    $Defaults{$keyword} = $default unless exists $Defaults{$keyword};
    KeywordDone($keyword);
  } else {
    #print STDERR "Using default $default for keyword $keyword\n" if $keyword =~ /spamwhite|definitelynot/i;
    $StaticScalars{$keyword} = $default unless $nodefaults;
  }
}


#
# Handle filenames
#

sub ReadFileValue {
  my($keyword, $RulesAllowed, $nodefaults) = @_;

  my($first, $isfile, $isrules);
  $first = $File{$keyword};
  $first =~ s/\s+.*$//; # Extract the first word
  $isfile = 1 if $first =~ /^\//; # Filenames start with '/'
  $isrules = 1 if $isfile && $first =~ /[Rr]ules?$/; # Try to find ruleset
  $isrules = 1 if $LDAP && $first =~ /customi[sz]e|\.RuleSet$/; # LDAP ruleset
  $isrules = 1 if $first =~ /customi[sz]e|\.RuleSet$/; # DB or LDAP ruleset

  # It might be a function name
  if ($first =~ /^&/) {
    $first =~ s/^&//;
    $CustomFunctionsParams{$keyword} = $CustomFunctions{$keyword} = $first;
    $CustomFunctions{$keyword} =~ s/\(.*//;
    $CustomFunctionsParams{$keyword} =~ s/^[^\(]+//;
    return;
  } else {
    # Do not delete the Custom Function if it's defined from a RulesetFunction
    unless ($nodefaults eq 'nodefaults') {
      delete $CustomFunctions{$keyword};
      delete $CustomFunctionsParams{$keyword};
    }
  }

  delete $RuleScalars{$keyword};
  delete $StaticScalars{$keyword};

  if ($isrules) {
    #print STDERR "Config: $keyword has a ruleset $isrules\n";
    if (!$RulesAllowed) {
      MailScanner::Log::WarnLog("Value of %s cannot be a ruleset, only a " .
                                "simple value", $keyword);
    }
    #print STDERR "Reading ruleset for $keyword, $first, file\n";
    ReadRuleset($keyword, $first, 'file', $nodefaults);
  } else {
    # It's a simple value
    #print STDERR "Config: $keyword has simple value $first\n";
    my $internal = InternalDataValue($keyword, 'file', $File{$keyword});
    #print STDERR "Config: internal = \"$internal\"\n";

    if ($internal ne "") {
      # It is a valid value
      #print STDERR "Config: Setting scalar " . $keyword .
      #             " = $internal\n";
      $StaticScalars{$keyword} = $internal unless $nodefaults;
    } else {
      # It is an invalid value
      MailScanner::Log::WarnLog("Error in line %d, file \"%s\" " .
        "for %s does not exist (or can not be read)",
        $LineNos{$keyword}, $File{$keyword}, $keyword);
    }
  }
}

sub ProcessFile {
  my($line, $category, $nodefaults) = @_;

  my($keyword, $default);

  $keyword = undef;
  $default = undef;
  ($keyword, $default) = split(" ", $line);
  $keyword = lc($keyword);
  $KeywordCategory{$keyword} = $category;
  $KeywordType{$keyword} = 'file';
  $HardCodedDefaults{$keyword} = $default;
  #$keyword = EtoI($keyword);
  #print STDERR "File keyword \"$keyword\" default \"$default\" value \"" .
  #             $File{$keyword} . "\"\n";
  if ($File{$keyword} ne "") {
    ReadFileValue($keyword, ($category !~ /simple/i), $nodefaults);
    $Defaults{$keyword} = $default unless exists $Defaults{$keyword};
    KeywordDone($keyword);
  } else {
    $StaticScalars{$keyword} = $default unless $nodefaults;
  }
}


#
# Handle commands
#

sub ReadCommandValue {
  my($keyword, $RulesAllowed, $nodefaults) = @_;

  my($first, $isfile, $isrules);
  $first = $File{$keyword};
  $first =~ s/\s+.*$//; # Extract the first word
  $isfile = 1 if $first =~ /^\//; # Filenames start with '/'
  $isrules = 1 if $isfile && $first =~ /[Rr]ules?$/; # Try to find ruleset
  $isrules = 1 if $LDAP && $first =~ /\.RuleSet$/; # LDAP ruleset
  $isrules = 1 if $first =~ /customi[sz]e|\.RuleSet$/; # DB or LDAP ruleset

  # It might be a function name
  if ($first =~ /^&/) {
    $first =~ s/^&//;
    $CustomFunctionsParams{$keyword} = $CustomFunctions{$keyword} = $first;
    $CustomFunctions{$keyword} =~ s/\(.*//;
    $CustomFunctionsParams{$keyword} =~ s/^[^\(]+//;
    return;
  } else {
    # Do not delete the Custom Function if it's defined from a RulesetFunction
    unless ($nodefaults eq 'nodefaults') {
      delete $CustomFunctions{$keyword};
      delete $CustomFunctionsParams{$keyword};
    }
  }

  delete $RuleScalars{$keyword};
  delete $StaticScalars{$keyword};

  if ($isrules) {
    #print STDERR "Config: $keyword has a ruleset $isrules\n";
    if (!$RulesAllowed) {
      MailScanner::Log::WarnLog("Value of %s cannot be a ruleset, only a " .
                                "simple value", $keyword);
    }
    ReadRuleset($keyword, $first, 'file', $nodefaults);
  } else {
    # It's a simple value
    #print STDERR "Config: $keyword has simple value $first\n";
    my $internal = InternalDataValue($keyword, 'command', $File{$keyword});
    #print STDERR "Config: internal = \"$internal\"\n";

    if ($internal ne "") {
      # It is a valid value
      #print STDERR "Config: Setting scalar " . $keyword .
      #             " = $internal\n";
      $StaticScalars{$keyword} = $internal unless $nodefaults;
    } else {
      # It is an invalid value
      MailScanner::Log::WarnLog("Error in line %d, file \"%s\" " .
        "for %s does not exist (or can not be read)",
        $LineNos{$keyword}, $File{$keyword}, $keyword);
    }
  }
}


sub ProcessCommand {
  my($line, $category, $nodefaults) = @_;

  my($keyword, $default);

  $keyword = undef;
  $default = undef;
  ($keyword, $default) = split(" ", $line);
  $keyword = lc($keyword);
  $KeywordCategory{$keyword} = $category;
  $KeywordType{$keyword} = 'command';
  $HardCodedDefaults{$keyword} = $default;
  #$keyword = EtoI($keyword);
  #print STDERR "File keyword \"$keyword\" default \"$default\" value \"" .
  #             $File{$keyword} . "\"\n";
  if ($File{$keyword} ne "") {
    ReadCommandValue($keyword, ($category !~ /simple/i), $nodefaults);
    $Defaults{$keyword} = $default unless exists $Defaults{$keyword};
    KeywordDone($keyword);
  } else {
    $StaticScalars{$keyword} = $default unless $nodefaults;
  }
}


#
# Handle directories
#

sub ReadDirValue {
  my($keyword, $RulesAllowed, $nodefaults) = @_;

  my($first, $isrules);
  $first = $File{$keyword};
  $isrules = 1 if -f $first; # Rules are files
  $isrules = 1 if $LDAP && $first =~ /customi[sz]e|\.RuleSet$/; # LDAP ruleset
  $isrules = 1 if $first =~ /customi[sz]e|\.RuleSet$/; # DB or LDAP ruleset

  # It might be a function name
  if ($first =~ /^&/) {
    $first =~ s/^&//;
    $CustomFunctionsParams{$keyword} = $CustomFunctions{$keyword} = $first;
    $CustomFunctions{$keyword} =~ s/\(.*//;
    $CustomFunctionsParams{$keyword} =~ s/^[^\(]+//;
    return;
  } else {
    # Do not delete the Custom Function if it's defined from a RulesetFunction
    unless ($nodefaults eq 'nodefaults') {
      delete $CustomFunctions{$keyword};
      delete $CustomFunctionsParams{$keyword};
    }
  }

  delete $RuleScalars{$keyword};
  delete $StaticScalars{$keyword};

  if ($isrules) {
    #print STDERR "Config: $keyword has a ruleset $isrules\n"
    #  if $keyword =~ /^in.*dir$/i;
    if (!$RulesAllowed) {
      MailScanner::Log::WarnLog("Value of %s cannot be a ruleset, only a " .
                                "simple value", $keyword);
    }
    # Read the ruleset here
    ReadRuleset($keyword, $first, 'dir', $nodefaults);
  } else {
    # It's a simple value
    $first =~ s/\/$//g; # Delete any trailing '/'
    #print STDERR "Config: $keyword has simple value $first\n"
    #  if $keyword =~ /^in.*dir$/i;
    my $internal = InternalDataValue($keyword, 'dir', $File{$keyword});

    if ($internal ne "") {
      # It is a valid value
      #print STDERR "Config: Setting scalar " . $keyword .
      #             " = $internal\n" if $keyword =~ /^in.*dir$/i;
      $StaticScalars{$keyword} = $internal unless $nodefaults;
    } else {
      # It is an invalid value
      MailScanner::Log::WarnLog("Error in configuration file line %d, " .
        "directory %s for %s does not exist (or is not readable)",
        $LineNos{$keyword}, $first, $keyword);
    }
  }
}


sub ProcessDir {
  my($line, $category, $nodefaults) = @_;

  my($keyword, $default);

  undef $keyword;
  undef $default;

  ($keyword, $default) = split(" ", $line);
  $keyword = lc($keyword);
  $KeywordCategory{$keyword} = $category;
  $KeywordType{$keyword} = 'dir';
  $HardCodedDefaults{$keyword} = $default;
  #$keyword = EtoI($keyword);
  #print STDERR "Dir keyword \"$keyword\" default \"$default\" value \"" .
  #             $File{$keyword} . "\n" if $keyword =~ /^in.*dir$/i;
  if (defined $File{$keyword} && $File{$keyword} ne "") {
    ReadDirValue($keyword, ($category !~ /simple/i), $nodefaults);
    $Defaults{$keyword} = $default unless exists $Defaults{$keyword};
    KeywordDone($keyword);
  } else {
    $StaticScalars{$keyword} = $default unless $nodefaults;
  }

}


#
# Handle numbers
#

sub ReadNumberValue {
  my($keyword, $RulesAllowed, $nodefaults) = @_;

  my($first, $isrules);
  $first = $File{$keyword};
  $isrules = 1 if $first !~ /^[\d._-]+[kmgKMG]?/; # Rules aren't all digits or ._- followed by optional multiplier
  $isrules = 1 if $LDAP && $first =~ /customi[sz]e|\.RuleSet$/; # LDAP ruleset
  $isrules = 1 if $first =~ /customi[sz]e|\.RuleSet$/; # DB or LDAP ruleset

  # It might be a function name
  if ($first =~ /^&/) {
    $first =~ s/^&//;
    $CustomFunctionsParams{$keyword} = $CustomFunctions{$keyword} = $first;
    $CustomFunctions{$keyword} =~ s/\(.*//;
    $CustomFunctionsParams{$keyword} =~ s/^[^\(]+//;
    return;
  } else {
    # Do not delete the Custom Function if it's defined from a RulesetFunction
    unless ($nodefaults eq 'nodefaults') {
      delete $CustomFunctions{$keyword};
      delete $CustomFunctionsParams{$keyword};
    }
  }

  delete $RuleScalars{$keyword};
  delete $StaticScalars{$keyword};

  if ($isrules) {
    #print STDERR "Config: $keyword has a ruleset $isrules\n";
    if (!$RulesAllowed) {
      MailScanner::Log::WarnLog("Value of %s cannot be a ruleset, only a " .
                                "simple value", $keyword);
    }
    # Read the ruleset here
    ReadRuleset($keyword, $first, 'number', $nodefaults);
  } else {
    # It's a simple value
    #print STDERR "Config: $keyword has simple value $first\n";
    my $internal = InternalDataValue($keyword, 'number', $File{$keyword});

    if ($internal ne "") {
      # It is a valid value
      #print STDERR "Config: Setting scalar " . $keyword .
      #             " = $internal\n";
      $StaticScalars{$keyword} = $internal unless $nodefaults;
    } else {
      # It is an invalid value
      MailScanner::Log::WarnLog("Syntax error in line %d, %s for %s " .
        "should be a number", $LineNos{$keyword}, $first, $keyword);
    }
  }
}


sub ProcessNumber {
  my($line, $category, $nodefaults) = @_;

  my($keyword, $default);

  $keyword = undef;
  $default = undef;
  #$keyword = EtoI($keyword);
  ($keyword, $default) = split(" ", $line);
  $keyword = lc($keyword);
  $KeywordCategory{$keyword} = $category;
  $KeywordType{$keyword} = 'number';
  $HardCodedDefaults{$keyword} = $default;

  #print STDERR "Number keyword \"$keyword\" default \"$default\" value \"" .
  #             $File{$keyword} . "\n";
  if ($File{$keyword} ne "") {
    ReadNumberValue($keyword, ($category !~ /simple/i), $nodefaults);
    $Defaults{$keyword} = $default unless exists $Defaults{$keyword};
    KeywordDone($keyword);
  } else {
    $StaticScalars{$keyword} = $default unless $nodefaults;
  }

}


#
# Handle other values...
# This includes a special case for "inqueuedir" as that can be the name
# of a file containing a list of mqueue.in directories, not a ruleset.
#

sub ReadOtherValue {
  my($keyword, $RulesAllowed, $nodefaults) = @_;

  my($first, $isrules);
  $first = $File{$keyword};
  $isrules = 1 if $first =~ /^\// && $first =~ /[Rr]ules?$/ && -f $first; # Rules are filenames
  $isrules = 1 if $LDAP && $first =~ /customi[sz]e|\.RuleSet$/; # LDAP ruleset
  $isrules = 1 if $first =~ /customi[sz]e|\.RuleSet$/; # DB or LDAP ruleset

  # It might be a function name
  if ($first =~ /^&/) {
    $first =~ s/^&//;
    $CustomFunctionsParams{$keyword} = $CustomFunctions{$keyword} = $first;
    $CustomFunctions{$keyword} =~ s/\(.*//;
    $CustomFunctionsParams{$keyword} =~ s/^[^\(]+//;
    return;
  } else {
    # Do not delete the Custom Function if it's defined from a RulesetFunction
    unless ($nodefaults eq 'nodefaults') {
      delete $CustomFunctions{$keyword};
      delete $CustomFunctionsParams{$keyword};
    }
  }

  delete $RuleScalars{$keyword};
  delete $StaticScalars{$keyword};

  if ($isrules && $keyword ne 'inqueuedir') {
    #print STDERR "Config: $keyword has a ruleset $isrules\n";
    if (!$RulesAllowed) {
      MailScanner::Log::WarnLog("Value of %s cannot be a ruleset, only a " .
                                "simple value", $keyword);
    }
    # Read the ruleset here
    ReadRuleset($keyword, $first, 'other', $nodefaults);
  } else {
    # It's a simple value
    #print STDERR "Config: $keyword has simple other value $first\n";
    my $internal = InternalDataValue($keyword, 'other', $File{$keyword});

    #if ($internal ne "") {
    if (defined $internal) {
      # It is a valid value
      #print STDERR "Config: Setting other scalar " . $keyword .
      #             " = $internal\n";
      # Percent variables need to be substituted here.
      $internal = DoPercentVars($internal); # %vars% must be defined before use
      $internal =~ s/\$\{?(\w+)\}?/$ENV{$1}/g;
      # Strip whitespace from mail headers
      $internal =~ s/\s+/-/g if $keyword =~ /header$/i && $internal =~ /:$/;
      $StaticScalars{$keyword} = $internal unless $nodefaults;
    }
    # Could do some specific syntax checking in here
  }
}


sub ProcessOther {
  my($line, $category, $nodefaults) = @_;

  my($keyword, $default);

  ($keyword, $default) = split(" ", $line, 2); # Allow spaces in it
  $keyword = lc($keyword);
  $KeywordCategory{$keyword} = $category;
  $KeywordType{$keyword} = 'other';
  $HardCodedDefaults{$keyword} = $default;
  #$keyword = EtoI($keyword);
  #print STDERR "Other keyword \"$keyword\" default \"$default\" value \"" .
  #             $File{$keyword} . "\"\n";
  if (exists $File{$keyword}) { # ne "") {
    ReadOtherValue($keyword, ($category !~ /simple/i), $nodefaults);
    unless (exists $Defaults{$keyword}) {
      $default =~ s/\s+/-/g if $keyword =~ /header$/i && $default =~ /:$/;
      $Defaults{$keyword} = $default;
    }
    KeywordDone($keyword);
  } else {
    $default =~ s/\s+/-/g if $keyword =~ /header$/i && $default =~ /:$/;
    $StaticScalars{$keyword} = $default unless $nodefaults;
  }

}

# Go through the configuration we have loaded and try to find all the
# options whose settings do not match the default.
# Use &Value to find the current setting, %RuleScalars exists where there
# is a ruleset for the value, %Defaults contains the default setting.
# Don't know what happens when there is a %Default which is a pointer to
# a ruleset, we'll have to find out.
# Print out a list of all the changed settings, what their default was and
# what their new value is. If it's a ruleset, just print out "rules".
sub PrintNonDefaults {
  my($key, $default, $actual, $external, %Output, $fixed, $fixed2);

  print "\nTable of Changed Values:\n\n";
  print PrintFixedWidth("Option Name", 35) . PrintFixedWidth("Default", 15) .
        "Current Value\n";
  print "=" x 79 . "\n";

  while (($key,$default) = each %HardCodedDefaults) {
    # This is a cheap Value($key) that won't evaluate Custom Functions
    $actual = $Defaults{$key};
    $actual = $StaticScalars{$key} if exists $StaticScalars{$key};

    $external = ItoE($key);
    # Special case for this one as it is a list of directory names
    if ($key eq 'inqueuedir') {
      my @dirs = @{Value('inqueuedir')};
      $actual = join(',',@dirs);
    }
    # Translate the internal numbers into user-readable keywords
    if ($KeywordType{$key} eq 'yesno') {
      $default = 0 unless $default;
      $actual  = 0 unless $actual;
      $default = $YesNoItoE{$key}{$default};
      $actual  = $YesNoItoE{$key}{$actual};
    }
    $fixed = PrintFixedWidth($external, 35);
    $fixed2 = PrintFixedWidth($default, 15);
    $actual =~ s/\n/\\n/g;
    if ($CustomFunctions{$key}) {
      # It's a Custom Function
      $Output{$external} = "$fixed$fixed2" . "FUNCTION:" . $CustomFunctions{$key};
    } elsif ($RuleScalars{$key}) {
      # It's a ruleset
      $Output{$external} = "$fixed$fixed2" . "RULESET:Default=$actual";
    } else {
      # It's a scalar
      $Output{$external} = "$fixed$fixed2$actual"
        if ($actual ne $default) && !($default eq '0' && $actual eq '');
    }
  }
  foreach $external (sort keys %Output) {
    print $Output{$external} . "\n";
  }
}
    
sub PrintFixedWidth {
  my($text,$width) = @_;
  my $length = length $text;
  $text .= ' ';
  $width--;
  $text .= ' ' x ($width-$length) if $width > $length;
  return $text;
}

# Has the LDAP configuration data changed in the last couple of minutes?
# Only actually do the LDAP query every 2 minutes, just cache it in
# between.
my($LDAPSerial, $LDAPSerialExpires);
my $LDAPSerialRetryTime = 120; # 2 minutes

sub LDAPUpdated {
  # Do nothing if we aren't using LDAP anyway
  return 0 unless $LDAP;

  if (!$LDAPSerial) {
    # There is no serial number, so fetch the current serial number
    # and do not trigger a restart.
    $LDAPSerial = LDAPFetchSerial();
    return 0;
  }

  # The first time around, the expiry time will be 0 so it will trigger.
  my $now = time;
  if ($now>$LDAPSerialExpires) {
    # Serial number has expired, fetch a new one
    my $newserial = LDAPFetchSerial();
    if ($newserial) {
      # Attempt to get serial number succeeded.
      # Trigger restart if it has changed.
      return 1 if $newserial ne $LDAPSerial;
    }
    $LDAPSerialExpires = $now + $LDAPSerialRetryTime;
  }
  return 0;
}

# Fetch the serial number from the same point in the tree as the rest of
# the LDAP MailScanner.conf settings.
# Attribute is 'mailScannerConfSerialNumber'.
sub LDAPFetchSerial {
  my($result, $searchfor, $number, $entr, $attr, $serial);

  # Build the search string 1 bit at a time. Gets syntax right that way.
  $searchfor = "(objectClass=mailscannerconfmain)";
  $searchfor = "(&$searchfor(mailScannerSite=$LDAPsite))";
  $searchfor = "(&$searchfor(mailScannerConfBranch=main))";

  $result = $LDAP->search(
                   base => $LDAPbase,
                   scope => 'sub',
                   filter => $searchfor,
  #                 attrs => ['mailScannerConfSerialNumber']
                   attrs => ['ConfSerialNumber']
                         );
  if ($result->code) {
    MailScanner::Log::WarnLog("LDAP search for configuration serial number " .
                              "returned error: %s", $result->error);
    return undef;
  }

  $number = 0;
  while (defined($entr = $result->entry($number))) {
    #print STDERR "Fetched Entry $number\n";
    #print STDERR "DN: ", $entr->dn, "\n";
    foreach $attr (sort $entr->attributes) {
      next unless $attr =~ /serialnumber/i;
      next if $attr =~ /;binary$/;
      $serial = join(' ',@{$entr->get_value($attr, asref=>1)});
    }
    $number++;
  }
  MailScanner::Log::DebugLog("LDAP configuration serial number is %s", $serial);
  return $serial;
}

# Call the CustomAction hook for custom spam actions
sub CallCustomAction {
  my($message, $yn, $flag) = @_;

  eval { MailScanner::CustomConfig::CustomAction($message, $yn, $flag); };
  if ($@) {
    MailScanner::Log::WarnLog('Calling CustomAction returned %s', $@);
    #print STDERR "CustomAction returned $@\n";
  }
}

1;

