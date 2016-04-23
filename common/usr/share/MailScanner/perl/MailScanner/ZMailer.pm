#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: ZMailer.pm 5080 2011-02-05 19:35:17Z sysjkf $
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
#   The authors (Leonardo Helman & Mariano Absatz) can be contacted
#   by email at
#      MailScanner-devel@pert.com.ar
#      Pert Consultores
#      Argentina

package MailScanner::Sendmail;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use DirHandle;
use Encode;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5080 $, 10;

# Command-line options you need to give to sendmail to sensibly process a
# message that is piped to it. Still need to add "-f" for specifying the
# envelope sender address. This is usually local postmaster.
my $SendmailOptions = "-t -oi -oem -F MailScanner -f";
my $UnsortedBatchesLeft;


# Attributes are
#
# $HDFileRegexp                 set by new
#


# If the sendmail and/or sendmail2 config variables aren't set, then
# set them to something sensible. This will need to be different
# for Exim.
sub initialise {
# LEOH TODO: ver que se pone aca
  MailScanner::Config::Default('sendmail', '/usr/sbin/sendmail');
  MailScanner::Config::Default('sendmail2',
                               MailScanner::Config::Value('sendmail'));
  # The default action is to WARN, and return 1
  MIME::WordDecoder->default->handler('*' => \&MailScanner::Message::WordDecoderKeep7Bit);
  $UnsortedBatchesLeft = 0; # Disable queue-clearing mode
}

# Constructor.
# Takes dir => directory queue resides in
# REVISO LEOH
sub new {
  my $type = shift;
  my $this = {};

  # These need to be improved
  # No change for V4
  $this->{HDFileRegexp} = '^([\\d]+)$';

  $this->{LockType} = "flock";

  bless $this, $type;
  return $this;
}

# Required vars are:
#
# HDFileRegexp:
# A regexp that will verify that a filename is a valid
# "HDFile" name and leave the queue id in $1 if it is.
#
# LockType:
# The way we should usually do spool file locking for
# this MTA ("posix" or "flock")
#
# Required subs are:
#
# HDFileName:
# Take a queue ID and return
# filename for envelope and data queue file (input)
#
# HDOutFileName:
# Take a queue ID and return
# new id for envelope and data queue file (output)
#
# TFileName:
# Take a queue ID and return
# filename for temp queue file
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
# AddRecipients:
# Return list of QF file lines for the passed recipients, which
# are comma-separated (with optional spaces with the commas).
#
# KickMessage:
# Given id, tell MTA to make a delivery attempt.
#
# CreateQf:
# Given a Message object, return a string containing the entire
# header file for this MTA.
#

# NOTE -- These were in list above; I believe that they are
# implementation details and should not be used outside this
# file. Looking further, they appear to be commented out here
# as well as in the Exim module -- nwp
#
# Internal subs:
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

# Do conditional once at include time

#my($MTA) = MailScanner::Config::Value('mta');
#
#print STDERR "MTA is \"" . MailScanner::Config::Value('mta') . "\"\n";
#
#print STDERR "We are running zmailer\n";
#
#MailScanner::Log::InfoLog("Configuring mailscanner for zmailer...");

# No change for V4
#REVISO LEOH
sub HDFileName {
  my($this, $id) = @_;
  return "$id";
}

# Give it a temp file name, changes the file name to 
# a new one based on the inode numbering
sub HDOutFileName {
  my($file) = @_;
  my $inode=(stat($file))[1];
  return $inode;
}

# No change for V4
sub TFileName {
  my($this, $id) = @_;
  return "tf-$$-$id";
}


# Change for V4: returns lower-case $from and @to
     # REVISO LEOH
sub ReadQf {
  my($this, $message, $getipfromheader) = @_;

  my($RQf) = $message->{store}{inhdhandle};

  my($InHeader, @results, $msginfo, $from);
  my($ip, $TOline, $RcvdFromLine);
  my($Line, $Flags);
  my($TOFound, $FROMFound, $IPFound);
  my(@rcvdiplist);
  #my($read1strcvd, $ipfromheader);

  #$message->{store}->print();

  # Just in case we get a message with no headers at all
  @{$message->{headers}} = ();


  # Seek to the start of the file in case anyone read the file
  # between me opening it and locking it.
  seek($RQf, 0, 0);
  $InHeader = 0;
  while(<$RQf>) {
    chomp; # Chomp everything now. We can easily add it back later.
    s/\015/ /g; # Sanitise everything by removing all embedded <CR>s
    s/\0//g; # Delete all null bytes
    # JKF: You can get ASCII 13 (decimal) characters in the headers, which
    # can be used to embed attachments in the headers. Remember that in
    # most Unix environments, \n = ASCII 10 (decimal).
    # This is a *very* important s// command.
    if ( /^env-end$|^env-eof$/i ) { # The envelope ends here, starting hdr
      $InHeader=1;
      next;
    }

    last if( $InHeader && /^$/ ); # One empty line ends whith the header part

    $Line = $_;
    unless( $InHeader ) {
     if ($Line =~ /^to /i) {
        $TOline = $Line;
        $TOline =~ s/^to //i;
        $TOline =~ s/^<//; # leading and
        $TOline =~ s/>$//; # trailing <>
        push @{$message->{to}}, lc($TOline);
        $TOFound = 1; # We have found a recipient
      }
      if ($Line =~ /^from /i) {
        $from = $Line;
        $from =~ s/^from //i;
        $from =~ s/^<//; # leading and
        $from =~ s/>$//; # trailing <>
        $message->{from} = lc($from);
        $FROMFound = 1; # We have found the sender
      }
      if ($Line =~ /^channel error/i) {
        $from = "";
        $message->{from} = lc($from);
        $FROMFound = 1; # We have found the (NULL) sender
      }
      if ($Line =~ /^rcvdfrom /i) {
        $ip = $Line;
        # PERT-BBY
        # handle envelope rcvdfrom to generate fake Received: for SA
        $RcvdFromLine = $Line;
        $RcvdFromLine =~ s/^rcvdfrom //i;
        $message->{zmenvrcvdfrom} = $RcvdFromLine;
        if ($ip =~ /\[(\d+\.\d+\.\d+.\d+)\]/) {
          $message->{clientip} = $1;
        } else {
          # It is a locally-created message and doesn't have an smtp client ip
          $message->{clientip} = '127.0.0.1';
        }
        $IPFound = 1; # We have found the client IP address
      }
      if ($Line =~ /^with *(.+)/) {
        # PERT-BBY
        # handle envelope with to generate fake Received: for SA
        $message->{zmenvwith} = $1;
      }
      if ($Line =~ /^rcvdfrom .*\ssmtp-auth:\s"([^"]+)"/i) {
        $message->{authenticateduser} = $1;
        $message->{authenticateduser} =~ s/\s//g;
        unless( $message->{authenticateduser} =~ /@/ ) {
          my $domainauth= MailScanner::Config::Value('domainauth');
          if( $domainauth ne "no" ) {
            $message->{authenticateduser} .= "\@$domainauth";
          } else {
            MailScanner::Log::WarnLog("Batch: There are authenticated users " .
	             "without domain but 'Default Domain Without Auth' is not defined" );
            undef $message->{authenticateduser};
          }
        }
      }
      push @{$message->{metadata}}, $Line; # Put non-headers into @metadata
    } else { # Inside Headers
      push @{$message->{headers}}, $Line;
      if ($Line =~ /^Subject:\s*(\S.*)?$/i) {
        $message->{subject} = $1;
      }
      if ($Line =~ /^Received:/i) {
        my $rcvdip = '127.0.0.1';
        if ($Line =~ /^Received: .+?\[(\d+\.\d+\.\d+\.\d+)\]/i) {
          $rcvdip = $1;
          #unless ($read1strcvd) {
          #  $ipfromheader = $1;
          #  $read1strcvd = 1;
          #}
        } elsif ($Line =~ /^Received: .+?\[([\dabcdef.:]+)\]/i) {
          $rcvdip = $1;
          #unless ($read1strcvd) {
          #  $ipfromheader = $1;
          #  $read1strcvd = 1;
          #}
        }
        push @rcvdiplist, $rcvdip;
      }
      # JKF Testing code, remove before production release
      #if ($Line =~ /^X-ClientIP:/i) {
      #  $message->{clientip} = $1 if $Line =~ /(\d+\.\d+\.\d+\.\d+)/;
      #  $IPFound = 1;
      #}
      # JKF End of testing code
    }
  }

  # If we were told to get the IP address from the header, and it was there...
  $getipfromheader = @rcvdiplist if $getipfromheader>@rcvdiplist;
  # If they wanted the 2nd Received from address, give'em element 1 of list
  $message->{clientip} = $rcvdiplist[$getipfromheader-1] if
    $getipfromheader>0;
  #$message->{clientip} = $ipfromheader
  #  if $getipfromheader && $read1strcvd && $ipfromheader ne "";

  # Decode ISO subject lines into UTF8
  # Needed for UTF8 support in MailWatch 2.0
  eval {
   $message->{utf8subject} = Encode::decode('MIME-Header',
                                            $message->{subject});
  };
  if ($@) {
   # Eval failed - store a copy of the subject before MIME::WordDecoder
   # is run, as this appears to destroy the characters of some subjects
   $message->{utf8subject} = $message->{subject};
  }

  # Decode the ISO encoded Subject line
  # Over-ride the default default character set handler so it does it
  # much better than the MIME-tools default handling.
  MIME::WordDecoder->default->handler('*' => \&MailScanner::Message::WordDecoderKeep7Bit);
  # Decode the ISO encoded Subject line
  my $TmpSubject = MIME::WordDecoder::unmime($message->{subject});
  if ($TmpSubject ne $message->{subject}) {
    # The unmime function dealt with an encoded subject, as it did
    # something. Allow up to 10 trailing spaces so that SweepContent
    # is more kind to us and doesn't go and replace the whole subject,
    # thinking that it is malicious. Total replacement and hence
    # destruction of unicode subjects is rather harsh when we are just
    # talking about a few spaces.
    $TmpSubject =~ s/ {1,10}$//;
    $message->{subject} = $TmpSubject;
  }
  #old $message->{subject} = MIME::WordDecoder::unmime($message->{subject});

  # Every zmailer file should at least define the sender, 1 recipient and the
  # IP address. Everything else is optional, and is preserved as
  # MailScanner may not understand all the types of line.
  return 1 if $FROMFound && $TOFound && $IPFound;
  #MailScanner::Log::WarnLog("Batch: Found invalid queue file for " .
  #                          "message %s", $message->{id});
  return 0;
}


# Add all the message headers to the metadata so it's ready to be
# mangled and output to disk. Puts the headers at the end.
# Can be passed in a string containing all the headers.
# This is usually the output of stringify_output (MIME-Tools).
# JKF: @headers doesn't include leading "H" header indicator.
#      @metadata includes leading "H" but no \n characters.
#      The input to this function can be a "\n"-separated string of
#      new header lines. This is useful as the SpamCheck header can
#      be flowed over multiple lines, but still be passed into here
#      as a single header.
# REVISO LEOH
sub AddHeadersToQf {
  my $this = shift;
  my($message, $headers) = @_;

  my($header, $h, @headerswithouth);

  if ($headers) {
    @headerswithouth = split(/\n/, $headers);
  } else {
    @headerswithouth = @{$message->{headers}};
  }

  unless( grep( /^env-end$|^env-eof$/i, @{$message->{metadata}} ) ) {
     push @{$message->{metadata}}, 'env-end';
               }
  foreach $header (@headerswithouth) {
    # Re-insert the header flags for Return-Path:
                     if( $header =~ /^Return-Path:/i ) {
      $header = $message->{returnpathflags} . $header;
    }
    push @{$message->{metadata}}, $header;
  }
}

# REVISO LEOH
sub AddHeader {
  my($this, $message, $newkey, $newvalue) = @_;
  unless( grep( /^env-end$|^env-eof$/i, @{$message->{metadata}} ) ) {
    push @{$message->{metadata}}, 'env-end';
  }
  # DKIM: May just need to unshift instead of push?
  if ($message->{newheadersattop}) {
    unshift @{$message->{metadata}}, "$newkey $newvalue";
  } else {
    push @{$message->{metadata}}, "$newkey $newvalue";
  }
}
# REVISO LEOH
sub DeleteHeader {
  my($this, $message, $key) = @_;

  my $usingregexp = ($key =~ s/^\/(.*)\/$/$1/)?1:0;

  # Add a colon if they forgot it.
  $key .= ':' unless $usingregexp || $key =~ /:$/;
  # If it's not a regexp, then anchor it and sanitise it.
  $key = '^' . quotemeta($key) unless $usingregexp;

  my($linenum);
  for ($linenum=0; $linenum<@{$message->{metadata}}; $linenum++) {
    last if $message->{metadata}[$linenum] =~ /^env-end$|^env-eof$/i;
  }
  for ($linenum++; $linenum<@{$message->{metadata}}; $linenum++) {
    next unless $message->{metadata}[$linenum] =~ /$key/i;
    # Have found the right line
    splice(@{$message->{metadata}}, $linenum, 1);
    # Now delete the continuation lines
    while($message->{metadata}[$linenum] =~ /^\s/) {
      splice(@{$message->{metadata}}, $linenum, 1);
    }
    $linenum--; # Allow for 2 neighbouring instances of $key
  }
}

sub UniqHeader {
  my($this, $message, $key) = @_;

  my($linenum, $foundat);
  for ($linenum=0; $linenum<@{$message->{metadata}}; $linenum++) {
    last if $message->{metadata}[$linenum] =~ /^env-end$|^env-eof$/i;
  }
  $foundat = -1;
  for ($linenum++; $linenum<@{$message->{metadata}}; $linenum++) {
    next unless $message->{metadata}[$linenum] =~ /^$key/i;
    # Have found the right line
    ($foundat = $linenum), next if $foundat == -1;

    splice(@{$message->{metadata}}, $linenum, 1);
    # Now delete the continuation lines
    while($message->{metadata}[$linenum] =~ /^\s/) {
      splice(@{$message->{metadata}}, $linenum, 1);
    }
    $linenum--; # Allow for 2 neighbouring instances of $key
  }
}

# REVISO LEOH
sub ReplaceHeader {
  my($this, $message, $key, $newvalue) = @_;

  # DKIM: Don't do DeleteHeeader if adding at top of headers
  $this->DeleteHeader($message, $key) unless $message->{dkimfriendly};
  $this->AddHeader($message, $key, $newvalue);
}

# REVISO LEOH
sub AppendHeader {
  my($this, $message, $key, $newvalue, $sep) = @_;

  my($linenum, $oldlocation, $totallines);

  # Try to find the old header
  $oldlocation = -1;
  $totallines = @{$message->{metadata}};

  # Find the start of the header
  for($linenum=0; $linenum<$totallines; $linenum++) {
    last if $message->{metadata}[$linenum] =~ /^env-end$|^env-eof$/i;
  }
  for($linenum++; $linenum<$totallines; $linenum++) {
    next unless $message->{metadata}[$linenum] =~ /^$key/i;
    $oldlocation = $linenum;
    last;
  }

  # Didn't find it?
  if ($oldlocation<0) {
    $this->AddHeader($message, $key, $newvalue);
    return;
  }

  # Find the last line of the header
  do {
    $oldlocation++;
  } while($linenum<$totallines &&
          $message->{metadata}[$oldlocation] =~ /^\s/);
  $oldlocation--;

  # Add onto the end of the header
  $message->{metadata}[$oldlocation] .= "$sep$newvalue";
}

# REVISO LEOH
sub PrependHeader {
  my($this, $message, $key, $newvalue, $sep) = @_;

  my($linenum, $oldlocation);

  # Try to find the old header
  $oldlocation = -1;

  for($linenum=0; $linenum<@{$message->{metadata}}; $linenum++) {
    last if $message->{metadata}[$linenum] =~ /^env-end$|^env-eof$/i;
  }
  # Find the start of the header
  for($linenum++; $linenum<@{$message->{metadata}}; $linenum++) {
    next unless $message->{metadata}[$linenum] =~ /^$key/i;
    $oldlocation = $linenum;
    last;
  }

  # Didn't find it?
  if ($oldlocation<0) {
    $this->AddHeader($message, $key, $newvalue);
    return;
  }

  $message->{metadata}[$oldlocation] =~
      s/^$key\s*/$key $newvalue$sep/i;
}

# REVISO LEOH
sub TextStartsHeader {
  my($this, $message, $key, $text) = @_;

  my($linenum, $oldlocation);

  # Try to find the old header
  $oldlocation = -1;

  for($linenum=0; $linenum<@{$message->{metadata}}; $linenum++) {
    last if $message->{metadata}[$linenum] =~ /^env-end$|^env-eof$/i;
  }
  # Find the start of the header
  for($linenum++; $linenum<@{$message->{metadata}}; $linenum++) {
    next unless $message->{metadata}[$linenum] =~ /^$key/i;
    $oldlocation = $linenum;
    last;
  }

  # Didn't find it?
  if ($oldlocation<0) {
    return 0;
  }

# TODO LEOH: Seguro que no es $key: ...???? Esta asi en el del sendmail
  return 1 if $message->{metadata}[$oldlocation] =~
                                 /^$key\s+\Q$text\E/i;
  return 0;
}

# REVISO LEOH
sub TextEndsHeader {
  my($this, $message, $key, $text) = @_;

  my($linenum, $oldlocation, $lastline, $totallines);

  # Try to find the old header
  $oldlocation = -1;
  $totallines = @{$message->{metadata}};

  for($linenum=0; $linenum<totallines; $linenum++) {
    last if $message->{metadata}[$linenum] =~ /^env-end$|^env-eof$/i;
  }
  # Find the start of the header
  for($linenum++; $linenum<$totallines; $linenum++) {
    next unless $message->{metadata}[$linenum] =~ /^$key/i;
    $oldlocation = $linenum;
    last;
  }

  # Didn't find it?
  if ($oldlocation<0) {
    return 0;
  }

  # Find the last line of the header
  $lastline = $oldlocation;
  do {
    $lastline++;
  } while($lastline<$totallines &&
          $message->{metadata}[$lastline] =~ /^\s/);
  $lastline--;
  $key = '\s' unless $lastline == $oldlocation;

  return 1 if $message->{metadata}[$lastline] =~
                                 /^$key.+\Q$text\E$/i;
  return 0;
}


#REVISO LEOH
sub AddRecipients {
  my $this = shift;
  my($message, @recips) = @_;
  #my($recip);
  #foreach $recip (@recips) {
  #  push @{$message->{metadata}}, "to <$recip>";
  #PERT-BBY add the envelope format to addresses:
  for (@recips) { s/^(.*)$/to <$1>/ };
  my ($line);
  my $pos=0;
  #PERT-BBY now, look for first 'to '
  foreach $line (@{$message->{metadata}}) {
    last if ($line =~ /^to |^env-end$|^env-eof$/);
    $pos++;
  }
  #PERT-BBY and insert the new ones here
  splice(@{$message->{metadata}} , $pos, 0, @recips);
}

# Delete the original recipients from the message. We'll add some
# using AddRecipients later.
#REVISO LEOH
sub DeleteRecipients {
  my $this = shift;
  my($message, $user) = @_;

  $user= quotemeta($user) if( $user );
  #my $userre=$user ? qr/.*\b$user\b/ : qr //;
  #my $userre=$user ?  qr/(:?.*RCPT=rfc822;|\s*<?)$user(:?\s+.*|>?\s*)/i : qr /.*/;
  my $userre=$user ?  qr/(?:.*RCPT=rfc822;$user\s|\s*<?$user(?:[>\s]|$))/i : qr //;
  my($linenum);
  for ($linenum=0; $linenum<@{$message->{metadata}}; $linenum++) {
    # Looking for "recipient" lines
    #next unless $message->{metadata}[$linenum] =~ /^to(:?dsn)?\s$userre/;
    #next unless $message->{metadata}[$linenum] =~ /^to(:?dsn)?\s$userre/i;
    next unless $message->{metadata}[$linenum] =~ /^to(?:dsn)?\s$userre/i;
    # Have found the right line
    splice(@{$message->{metadata}}, $linenum, 1);
    $linenum--; # Study the same line again
  }
}


sub KickMessage {
  # ZMailer is always checking its queues anyway, so there is no point
  # doing anything here.
  return 1;
}

#REVISO LEOH
sub CreateQf {
  my($message) = @_;

  return join("\n", @{$message->{metadata}}) . "\n\n";
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
#REVISO LEOH
sub SendMessageString {
  my $this = shift;
  my($message, $email, $sender) = @_;

  my($fh);

  #print STDERR '|' . MailScanner::Config::Value('sendmail', $message) .
  #          ' ' . $SendmailOptions . '-f ' . "'$sender'" . "\n";
  $fh = new FileHandle;
  $fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
            " $SendmailOptions '" . $sender . "'")
    or MailScanner::Log::WarnLog("Could not send email message, %s", $!),
       return 0;
  #$fh->open('|cat >> /tmp/1');
  $fh->print($email);
  #print STDERR $email;
  $fh->close();

  1;
}


# Send an email message containing the attached MIME entity.
# Also passed in the sender's address.
sub SendMessageEntity {
  my $this = shift;
  my($message, $entity, $sender) = @_;

  my($fh);

  #print STDERR  '|' . MailScanner::Config::Value('sendmail', $message) .
  #          ' ' . $SendmailOptions . '-f ' . $sender . "\n";
  $fh = new FileHandle;
  $fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
            " $SendmailOptions '" . $sender . "'")
    or MailScanner::Log::WarnLog("Could not send email entity, %s", $!),
       return 0;
  #$fh->open('|cat >> /tmp/2');
  $entity->print($fh);
  #$entity->print(\*STDERR);
  $fh->close();

  1;
}

# Create a MessageBatch object by reading the queue and filling in
# the passed-in batch object.
#REVISO LEOH
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
  #chdir $queuedirname or Log::DieLog("Cannot cd to dir %s to read " .
  #                                   "messages, %s", $queuedirname, $!);

  $queuedir = new DirHandle;
  $MsgsInQueue = 0;
  #print STDERR "Inq = " . $global::MS->{inq} . "\n";
  #print STDERR "dir = " . $global::MS->{inq}{dir} . "\n";
  @queuedirnames = @{$global::MS->{inq}{dir}};

  ($MaxCleanB, $MaxCleanM, $MaxDirtyB, $MaxDirtyM)
                    = MailScanner::MessageBatch::BatchLimits();

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
    $DirtyMsgs  = 0;
    $DirtyBytes = 0;
    $CleanMsgs  = 0;
    $CleanBytes = 0;
    $MsgsInQueue = 0;
    %ModDate = ();
    @SortedFiles = ();
    $HitLimit1  = 0;
    $HitLimit2  = 0;
    $HitLimit3  = 0;
    $HitLimit4  = 0;
    $invalidfiles = "";

    # Loop through each of the inq directories
    # Patch to combat starving in emergency queue mode
    # foreach $queuedirname (@queuedirnames) {
    my @aux_queuedirnames=@queuedirnames;
    while( defined($queuedirname=splice(@aux_queuedirnames,
          ($UnsortedBatchesLeft<=0 ? 0 :int(rand(@aux_queuedirnames))),1))) {
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
      while($file = $queuedir->read()) {
        next unless $file =~ /$mta->{HDFileRegexp}/;
        #print STDERR "Found message file $file\n";
        $MsgsInQueue++; # Count the size of the queue
        push @SortedFiles, "$queuedirname/$file";
        if ($UnsortedBatchesLeft<=0) {
          # Running normally
          $tmpdate = (stat($file))[9]; # 9 = mtime
          next unless -f _;
          next if -z _; # Skip 0-length qf files
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
    #print STDERR "Files are " . join(', ', @SortedFiles) . "\n";
    umask $headerfileumask; # Started creating files
    while(($file = shift @SortedFiles) &&
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
      next unless $file =~ /$mta->{HDFileRegexp}/;
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
          #print STDERR "Moving $attempts[0], $attempts[1], $attempts[2] into achive table\n";
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
      $newmessage->WriteHeaderFile(); # Write the file of headers
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
        # Will have to add a WriteHeaderFile() here to implement
        # single-file archiving of messages.
        # Moved this further up
        #$newmessage->WriteHeaderFile(); # Write the file of headers
      }
    }
    umask 0077; # Safety net as stopped creating files

    # Wait a bit until I check the queue again
    sleep(MailScanner::Config::Value('queuescaninterval')) if $batchempty;
  } while $batchempty; # Keep trying until we get something

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

  #MailScanner::Log::NoticeLog("New Batch: Archived %d $ArchivedMsgs messages",
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
# This is in Sendmail.pm as the storage of the headers array is specific
# to the MTA being used.
sub OriginalMsgHeaders {
  my $this = shift;
  my($message, $separator) = @_;
  # PERT-BBY
  # handle envelope with to generate fake Received: for SA
  my $fakereceived;
  my $hostname = MailScanner::Config::Value('hostname', $this);
  # if hostname has blanks in it, replace by dots
  $hostname =~ s/  */./g;
  my ($sec1,$min1,$hr1,$md1,$mon1,$yr1,$wd1,$yd1,$dst1) = gmtime;

  my $month = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$mon1];
  my $wday = (qw(Sun Mon Tue Wed Thu Fri Sat))[$wd1];
  my $year = $yr1+1900;
  my $time = sprintf("%02d:%02d:%02d",$hr1,$min1,$sec1);
  # PERT-BBY
  # we use GMT since it's allowed and we don't want to mess up with timezone
  # calculations for a header only SA will see
  my $rfc822date = "$wday, $md1 $month $year $time +00:00";

  $fakereceived = "Received: from " . $message->{zmenvrcvdfrom} .
      " by " . $hostname . " with " . $message->{zmevnwith} . 
	  " id <" .  $message->{id} . ">; " . $rfc822date;
  #MailScanner::Log::InfoLog("Generated line: %s", $fakereceived);

  # No separator so just return the array
  return ($fakereceived,@{$message->{headers}}) unless $separator;

  # There is a separator
  my($h,@result);
  push @result, $fakereceived . $separator;
  foreach $h (@{$message->{headers}}) {
    push @result, $h . $separator;
  }
  return @result;
}


# Check that the queue directory passed in is flat and contains
# no queue sub-directories. For some MTA's this may be a no-op.
# For sendmail it matters a lot! Sendmail will put different files in
# different directories if there are subdirectories called things like
# qf, xf, tf or df. Also directories called q1, q2, etc. are a sure
# sign that sendmail is running queue groups, which MailScanner cannot
# handle.
#
# Called from main mailscanner script
#
# REVISO LEOH
sub CheckQueueIsFlat {
  my($dir) = @_;

  #MailScanner::Log::WarnLog("In CheckQueueIsFlat, dir is %s", $dir);
  my($dirhandle, $f);

  $dirhandle = new DirHandle;
  $dirhandle->open($dir)
    or MailScanner::Log::DieLog("Cannot read queue directory $dir");

  # Check there are no q\d or qf subdirectories
  while($f = $dirhandle->read()) {
    # 2nd half of the line for SuSE Linux setups which put .hoststat
    # directory inside the queue!
    next if $f =~ /^\.\.?$/ || $f =~ /^\.hoststat/;
    # Delete core files
    $f =~ /^core$/ and unlink "core";
    next unless $f =~ /^\d+$/;
    # Also needs untaint... sledgehammer. nut.
    $f =~ /(.*)/;
    MailScanner::Log::DieLog("Queue directory %s cannot contain sub-" .
                             "directories, currently contains dir %s",
                             $dir, $1)
      if -d "$dir/$1";
  }
  $dirhandle->close();

  return 1;
}

1;
