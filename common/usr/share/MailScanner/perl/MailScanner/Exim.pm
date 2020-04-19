#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: Exim.pm 3638 2006-06-17 20:28:07Z sysjkf $
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

package MailScanner::Sendmail;

use strict 'vars';
use strict 'refs';
no  strict 'subs';		# Allow bare words for parameter %'s

use vars qw($VERSION);

use Data::Dumper;
use IO::Pipe;
use Carp;
use Encode;

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 3638 $, 10;

# Command-line options you need to give to sendmail to sensibly process
# a message that is piped to it. Still need to add the envelope sender
# address argument for -f. This is usually local postmaster.
my @SendmailOptions = qw"-t -oi -oem -F MailScanner -f";
my $UnsortedBatchesLeft;


# Attributes are
#
# $DFileRegexp                  set by new
# $HFileRegexp                  set by new
# $TFileRegexp                  set by new
# $QueueFileRegexp              set by new
# $LockType                     set by new
#


# If the sendmail and/or sendmail2 config variables aren't set, then
# set them to something sensible. This will need to be different
# for Exim.
sub initialise {
  MailScanner::Config::Default('sendmail', '/usr/sbin/exim');
  MailScanner::Config::Default('sendmail2',
			       MailScanner::Config::Value('sendmail').
			       ' -C /etc/exim/exim_send.conf');
  $UnsortedBatchesLeft = 0; # Disable queue-clearing mode
}

# Constructor.
# Takes dir => directory queue resides in
sub new {
  my $type = shift;
  my $this = {};

  # These need to be improved
  # No change for V4
  $this->{DFileRegexp} = '^([-\\w]*)-D$';
  $this->{HFileRegexp} = '^([-\\w]*)-H$';
  $this->{TFileRegexp} = '^([-\\w]*)-T$';
  $this->{QueueFileRegexp} = '^([-\\w]*)-[A-Z]$';

  $this->{LockType} = "posix";

  bless $this, $type;
  return $this;
}

# Required vars are:
#
# DFileRegexp:
# A regexp that will verify that a filename is a valid
# "DFile" name and leave the queue id in $1 if it is.
#
# HFileRegexp:
# A regexp that will verify that a filename is a valid
# "HFile" name and leave the queue id in $1 if it is.
#
# TFileRegexp:
# A regexp that will verify that a filename is a valid
# "TFile" name and leave the queue id in $1 if it is.
#
# QueueFileRegexp:
# A regexp that will match any legitimate queue file name
# and leave the queue id in $1.
#
# LockType:
# The way we should usually do spool file locking for
# this MTA ("posix" or "flock")
#
# Required subs are:
#
# DFileName: 
# Take a queue ID and return
# filename for data queue file
#
# HFileName:
# Take a queue ID and return
# filename for envelope queue file
#
# TFileName:
# Take a queue ID and return
# filename for temp queue file
#
# BuildMessageCmd:
# Return the shell command to take a mailscanner header file
# and an MTA message file, and build a plain text message
# (complete with headers)
#
# ReadQf:
# Read an envelope queue file (sendmail qf) and build
# an array of lines which together form all the mail headers.
#
# AddHeader:
# Given a current set of headers (string), and another header
# (key string, value string), return the set of headers with the new one
# added.
#
# DeleteHeader:
# Given a current set of headers (string), and another header
# (string), return the set of headers with the new one removed.
#
# ReplaceHeader:
# Given a current set of headers (string), and another header
# (key string, value string), return the set of headers with the new one
# in place of any existing occurence of the header.
#
# AppendHeader:
# Given a current set of headers (string), another header
# (key string, value string), and a separator string,
# return the set of headers with the new value
# appended to any existing occurrence of the header.
#
# PrependHeader:
# Given a current set of headers (string), another header
# (key string, value string), and a separator string,
# return the set of headers with the new value
# prepended to the front of any existing occurrence of the header.
# Do the header matching in a case-insensitive way.
#
# TextStartsHeader:
# Given a current set of headers (string), another header (string)
# and a search string,
# return true if the search string appears at the start of the
# text of the header.
# Do the matching in a case-insensitive way.
#
# ConstructHeaders:
# Build a set of headers (in a string) ready to go into an MTA
# envelope file.
#
# ReadEnvelope:
# Given filehandle open for reading, read envelope lines into
# string and return it.
#
# SplitEnvelope:
# Given complete envelope string, separate out header lines and
# return 2 strings, one containing the main part of the envelope,
# the other containing the headers.
#
# MergeEnvelope:
# Given main envelope body (from SplitEnvelope at the moment) and
# string of headers, merge them to form a complete envelope.
#
# MergeEnvelopeParts:
# Given filehandle open for reading, merge envelope data (excepting
# headers) from filehandle with headers from string, and return new
# envelope data in string, ready to be written back to new
# envelope queue file.
#
# AddRecipients:
# Return list of QF file lines for the passed recipients, which
# are comma-separated (with optional spaces with the commas).
# Not implemented for Exim yet.
#
# KickMessage:
# Given id, tell MTA to make a delivery attempt.
#
# CreateQf:
# Given a Message object, return a string containing the entire
# header file for this MTA.
#

# Do conditional once at include time

#my($MTA) = MailScanner::Config::Value('mta');
#
#print STDERR "MTA is \"" . MailScanner::Config::Value('mta') . "\"\n";
#
#  print STDER "We are running exim\n";
#
#  MailScanner::Log::InfoLog("Configuring mailscanner for exim...");

sub DFileName {
  my($this, $id) = @_;
  return "$id-D";
}

# No change for V4
sub HFileName {
  my($this, $id) = @_;
  return "$id-H";
}

# No change for V4
sub TFileName {
  my($this, $id) = @_;
  return "$id-T";
}

# Per-message log file is specific to Exim
sub LFileName {
  my($this, $id) = @_;
  return "../msglog/$id";
}

#  sub BuildMessageCmd {
#    my($this, $hfile, $dfile) = @_;
#    return "$global::sed -e '1d' \"$dfile\" | $global::cat \"$hfile\" -";
#  }

sub ReadQf {
  my($this, $message, $getipfromheader) = @_;

  my($RQf) = $message->{store}{inhhandle};

  my %metadata;
  my($InHeader, $InSubject, $InDel, @headers, $msginfo, $from, @to, $subject);
  my($ip, $sender, %acl, %aclc, %aclm, $line, $acltype);
  my(@rcvdiplist);
  #my($read1strcvd, $ipfromheader);

  #print STDERR "ReadQf for " . $message->{id} . "\n";

  # Seek to the start of the file in case anyone read the file
  # between me opening it and locking it.
  seek($RQf, 0, 0);

  # queue file name
  chomp($metadata{id} = <$RQf>);
  # username, uid, gid that submitted message
  chomp(($metadata{user},$metadata{uid},$metadata{gid}) = split / /, <$RQf>);
  # envelope-sender (in <>)
  $sender = <$RQf>;
  chomp $sender;
  $sender =~ s/^<\s*//; # leading and
  $sender =~ s/\s*>$//; # trailing <>
  #$sender = lc($sender);
  $metadata{sender} = $sender;
  #$message->{from}  = $sender;
  $message->{from}  = lc($sender);
  #JKF Don't want the < or >
  #JKF chomp($metadata{sender} = <$RQf>);
  #JKF $message->{from} = lc $metadata{sender};
  # time msg received (seconds since epoch)
  # + number of delay warnings sent
  chomp(($metadata{rcvtime},$metadata{warncnt}) = split / /, <$RQf>);

  # Loop through -line section, setting metadata
  # items corresponding to Exim's names for them,
  # and tracking them in %{$metadata{dashvars}}
  while (chomp($line = <$RQf>)) {
    $line =~ s/^--?(\w+) ?// or last;
    # ACLs patch starts here
    #$metadata{dashvars}{$1} = 0;
    #$line eq "" and $metadata{"dv_$1"} = 1, next;
    #$metadata{"dv_$1"} = $line;
    #$metadata{dashvars}{$1} = 1;
    # ACLs can be -acl or -aclc or -aclm.
    $acltype = $1;
    if($acltype =~ /^acl[cm]?$/) {
      # we need to handle acl vars differently
      if($line =~ /^(\w+|_[[:alnum:]_]+) (\d+)$/) {
        my $buf;
        my $pos = $1;
        my $len = $2;
        if ($acltype eq "acl") {
          $acl{$pos}->[0] = [];
        } elsif ($acltype eq "aclc") {
          $aclc{$pos}->[0] = [];
        } elsif ($acltype eq "aclm") {
          $aclm{$pos}->[0] = [];
        } else {
          # invalid format
          last;
        }
        (read($RQf, $buf, $len + 1)==$len+1) or last;
        if($buf =~ /\n$/) {
          chomp $buf;
        } else {
          # invalid format
          last;
        }
        if ($acltype eq "acl") {
          $acl{$pos}->[0] = $buf;
        } elsif ($acltype eq "aclc") {
          $aclc{$pos}->[0] = $buf;
        } elsif ($acltype eq "aclm") {
          $aclm{$pos}->[0] = $buf;
        } else {
          # invalid format
          last;
        }
      } else {
        # this is a weird format, and we're not sure how to handle it
        last;
      }
    } else {
      $metadata{dashvars}{$1} = 0;
      $line eq "" and $metadata{"dv_$1"} = 1, next;
      $metadata{"dv_$1"} = $line;
      $metadata{dashvars}{$1} = 1;
    }
    next;
  }
  $metadata{aclvars} = \%acl;
  $metadata{aclcvars} = \%aclc;
  $metadata{aclmvars} = \%aclm;

  # If it was an invalid queue file, log a warning and tell caller
  unless (defined $line) {
    #MailScanner::Log::WarnLog("Batch: Ignoring invalid queue file for " .
    #                          "message %s", $metadata{id});
    return 0;
  }

  # FIXME: we haven't really defined what $message{clientip} should
  # be when it's a locally-submitted message... so the rest of
  # the code probably doesn't deal with it well.
  #
  #     JKF: Sendmail apparently generates "root@localhost" as the client ip
  #     address, which I currently don't handle at all, oops!
  #     It *doesn't* contain a numerical IP address, as opposed to SMTP
  #     connections from localhost, which get a numerical IP address as normal.
  #     So how do we describe them? Personally I think we should always treat
  #     them as normal messages, maybe just coming from 127.0.0.1. I'm not
  #     convinced that created messages should be handled differently from
  #     messages from 127.0.0.1, as that will discourage users from doing silly
  #     things like not scanning created messages.
  #     I have changed the sendmail code so it puts in 127.0.0.1.
  #
  # OK, well I'll probably try having a look at what it would take to
  # differentiate it later, then... (i.e. put 'local' back in and see
  # what breaks)
  #
  $message->{clientip} = (exists $metadata{dv_host_address} &&
		    defined $metadata{dv_host_address})?
		      $metadata{dv_host_address}:
		      "127.0.0.1";
  $message->{clientip} =~ s/^(\d+\.\d+\.\d+\.\d+)(\..*)?/$1/;
  $message->{clientip} =~ s/^([a-f\d]*)(:[a-f\d]*){6}.*$/$1$2/;

  # Deal with b-tree of non-recipients
  $metadata{nonrcpts} = {};
  if ($line ne "XX") {
    my $nodecount=0;
    my ($branches, $address) = split / /, $line;
    $metadata{nonrcpts}{$address} = 1;
    substr($branches,0,1) eq "Y" and $nodecount++;
    substr($branches,1,1) eq "Y" and $nodecount++;
    while ($nodecount) {
      chomp($line = <$RQf>);
      unless ($line) {
        #MailScanner::Log::WarnLog("Batch: Ignoring invalid queue file for " .
        #                          "message %s", $metadata{id});
        return 0;
      }
      # $line eq "" and **** --- invalid queue file - JKF won't get here if bad
      ($branches, $address) = split / /, $line;
      $nodecount--;
      $metadata{nonrcpts}{$address} = 1;
      substr($branches,0,1) eq "Y" and $nodecount++;
      substr($branches,1,1) eq "Y" and $nodecount++;
    }
  }

# This way would actually build a b-tree to store them
# but we leave the efficiency thing to perl's hash implementation
# above.
#   if ($line ne "XX") {
#     my @nodestack;
#     my ($branches, $address) = split / /, $line;
#     my $noderef;
#     $metadata{nonrecpts}{address} = $address;
#     $metadata{nonrecpts}{l} = {};
#     $metadata{nonrecpts}{r} = {};
#     substr($branches,0,1) eq "Y" and push @nodestack,$metadata{nonrecpts}{l};
#     substr($branches,1,1) eq "Y" and push @nodestack,$metadata{nonrecpts}{r};
#     while ($#nodestack >= 0) {
#       chomp($line = <$RQf>);
#       # $line eq "" and **** --- invalid queue file
#       ($branches, $address) = split / /, $line;
#       $noderef = pop @nodestack;
#       $noderef->{address} = $address;
#       $noderef->{l} = {};
#       $noderef->{r} = {};
#       substr($branches,0,1) eq "Y" and push @nodestack,$noderef->{l};
#       substr($branches,1,1) eq "Y" and push @nodestack,$noderef->{r};
#     }
#   }

  # Get number of recipients
  chomp($metadata{numrcpts} = <$RQf>);
  #print STDERR "Number of recips = " . $metadata{numrcpts} . "\n";

  # Read in recipient list
  for (my $i=0; $i<$metadata{numrcpts};$i++) {
    chomp($line = <$RQf>);
    #print STDERR "Read $line\n";
    unless (defined $line && $line ne "") {
      #MailScanner::Log::WarnLog("Batch: Ignoring invalid queue file for " .
      #                          "message %s", $metadata{id});
      return 0;
    }
    # $line eq "" and ***** -- invalid queue file
    push @{$metadata{rcpts}}, $line;
    unless (exists $metadata{nonrcpts}{$line}) {
      # Add recipient to message data
      # but deal with "special" lines first
      # (when "one_time" option is being used)
      # strips old "special" content <4.10
      #print STDERR "Line before1 = **$line**\n";
      $line =~ s/ \d+,\d+,\d+$//;
      #BROKEN # strips new "special" content >= 4.10
      #BROKEN $line =~ s/ (\d+),\d+#01$//;
      #BROKEN if (defined $1) {
      #BROKEN   $line = substr($line, 0, length($line)-$1-1);
      #BROKEN }
      # Patch contributed by Simon Walter.
      # strips new "special" content >= 4.10
      #print STDERR "Line before2  = **$line**\n";
      if ($line =~ s/ (\d+),\d+#1$//) {
        #print STDERR "Line after 2  = **$line**\n";
        #print STDERR "Dollar 1 = **$1**\n";
        #print STDERR "Length   = **" . length($line) . "**\n";
        $line = substr($line, 0, length($line)-$1-1) if defined $1;
      }
      #print STDERR "Line after 1  = **$line**\n";

      push @{$message->{to}}, $line;
    }
  }

  # This line should be blank
  chomp($line = <$RQf>);
  if ($line) {
    #MailScanner::Log::WarnLog("Batch: Ignoring invalid queue file for " .
    #                          "message %s", $metadata{id});
    return 0;
  }

  # Now the message headers start
  $InHeader = 0;
  $InSubject = 0;
  $InDel = 0;

  # OK, don't let's confuse envelope and header data.
  # None of these headers are actually used to determine where
  # to deliver or anything like that.
  # $message->{headers} should be an array of message header lines,
  # and is (to be) regarded as RO.
  # $metadata{headers} on the other hand needs to contain *all*
  # information necessary to regenerate a queue file, so needs to
  # track Exim's flags on the headers. %metadata will/must only
  # be modified by functions in this package.
  #
  # I thought this loop was ugly when I wrote it... I've tidied
  # it up a bit, but its beauty is only skin-deep, if that.
  # --nwp

  my $header = {};
  while (<$RQf>) {
    # chomp()ing here would screw the header length calculations
    $line = $_;
    $line =~ s/\0//g; # Delete all null bytes

    if ($InHeader) {

      # We are expecting a continuation line...
      $InHeader -= (length($line));
      if ($InHeader < 0) {
	MailScanner::Log::NoticeLog("Header ($line) too long (wanted " .
                     "$InHeader) -- using it anyway!!");
	$InHeader = 0;
      }
      $line =~ /^[\t ]/
	or MailScanner::Log::NoticeLog("Header continuation ($line) doesn't" .
                        " begin with LWSP -- using it anyway!!");

      # Push line onto simple @headers array unless it's one
      # that Exim's flagged as deleted...
      push @headers, $line unless $InDel;

      # Add it to metadata header object too.
      $header->{body} .= $line;

      # Is this header one that we need to have directly available
      # (currently only subject)
      $InSubject and chomp($message->{subject} .= $line);

      # Track whether we're still in the middle of anything
      $InDel = ($InDel && $InHeader);
      $InSubject = ($InSubject && $InHeader);

      # Very important
      next;
    }

    # Looking for first line of a header...
    if ($line =~ /^([\d]{3,})([A-Z* ]) (.*)/s) {
      # If we've got a header built, push it onto metadata
      # headers array and clear the decks ready to build
      # another one.
      if (exists $header->{name}) {
	push @{$metadata{headers}},$header;
	$header = {};
      }
      # Has Exim flagged this header as deleted?
      $InDel = ((my $flagchar = $2) eq '*');
      # got one... track length
      $InHeader = $1 - (length($3));
      if ($InHeader < 0) {
	MailScanner::Log::WarnLog("Header too long! -- using it anyway!!");
	$InHeader = 0;
      }
      my $headerstring = $3;
      # Actually header names *MUST* only contain
      # ASCII 33-126 decimal inclusive...
      # ...but we'll be gentle, just in case.
      # Note that spaces are *not* required after the colon,
      # and if present are considered to be part of the field
      # data, so must not be (carelessly) modified. *shrug*.
      # We *do* want newlines to be included in $2, hence
      # /s modifier and use of \A and \Z instead of ^ and $.
      # Note that we have (arbitrarily, we think) decided to
      # count the delimiting colon as part of the field name.
      $headerstring =~ /\A([^: ]+:)(.*)\Z/s; # or *****
      $header->{name} = $1;
      $header->{body} = $2;
      $header->{flag} = $flagchar;
      $metadata{vanishedflags}{$flagchar} = 0;

      # Ignore it if it's flagged as deleted
      unless ($InDel) {
	# It's not deleted, so push it onto headers array
	push @headers, $headerstring;
	# And if it's the subject, deal with it + track it
	if ("subject:" eq lc $1) {
	  # Make $metadata{subject} and the relevant header
	  # entry point to the same object, just to save hunting
	  # for it later.
	  $metadata{subject} = $header;
	  # And just stick an unfolded string into message subject
	  # attribute.
	  chomp($message->{subject} = $2);
	  $InSubject = 1;
	}
        if ("received:" eq lc $1) {
          my $received = $2;
          my $rcvdip = '127.0.0.1';
          if ($received =~ /\[(\d+\.\d+\.\d+\.\d+)\]/i) {
            $rcvdip = $1;
            #unless ($read1strcvd) {
            #  $ipfromheader = $1;
            #  $read1strcvd = 1;
            #}
          } elsif ($received =~ /\[([\dabcdef.:]+)\]/i) {
            $rcvdip = $1;
            #unless ($read1strcvd) {
            #  $ipfromheader = $1;
            #  $read1strcvd = 1;
            #}
          }
          push @rcvdiplist, $rcvdip;
        }
      }
      # Track anything we may be in the middle of
      $InDel = ($InDel && $InHeader);
      $InSubject = ($InSubject && $InHeader);
      next;
    }

    # Weren't expecting a continuation, but didn't find
    # something that looked like the first line of a header
    # either...
    MailScanner::Log::WarnLog("Apparently invalid line in queue file!".
		 "- continuing anyway.");
  }

  # If we were told to read the IP from the header and it was there...
  $getipfromheader = @rcvdiplist if $getipfromheader>@rcvdiplist;
  # If they wanted the 2nd Received from address, give'em element 1 of list
  $message->{clientip} = $rcvdiplist[$getipfromheader-1] if
    $getipfromheader>0;

  #$message->{clientip} = $ipfromheader
  #  if $getipfromheader && $read1strcvd && $ipfromheader ne "";

  # We should have the last header built but not pushed
  # onto the metadata headers array at this point...
  exists $header->{name} and push @{$metadata{headers}},$header;

  # Decode ISO subject lines into UTF8
  # Needed for UTF8 support in MailWatch 2.0
  eval {
   $message->{utf8subject} = Encode::decode('MIME-Header',$message->{subject});
  };
  if($@) {
   # Eval failed - store a copy of the subject before MIME::WordDecoder
   # is run, as this appears to destroy the characters of some subjects
   $message->{utf8subject} = $message->{subject};
  }

  # Decode the ISO encoded Subject line
  # Over-ride the default default character set handler so it does it
  # much better than the MIME-tools default handling.
  MIME::WordDecoder->default->handler('*' => \&MailScanner::Message::WordDecoderKeep7Bit);
  # Decode the ISO encoded Subject line

  # Remove any wide characters so that WordDecoder can parse
  # mime_to_perl_string is ignoring the built-in handler that was set earlier
  # https://github.com/MailScanner/v5/issues/253
  my $safesubject = $message->{subject};
  $safesubject =~  tr/\x00-\xFF/#/c;

  my $TmpSubject;
  eval {
    $TmpSubject = MIME::WordDecoder::mime_to_perl_string($safesubject);
  };
  if ($@) {
    # Eval failed - return unaltered subject
    $TmpSubject = $message->{subject};
  }
  if ($TmpSubject ne $message->{subject}) {
    # The mime_to_perl_string function dealt with an encoded subject, as it did
    # something. Allow up to 10 trailing spaces so that SweepContent
    # is more kind to us and doesn't go and replace the whole subject,
    # thinking that it is malicious. Total replacement and hence
    # destruction of unicode subjects is rather harsh when we are just
    # talking about a few spaces.
    $TmpSubject =~ s/ {1,10}$//;
    $message->{subject} = $TmpSubject;
  }
  #old $message->{subject} = MIME::WordDecoder::unmime($message->{subject});

  # I'd prefer that $message->{headers} not exist;
  # it's an incitement to do bad things that defeat
  # the point of hiding the internal implementation
  # of the object.
  chomp @headers; # :(
  $message->{headers} = \@headers;
  $message->{metadata} = \%metadata;

  #print STDERR Dumper($message->{metadata});
  return 1;
}

# FIXME: Check out requesting no dsn via esmtp - can't see how spool
# can record this data.

# Merge header data from @headers into metadata :(

sub AddHeadersToQf {
  my($this, $message, $headers) = @_;
  
  my($header, $h, @newheaders);
  
  #print STDERR Dumper($message->{headers});

  if (defined $headers) {
    @newheaders = split(/\n/, $headers);
  } else {
    @newheaders = @{$message->{headers}};
  }

  return RealAddHeadersToQf($this,$message,\@newheaders);
}


sub RealAddHeadersToQf {
  my ($this, $message, $headerref) = @_;

  my @newheaders = @$headerref;

  # Out-of-date comment but still explains problem.

  # Would prefer to be taking in an explicitly passed array
  # and do away with $message->{headers} altogether.
  
  # Could use $message->Headers to return an arrayref if/
  # when necessary, then call this with the ref if/when you
  # want to merge them back in.

  # Essentially I'd like the headers to be considered "ours",
  # to be modified one-at-a-time via the method provided
  # (AddHeader, ReplaceHeader, DeleteHeader etc.)

  # But using MIME::tools makes this impossible, as they do
  # not distinguish between "their" headers and "our" headers,
  # and just return us a whopping great string of all of them.

  # Grrrrrrrr.....

  # OK, we'll assume & hope that the "special" flags Exim
  # gives headers aren't important to it, and just pull in
  # the headers that we're given. This offends my delicate
  # sensibilities, but I need to get this working *soon*.

  # --nwp 20021006

  my @realheaders = ();
  my $header = {};
  my $line;

  # :(
  $message->{metadata}{headers} = [];

  my $InHeader = 0;
  my $InSubject = 0;
  my $InDel = 0;

  foreach (@newheaders) {
    # This line to identify problems rather than just work
    # round them (which costs efficiency).
    s/\n\Z// and MailScanner::Log::DieLog("BUG! header line '$_' should not have newline.");
    
    # This line for safety but inefficiency
    chomp($line = $_);

    if ($InHeader && ($line =~ /^[\t ]/)) {
      
      # Continuation
      
      # Add it to metadata header object (already
      # built the rest)
      $header->{body} .= $line . "\n";
      
      # Don't reset $InHeader as there could be more lines.

      # Very important
      next;
    }
    elsif ($line =~ /^([^: ]+:)(.*)$/) {
      # Actually header names *MUST* only contain
      # ASCII 33-126 decimal inclusive...
      # ...but we'll be gentle, just in case.
      # Note that spaces are *not* required after the colon,
      # and if present are considered to be part of the field
      # data, so must not be (carelessly) modified. *shrug*.
      # We shouldn't have any terminating newlines at this point.
      # Note that we have (arbitrarily, we think) decided to
      # count the delimiting colon as part of the field name.

      # Push any previous header to right place...
      if ($InHeader) {
	push @{$message->{metadata}{headers}}, $header;
	$header = {};
      }

      # Set up new header
      $InHeader = 1;
      $header->{name} = $1;
      $header->{body} = $2 . "\n";
      # Ugly ugly ugly
      $header->{flag} = " ";
      
      # Important
      next;
    }
    else {
      # Not a continuation and not a valid header start
      MailScanner::Log::WarnLog("Don't know what to do with line '$line' in header array!");
      $InHeader = 0;
    }
  }

  # We should have the last header built but not pushed
  # onto the metadata headers array at this point...
  exists $header->{name} and push @{$message->{metadata}{headers}},$header;
  
  # Since we've just generated a bunch of headers with no "special"
  # flags, note that they've *all* gone missing:
  foreach (keys %{$message->{metadata}{vanishedflags}}) {
    $message->{metadata}{vanishedflags}{$_} = 1;
  }

  return 1;
}


sub AddStringOfHeadersToQf {
  my ($this, $message, $headers) = @_;

  my @headers;

  @headers = split(/\n/, $headers);

  return RealAddHeadersToQf($this, $message, \@headers);
}


sub AddHeader {
  my($this, $message, $newkey, $newvalue) = @_;
  my($newheader);

  # need an equivalent to "assert"...
  #defined $newvalue or croak("not enough args to AddHeader!\n");
  # Sometimes the spam report is undef
  $newvalue = " " unless defined $newvalue;

  # Sanitise new header value - one leading space and one trailing newline.
  #$newvalue = ((substr($newvalue,0,1) eq " ")?$newvalue:" $newvalue");
  $newvalue =~ s/^ */ /;
  $newvalue =~ s/\n*\Z/\n/;

  $newheader = { name => $newkey, body => $newvalue, flag => " " };
  # DKIM: Add header at top if adding headers at top
  if ($message->{newheadersattop}) {
    unshift @{$message->{metadata}{headers}}, $newheader;
  } else {
    push @{$message->{metadata}{headers}}, $newheader;
  }

  return 1;
}


# This is how we build the entry that goes in the -H file
#    sprintf("%03d  ", length($newheader)+1) . $newheader . "\n";


# Delete a header from the message's metadata structure
sub DeleteHeader {
  my($this, $message, $key) = @_;

  my $usingregexp = ($key =~ s/^\/(.*)\/$/$1/)?1:0;

  # Add a colon if they forgot it.
  $key .= ':' unless $usingregexp || $key =~ /:$/;
  # If it's not a regexp, then anchor it and sanitise it.
  $key = quotemeta($key) unless $usingregexp;

  # Delete header by flagging it as deleted rather than by
  # actually deleting it; might help with debugging.
  # Also keep track of any flags that we've managed to "vanish".
  my($hdrnum, $line);
  my $metadata = $message->{metadata};
  for ($hdrnum=0; $hdrnum<@{$metadata->{headers}}; $hdrnum++) {
    # Skip if they are using a header name and it doesn't match
    # Quotemeta the header name we are checking as we have done it to $key.
    next if !$usingregexp &&
            lc(quotemeta($metadata->{headers}[$hdrnum]{name})) ne lc $key;
    # Skip if they are using a regexp and it doesn't match
    $line = $metadata->{headers}[$hdrnum]{name} . $metadata->{headers}[$hdrnum]{body};
    next if $usingregexp && $line !~ /$key/i;
    # Have found the right line
    $metadata->{headers}[$hdrnum]{flag} ne " "
      and $metadata->{vanishedflags}{$metadata->{headers}[$hdrnum]{flag}} = 1;
    $metadata->{headers}[$hdrnum]{flag} = "*";
  }
}

sub UniqHeader {
  my($this, $message, $key) = @_;

  my $hdrnum;
  my $foundat = -1;
  my $metadata = $message->{metadata};
  for ($hdrnum=0; $hdrnum<@{$metadata->{headers}}; $hdrnum++) {
    next unless lc $metadata->{headers}[$hdrnum]{name} eq lc $key;

    # Have found the header line, skip it if we haven't seen it before
    ($foundat = $hdrnum), next if $foundat == -1;

    # Have found the right line
    $metadata->{headers}[$hdrnum]{flag} ne " "
      and $metadata->{vanishedflags}{$metadata->{headers}[$hdrnum]{flag}} = 1;
    $metadata->{headers}[$hdrnum]{flag} = "*";
  }
}


# We need to delete *all* instances of the header in
# question, as this is used e.g. to replace previous
# mailscanner disposition headers with the "right" one,
# and we don't want lots of old ones left lying aorund.
# Shame, as it means I will have to regenerate header
# flags on output.

sub ReplaceHeader {
  my($this, $message, $key, $newvalue) = @_;

  # DKIM: Don't do DeleteHeader if adding all headers at top
  $this->DeleteHeader($message, $key) unless $message->{dkimfriendly};
  $this->AddHeader($message, $key, $newvalue);

  return 1;
}


# Return a reference to a header object called "$name"
# (case-insensitive)
# FOR INTERNAL USE ONLY

sub FindHeader {
  my($this, $message, $name, $includedeleted) = @_;

  defined $includedeleted or $includedeleted = 0;

  $includedeleted and $includedeleted = 1;

  for (my $ignoreflag = 0;
       $ignoreflag < 1 + $includedeleted;
       $ignoreflag++) {
    foreach (@{$message->{metadata}{headers}}) {
      lc $_->{name} eq lc $name and ($ignoreflag or $_->{flag} ne '*') and return $_;
    }
  }

  return undef;
}


sub AppendHeader {
  my($this, $message, $key, $newvalue, $sep) = @_;

  my $header = FindHeader($this, $message, $key);

  if (defined $header) {
    # Found it :)
    chomp($header->{body});
    $header->{body} .= $sep . $newvalue . "\n";
  }
  else {
    # Didn't find it :(
    $this->AddHeader($message, $key, $newvalue);
  }
  return 1;
}


sub PrependHeader {
  my($this, $message, $key, $newvalue, $sep) = @_;

  my $header = FindHeader($this, $message, $key);

  if (defined $header) {
    # Found it :)
    #$header->{body} = $newvalue . $sep . $header->{body};
    chomp($header->{body});
    $header->{body} =~ s/^($sep|\s)*/ $newvalue$sep/;
    $header->{body} .= "\n";
  }
  else {
    # Didn't find it :(
    $this->AddHeader($message, $key, $newvalue);
  }
  return 1;
}


sub TextStartsHeader {
  my($this, $message, $key, $text) = @_;

  my $header = FindHeader($this, $message, $key);

  if (defined $header) {
    return (($header->{body} =~ /^\s*\Q$text\E/i)?1:0);
  }
  else {
    return 0;
  }
}

sub TextEndsHeader {
  my($this, $message, $key, $text) = @_;

  my $header = FindHeader($this, $message, $key);

  if (defined $header) {
    return (($header->{body} =~ /\Q$text\E$/i)?1:0);
  }
  else {
    return 0;
  }
}


#sub ConstructHeaders {
#  my($headers) = @_;
#  $headers =~ s/^\S/H$&/mg;
#  return $headers;
#}

#sub ReadEnvelope {
#  my($fh) = @_;
#  my $envelope = "";
#
#  while(<$fh>) {
#    last if /^\./; # Bat book section 23.9.19
#    $envelope .= $_;
#  }
#  return $envelope;
#}

#sub SplitEnvelope {
#  my($envelope) = @_;
#
#    my ($headers,$newenvelope);
#    my(@envelope) = split "\n", $envelope;
#
#    my $InHeader = 0;
#
#    while($_ = shift @envelope) {
#      last if /^\./; # Bat book section 23.9.19
#      if (/^H/) {
#        $InHeader = 1;
#        $headers .= "$_\n";
#        next;
#      }
#      if (/^\s/ && $InHeader) {
#        $headers .= "$_\n";
#        next;
#      }
#      $InHeader = 0;
#      $newenvelope .= "$_\n";
#    }
#
#    return ($newenvelope,$headers);
#  }

#  sub MergeEnvelope {
#    my ($envelope,$headers) = @_;
#    return "$envelope$headers.\n";
#  }

#  sub MergeEnvelopeParts {
#    my($fh, $headers) = @_;
#
#    my $envelope = "";
#    my $InHeader = 0;
#
#    while(<$fh>) {
#      last if /^\./; # Bat book section 23.9.19
#      ($InHeader = 1),next if /^H/;
#      next if /^\s/ && $InHeader;
#      $InHeader = 0;
#      $envelope .= $_;
#    }
#
#    $envelope .= $headers;
#    $envelope .= ".\n";
#    return $envelope;
#  }


# FIXME: Document what format are we supposed to be passed
# recipients in (assuming just plain email address, no quotes,
# no angle brackets, no nuffin' for now)...

sub AddRecipients {
  my $this = shift;
  my($message, @recips) = @_;
  my($recip);
  foreach $recip (@recips) {
    $message->{metadata}{numrcpts}++;
    push @{$message->{metadata}{rcpts}}, "$recip";
    exists $message->{metadata}{nonrpcts}{$recip} and
      delete $message->{metadata}{nonrpcts}{$recip};
  }
}


# Delete recipient from recipient list unless they are already
# also on nonrcpt list?

# Delete the original recipient from the message. We'll add some
# using AddRecipients later.

sub DeleteRecipients {
  my $this = shift;
  my($message) = @_;

  $message->{metadata}{numrcpts} = 0;
  $message->{metadata}{rcpts} = [];
  $message->{metadata}{nonrcpts} = {};

  return 1;
}


# Ask MTA to deliver message(s) from queue

sub KickMessage {
  my $pid;
  my($messages, $sendmail2) = @_;
  my(@ids, @ThisBatch);
  # Build a list @ids of all the message ids
  foreach (values(%{$messages})) {
    push @ids, split(" ", $_);
  }

  while(@ids) {
    @ThisBatch = splice @ids, $[, 30;

    # This code is the simpler version of the #JJH code below here.
    my $idlist = join(' ', @ThisBatch);
    $idlist .= ' &' if MailScanner::Config::Value('deliverinbackground');
    #print STDERR "About to do \"Sendmail2 -Mc $idlist\"\n";
    # Change out of the current working directory that no longer exists
    # before calling exim
    system('cd ' . MailScanner::Config::Value('outqueuedir') . ' && ' . 
        MailScanner::Config::Value('sendmail2') . ' -Mc ' . $idlist);

    #JJH # JJH's version
    #JJH if(MailScanner::Config::Value('deliverinbackground')) {
      #JJH # fork twice so that we don't have to reap :-)
      #JJH $pid = fork;
      #JJH # jjh 2004-03-12 don't waitpid here, too slow.
      #JJH #waitpid $pid, 0 if $pid > 0;
      #JJH return if $pid > 0 or not defined $pid;
      #JJH $pid = fork;
      #JJH exit if $pid > 0 or not defined $pid;
      #JJH exec(split(/ +/, MailScanner::Config::Value('sendmail2')), '-Mc', @ThisBatch);
    #JJH } else {
      #JJH system(split(/ +/, MailScanner::Config::Value('sendmail2')), '-Mc', @ThisBatch);
    #JJH }
  }

}


# Serialize metadata into a string for output into
# -H file...
# INTERNAL USE ONLY

sub CreateQf {
  my($message) = @_;

  my $i;
  my $Qfile = "";
  my $metadata = $message->{metadata};

  # Add id line
  $Qfile .= $metadata->{id}. "\n";
  
  # Add user, uid, gid line
  $Qfile .= $metadata->{user} . " ";
  $Qfile .= $metadata->{uid} . " ";
  $Qfile .= $metadata->{gid} . "\n";

  # Add sender line
  $Qfile .= '<' . $metadata->{sender} . ">\n";
  # JKF Need the < and > round the sender $Qfile .= $metadata->{sender} . "\n";

  # Add time received and warning count
  $Qfile .= $metadata->{rcvtime} . " ";
  $Qfile .= $metadata->{warncnt} . "\n";

  # Add -<item_name> lines
  foreach (keys %{$metadata->{dashvars}}) {
    $Qfile .= "-" . $_;
    $metadata->{dashvars}{$_} and $Qfile .= " " . $metadata->{"dv_$_"};
    $Qfile .= "\n";
  }

  # ACLs patch starts here
  # Add the separate ACL Vars
  my %acl  = %{$metadata->{aclvars}};
  my %aclc = %{$metadata->{aclcvars}};
  my %aclm = %{$metadata->{aclmvars}};
  foreach(keys %acl){
    if($acl{$_}) {
      $Qfile .= "-acl " . $_ . " " . length($acl{$_}->[0]) . "\n";
      $Qfile .= $acl{$_}->[0] . "\n";
    }
  }
  foreach(keys %aclc){
    if($aclc{$_}) {
      $Qfile .= "-aclc " . $_ . " " . length($aclc{$_}->[0]) . "\n";
      $Qfile .= $aclc{$_}->[0] . "\n";
    }
  }
  foreach(keys %aclm){
    if($aclm{$_}) {
      $Qfile .= "-aclm " . $_ . " " . length($aclm{$_}->[0]) . "\n";
      $Qfile .= $aclm{$_}->[0] . "\n";
    }
  }

  # Add non-recipients
  $Qfile .= BTreeString($metadata->{nonrcpts});

  # Add number of recipients
  $Qfile .= $metadata->{numrcpts} . "\n";

  # Add recipients
  foreach (@{$metadata->{rcpts}}) {
    $Qfile .= "$_\n";
  }

  # Add blank line
  $Qfile .= "\n";

  # Add headers from $metadata->{headers}...
  # First we need to check the "special" flags.
  # Then we need to write out headers to a
  # string, calculating length as we go.
  my %flags = ();
  foreach (keys %{$metadata->{vanishedflags}}) {
    $metadata->{vanishedflags}{$_} and FindAndFlag($metadata->{headers}, "$_");
  }
#  MailScanner::Log::InfoLog(Dumper($metadata->{headers}));
  foreach (@{$metadata->{headers}}) {
    my $htext = $_->{name} . $_->{body};
    # We want exactly one \n at the end of each header
    # but this *should* be inefficient and unnecessary
    # $htext =~ s/\n*\Z/\n/;
    $Qfile .= sprintf("%03d", length($htext)) . $_->{flag} . ' ' . $htext;
  }

  return $Qfile;
}


# Find relevant header and flag it as special
# INTERNAL USE ONLY

sub FindAndFlag {
  my ($headerary, $flag) = @_;

  # Must be lower-case
  my %headers = (
		 B => "bcc",
		 C => "cc",
		 F => "from",
		 I => "message-id",
		 R => "reply-to",
		 S => "sender",
		 T => "to",
		 P => "received",
		); 
  
  # We don't do:
  # * - deleted
  #   - nothing special
  # We should only be asked to do message-id if there
  # definitely was one flagged to start with...
  $flag =~ /[BCFIRSTP]/ or return 0;
 
  my $foundone = 0;
  foreach (@$headerary) {
      
    $_->{flag} ne " " and next;
    $headers{uc($flag)}.":" eq lc $_->{name} or next;

    # OK, found one
    $foundone = 1;
    $_->{flag} = $flag;
    # End if we only want one of this header
    $flag ne 'R' and last;
  }

  return $foundone;
}


# Build string representing a balanced b-tree
# of the keys of the hash passed in.
# INTERNAL USE ONLY

sub BTreeString {
  my ($hashref) = @_;

  my $treeref = BTreeHash($hashref);

  my $treestring = BTreeDescend($treeref);

  $treestring or $treestring = "XX\n";

  return $treestring;
}


# Build a not-too-unbalanced b-tree from keys of a
# hash and return a reference to the tree.
# INTERNAL USE ONLY

sub BTreeHash {
  my ($hashref) = @_;

  my @nodes = keys %$hashref;
  my $treeref = {};
  my @nodequeue = ($treeref);
  my $data;
  my $currentnode;

  while ($data = pop @nodes) {
    $currentnode = pop @nodequeue
      or MailScanner::Log::DieLog("Ran out of nodes in BTreeHash - shouldn't happen!");
    unshift @nodequeue, ($currentnode->{left} = {});
    unshift @nodequeue, ($currentnode->{right} = {});
    $currentnode->{data} = $data;
  }

  return $treeref;
}


# Descend a b-tree passed in a hash reference,
# generating a string representing the tree
# as we go.
# INTERNAL USE ONLY

sub BTreeDescend {
  my ($treeref) = @_;

  exists $treeref->{data} or return "";

  my $string = "";
  $string .= (exists $treeref->{left}{data}?"Y":"N");
  $string .= (exists $treeref->{right}{data}?"Y":"N");
  $string .= " " . $treeref->{data} . "\n";

  $string .= BTreeDescend($treeref->{left});
  $string .= BTreeDescend($treeref->{right});

  return $string;
}


# Append, add or replace a given header with a given value.
sub AddMultipleHeaderName {
  my $this = shift;
  my($message, $headername, $headervalue, $separator) = @_;

  my($multiple) = MailScanner::Config::Value('multipleheaders', $message);
  $this->AppendHeader ($message, $headername, $headervalue, $separator)
    if $multiple eq 'append';

  $this->AddHeader    ($message, $headername, $headervalue)
    if $multiple eq 'add';

  $this->ReplaceHeader($message, $headername, $headervalue)
    if $multiple eq 'replace';
}

# Append, add or replace a given header with a given value.
sub AddMultipleHeader {
  my $this = shift;
  my($message, $headername, $headervalue, $separator) = @_;

  my($multiple) = MailScanner::Config::Value('multipleheaders', $message);
  $this->AppendHeader ($message,
		       MailScanner::Config::Value(lc($headername), $message),
		       $headervalue, $separator)
    if $multiple eq 'append';

  $this->AddHeader    ($message,
		       MailScanner::Config::Value(lc($headername), $message),
		       $headervalue)
    if $multiple eq 'add';

  $this->ReplaceHeader($message,
		       MailScanner::Config::Value(lc($headername), $message),
		       $headervalue)
    if $multiple eq 'replace';
}


# Send an email message containing all the headers and body in a string.
# Also passed in the sender's address.
sub SendMessageString {
  my $this = shift;
  my($message, $email, $sender) = @_;

  my($fh);

  #print STDERR '|' . MailScanner::Config::Value('sendmail', $message) .
  #          ' ' . $SendmailOptions . '-f ' . "'$sender'" . "\n";
  #$fh = new FileHandle;
  #$fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
  #          " $SendmailOptions '" . $sender . "'")

  $fh = new IO::Pipe;
  $fh->writer(split(/ +/, MailScanner::Config::Value('sendmail', $message)),
              @SendmailOptions, $sender)
    or MailScanner::Log::WarnLog("Could not send email message, %s", $!), return 0;
  #$fh->open('|$global::cat >> /tmp/1');
  $fh->print($email);
  #print STDERR $email;
  #$fh->close();
  #1;

  return $fh->close();
}


# Send an email message containing the attached MIME entity.
# Also passed in the sender's address.
sub SendMessageEntity {
  my $this = shift;
  my($message, $entity, $sender) = @_;

  my($fh);

  #print STDERR  '|' . MailScanner::Config::Value('sendmail', $message) .
  #          ' ' . $SendmailOptions . '-f ' . $sender . "\n";
  #$fh = new FileHandle;
  #$fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
  #          " $SendmailOptions '" . $sender . "'")
  $fh = new IO::Pipe;
  $fh->writer(split(/ +/, MailScanner::Config::Value('sendmail', $message)),
           @SendmailOptions, $sender)
    or MailScanner::Log::WarnLog("Could not send email entity, %s", $!), return 0;
  #$fh->open('|$global::cat >> /tmp/2');
  $entity->print($fh);
  #$entity->print(\*STDERR);
  #$fh->close();
  #1;

  return $fh->close();
}


# Create a MessageBatch object by reading the queue and filling in
# the passed-in batch object.

sub CreateBatch {
  my $this = shift;
  my($batch, $onlyid) = @_;

  my($queuedirname, $queuedir, $MsgsInQueue, $mtime);
  my($DirtyMsgs, $DirtyBytes, $CleanMsgs, $CleanBytes);
  my($HitLimit1, $HitLimit2, $HitLimit3, $HitLimit4);
  my($MaxCleanB, $MaxCleanM, $MaxDirtyB, $MaxDirtyM);
  my(%ModDate, $mta, $file, $tmpdate, $invalidfiles);
  my(@SortedFiles, $id, $newmessage, @queuedirnames);
  my($batchempty, $CriticalQueueSize, $headerfileumask);
  my($getipfromheader);

  # Old code left over from single queue dir
  #$queuedirname = $global::MS->{inq}{dir};
  #chdir $queuedirname or MailScanner::Log::DieLog("Cannot cd to dir %s to read " .
  #                                   "messages, %s", $queuedirname, $!);

  $queuedir = new DirHandle;
  $MsgsInQueue = 0;
  #print STDERR "Inq = " . $global::MS->{inq} . "\n";
  #print STDERR "dir = " . $global::MS->{inq}{dir} . "\n";
  @queuedirnames = @{$global::MS->{inq}{dir}};

  ($MaxCleanB, $MaxCleanM, $MaxDirtyB, $MaxDirtyM)
                    = MailScanner::MessageBatch::BatchLimits();
  #print Dumper(\@queuedirnames);

  # If there are too many messages in the queue, start processing in
  # directory storage order instead of date order.
  $CriticalQueueSize = MailScanner::Config::Value('criticalqueuesize');
  $getipfromheader = MailScanner::Config::Value('getipfromheader');

  # Set what we will need the umask to be
  $headerfileumask = $global::MS->{work}->{fileumask};

  do {
    $batch->{messages} = {};
    # Statistics logging
    $batch->{totalbytes} = 0;
    $batch->{totalmessages} = 0;

    #
    # Now do the actual work
    #
    $MsgsInQueue= 0;
    $DirtyMsgs  = 0;
    $DirtyBytes = 0;
    $CleanMsgs  = 0;
    $CleanBytes = 0;
    %ModDate = ();
    @SortedFiles = ();
    $HitLimit1  = 0;
    $HitLimit2  = 0;
    $HitLimit3  = 0;
    $HitLimit4  = 0;
    $invalidfiles = "";

    # Loop through each of the inq directories
    # Patch to combat starving in emergency queue mode
    #foreach $queuedirname (@queuedirnames) {
    my @aux_queuedirnames=@queuedirnames;
    while( defined($queuedirname=splice(@aux_queuedirnames,
        ($UnsortedBatchesLeft<=0 ? 0 :int(rand(@aux_queuedirnames))),1))) {
      
      # FIXME: Probably as a result of in-queue spec being
      # tainted, $queuedirname is tainted... work out exactly why!
      $queuedirname =~ /(.*)/;
      $queuedirname = $1;

      #print STDERR "Scanning dir $queuedirname\n";
      unless (chdir $queuedirname) {
	MailScanner::Log::WarnLog("Cannot cd to dir %s to read messages, %s",
		     $queuedirname, $!);
	next;
      }

      $queuedir->open('.')
	or MailScanner::Log::DieLog("Cannot open queue dir %s for reading " .
				    "message batch, %s", $queuedirname, $!);
      $mta = $global::MS->{mta};
      #print STDERR "Searching " . $queuedirname . " for messages\n";

      # Read in modification dates of the qf files & use them in date order
      while (defined($file = $queuedir->read())) {
	# Optimised by binning the 50% that aren't H files first
	next unless $file =~ /$mta->{HFileRegexp}/;
	#print STDERR "Found message file $file\n";
	$MsgsInQueue++;		# Count the size of the queue
        push @SortedFiles, "$queuedirname/$file";
        if ($UnsortedBatchesLeft<=0) {
          # Running normally
          $tmpdate = (stat($file))[9]; # 9 = mtime
          next unless -f _;
          next if -z _;		# Skip 0-length qf files
          $ModDate{"$queuedirname/$file"} = $tmpdate; # Push msg into list
          #print STDERR "Stored message file $file\n";
        }
      }
      $queuedir->close();
    }

    # Not sorting the queue will save us considerably more time than
    # just skipping the sort operation, as it will enable the next bit
    # of code to just use the files nearest the beginning of the directory.
    # This should make the directory lookups much faster on filesystems
    # with slow directory lookups (e.g. anything except xfs).
    $UnsortedBatchesLeft = 40
      if $CriticalQueueSize>0 && $MsgsInQueue>=$CriticalQueueSize;
    # SortedFiles is array of full pathnames now, not just filenames
    if ($UnsortedBatchesLeft>0) {
      $UnsortedBatchesLeft--;
    } else {
      @SortedFiles = sort { $ModDate{$a} <=> $ModDate{$b} } keys %ModDate;
    }

    $batchempty = 1;
    my $maxattempts = MailScanner::Config::Value('procdbattempts');

    # Keep going until end of dir or have reached every imposed limit. This
    # now processes the files oldest first to make for fairer queue cleanups.
    umask $headerfileumask; # Started creating files
    while (defined($file = shift @SortedFiles) &&
	   $HitLimit1+$HitLimit2+$HitLimit3+$HitLimit4<1) {
      # In accelerated mode, so we don't know anything about this file
      if ($UnsortedBatchesLeft>0) {
        my @stats = stat $file;
        next unless -f _;
        next if     -z _;
        $mtime = $stats[9];
      } else {
        $mtime = $ModDate{$file};
      }

      # must separate next two lines or $1 gets re-tainted by being part of
      # same expression as $file [mumble mumble grrr mumble mumble]
      #print STDERR "Reading file $file from list\n";
      # Split pathname into dir and file again
      ($queuedirname, $file) = ($1,$2) if $file =~ /^(.*)\/([^\/]+)$/;
      next unless $file =~ /$mta->{HFileRegexp}/;
      $id = $1;
      # If they want a particular message id, ignore it if it doesn't match
      next if $onlyid ne "" && $id ne $onlyid;

      #print STDERR "Adding $id to batch\n";

      # Lock and read the qf file. Skip this message if the lock fails.
      $newmessage = MailScanner::Message->new($id, $queuedirname,
                                              $getipfromheader);
      if ($newmessage && $newmessage->{INVALID}) {
      #if ($newmessage eq 'INVALID') {
        $invalidfiles .= "$id ";
        undef $newmessage;
        next;
      }
      next unless $newmessage;
      $newmessage->WriteHeaderFile(); # Write the file of headers

      # JKF 20090301 Skip this message if $id has been scanned
      # too many times.
      # JKF 20090301 Read the number of times this message id has
      # been processed. If over the limit, then ignore it.
      # JKF 20090301 Should ideally make it in a batch of its own,
      # and try that once or twice, *then* skip it. But let's try
      # a simple version first.
      # Just do a "next" if we want to skip the message.
      if ($maxattempts) {
        my $nexttime = time + 120 + int(rand(240)); # 4 +- 2 minutes
        #my $nexttime = time + 10 + int(rand(20)); # 4 +- 2 minutes
        my @attempts = $MailScanner::ProcDBH->selectrow_array(
                         $MailScanner::SthSelectRows, undef, $id);
        #my @attempts = $MailScanner::ProcDBH->selectrow_array(
        #"SELECT id,count,nexttime FROM processing WHERE (id='" . $id . "')");
        #print STDERR "id       = \"$attempts[0]\"\n";
        #print STDERR "count    = \"$attempts[1]\"\n";
        #print STDERR "nexttime = \"$attempts[2]\"\n";
        if (@attempts && $attempts[1]>=$maxattempts) {
          MailScanner::Log::WarnLog("Warning: skipping message %s as it has been attempted too many times", $id);
          # JKF 20090301 next;
          # Instead of just skipping it, quarantine it and notify
          # the local postmaster.
          $newmessage->QuarantineDOS();
          #print STDERR "Moving $attempts[0], $attempts[1], $attempts[2] into archive table\n";
          $MailScanner::SthDeleteId->execute($id);
          #$MailScanner::ProcDBH->do(
          #  "DELETE FROM processing WHERE id='" . $id . "'");
          $MailScanner::SthInsertArchive->execute($attempts[0], $attempts[1],
                                             $attempts[2]);
          #$MailScanner::ProcDBH->do(
          #  "INSERT INTO archive (id, count, nexttime) " .
          #  "VALUES ('$attempts[0]', $attempts[1], $attempts[2])");
        } elsif (defined $attempts[1]) {
          # We have tried this message before
          if (time>=$attempts[2]) {
            # Time for next attempt has arrived
            $MailScanner::SthIncrementId->execute($nexttime, $id);
            #$MailScanner::ProcDBH->do(
            #  "UPDATE processing SET count=count+1, nexttime=$nexttime " .
            #  " WHERE id='" . $id . "'");
            MailScanner::Log::InfoLog(
              "Making attempt %d at processing message %s",
              $attempts[1]+1, $id);
            #print STDERR "Incremented $id\n";
          } else {
            # Not time for next attempt yet, so ignore the message
            $newmessage->DropFromBatch();
            next;
          }
        } else {
          # We have never seen this message before
          $MailScanner::SthInsertProc->execute($id, 1, $nexttime);
          #$MailScanner::ProcDBH->do(
          #  "INSERT INTO processing (id, count, nexttime) " .
          #  "VALUES ('" . $id . "', 1, $nexttime)");
          #print STDERR "Inserted $id\n";
        }
      }

      $batch->{messages}{"$id"} = $newmessage;
      $newmessage->{mtime} = $mtime;
      $batchempty = 0;

      if (MailScanner::Config::Value("scanmail", $newmessage) =~ /[12]/ ||
          MailScanner::Config::Value("virusscan", $newmessage) =~ /1/ ||
          MailScanner::Config::Value("dangerscan", $newmessage) =~ /1/) {
	$newmessage->NeedsScanning(1);
	$DirtyMsgs++;
	$DirtyBytes += $newmessage->{size};
	$HitLimit3 = 1
	  if $DirtyMsgs>=$MaxDirtyM;
	$HitLimit4 = 1
	  if $DirtyBytes>=$MaxDirtyB;
        # Moved this further up
	#$newmessage->WriteHeaderFile(); # Write the file of headers
      } else {
	$newmessage->NeedsScanning(0);
	$CleanMsgs++;
	$CleanBytes += $newmessage->{size};
	$HitLimit1 = 1
	  if $CleanMsgs>=$MaxCleanM;
	$HitLimit2 = 1
	  if $CleanBytes>=$MaxCleanB;
        # Moved this further up
	#$newmessage->WriteHeaderFile(); # Write the file of headers
      }
    }
    umask 0077; # Safety net as stopped creating files

    # Wait a bit until I check the queue again
    sleep(MailScanner::Config::Value('queuescaninterval')) if $batchempty;
  } while $batchempty;		# Keep trying until we get something

  # Log the number of invalid messages found
  MailScanner::Log::NoticeLog("New Batch: Found invalid queue files: %s",
                            $invalidfiles)
    if $invalidfiles;
  # Log the size of the queue if it is more than 1 batch
  MailScanner::Log::InfoLog("New Batch: Found %d messages waiting",
			    $MsgsInQueue)
      if $MsgsInQueue > ($DirtyMsgs+$CleanMsgs);

  MailScanner::Log::InfoLog("New Batch: Forwarding %d unscanned messages, " .
			    "%d bytes", $CleanMsgs, $CleanBytes)
      if $CleanMsgs;
  MailScanner::Log::InfoLog("New Batch: Scanning %d messages, %d bytes",
			    $DirtyMsgs, $DirtyBytes)
      if $DirtyMsgs;

  #MailScanner::Log::InfoLog("New Batch: Archived %d $ArchivedMsgs messages",
  #                          $ArchivedMsgs)
  #  if $ArchivedMsgs;

  $batch->{dirtymessages} = $DirtyMsgs;
  $batch->{dirtybytes}    = $DirtyBytes;

  # Logging stats
  $batch->{totalmessages} = $DirtyMsgs  + $CleanMsgs;
  $batch->{totalbytes}    = $DirtyBytes + $CleanBytes;

  #print STDERR "Dirty stats are $DirtyMsgs msgs, $DirtyBytes bytes\n";
}


# Return the array of headers from this message, optionally with a
# separator on the end of each one.
# This is designed to be used to produce the input headers for the message,
# ie. the headers of the original message. It produces 1 line per list
# element, not 1 header per list element.
sub OriginalMsgHeaders {
  my $this = shift;
  my($message, $separator) = @_;

  return @{$message->{headers}} unless $separator;
  
  # There is a separator
  my($h,@result);
  foreach $h (@{$message->{headers}}) {
    push @result, $h . $separator;
  }
  return @result;

  #defined $separator or $separator = "";
  #
  #my @headers =();
  #my $header = "";
  #foreach (@{$message->{metadata}{headers}}) {
  #  chomp ($header = $_->{name}.$_->{body});
  #  $header .= $separator;
  #  push @headers, $header;
  #}
  # 
  #return @headers;
}


sub CheckQueueIsFlat {
  my ($dir) = @_;

  # FIXME: What is the purpose of this?

  return 1;
}

1;
