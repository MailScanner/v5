#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: Postfix.pm 5098 2011-06-25 20:11:06Z sysjkf $
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
no  strict 'subs'; # Allow bare words for parameter %'s

use DirHandle;
use Encode;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5098 $, 10;

# Command-line options you need to give to sendmail to sensibly process a
# message that is piped to it. Still need to add "-f" for specifying the
# envelope sender address. This is usually local postmaster.
my $SendmailOptions = "-t -oi -oem -F MailScanner -f";
my $RunAsUser = 0;
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
  $RunAsUser = MailScanner::Config::Value('runasuser');
  $RunAsUser = $RunAsUser?getpwnam($RunAsUser):0;

  MailScanner::Config::Default('sendmail', '/usr/sbin/sendmail');
  MailScanner::Config::Default('sendmail2',
                               MailScanner::Config::Value('sendmail'));
  $MailScanner::SMDiskStore::HashDirDepth = -1;
  $UnsortedBatchesLeft = 0; # Disable queue-clearing mode
}

# Constructor.
# Takes dir => directory queue resides in
# REVISO LEOH
sub new {
  my $type = shift;
  my $this = {};

  # updated by Jerry Benton
  # Replaced HDFileRegexp '^([\\dA-F]+)$' with '^([\\w]+)$'
  $this->{HDFileRegexp} = '^([\\w]+)$';
  $this->{TFileRegexp} = '^tf-' . $$ . '-([\\dA-F]+)$';
  # JKF Must fix this once I know what it's for.
  $this->{QueueFileRegexp} = '^([\\d]+-[\\d]+)$';

  $this->{LockType} = "flock";

  bless $this, $type;
  return $this;
}

# Required vars are:
#
#ZZ# DFileRegexp:
#ZZ# A regexp that will verify that a filename is a valid
#ZZ# "DFile" name and leave the queue id in $1 if it is.
#ZZ#
# HDFileRegexp:
# A regexp that will verify that a filename is a valid
# "HDFile" name and leave the queue id in $1 if it is.
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
#ZZ# DFileName: 
#ZZ# Take a queue ID and return
#ZZ# filename for data queue file
#ZZ#
# HDFileName:
# Take a queue ID and return
# filename for envelope and data queue file (input)
#
# HDOutFileName:
# Take a queue ID and return
# filename for envelope and data queue file (output)
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
#print STDERR "We are running zmail\n";
#
#MailScanner::Log::InfoLog("Configuring mailscanner for zmail...");

  sub HDFileName {
    my($this, $id) = @_;
    #my($dir1, $dir2, $file);
    #$id =~ /^(.)(.)(.+)$/;
    #($dir1, $dir2, $file) = ($1,$2,$3);
    #return "$dir1/$dir2/$file";
    $id =~ s/\.[^.]+$//;
    return "$id";
  }

  # Give it a temp file name, changes the file name to 
  # a new one for the outgoing queue.
  sub HDOutFileName {
    my($file) = @_;

    #print STDERR "HDOutFileName $file\n";

    my $dir = $file;
    $dir =~ s/\/[^\/]+$//;

    # Bad hash key $file = sprintf("%05X%lX", time % 1000000, (stat($file))[1]);
    # Add 1 so the number is never zero (defensive programming)
    $file = sprintf("%05X%lX", int(rand 1000000)+1, (stat($file))[1]);
    #print STDERR "New Filename is $file\n";

    if ($MailScanner::SMDiskStore::HashDirDepth == 2) {
      $file =~ /^(.)(.)/;
      return ($dir,$1,$2,$file);
    } elsif ($MailScanner::SMDiskStore::HashDirDepth == 1) {
      $file =~ /^(.)/;
      return ($dir,$1,$file);
    } elsif ($MailScanner::SMDiskStore::HashDirDepth == 0) {
      return ($dir,$file);
    } else {
      MailScanner::Log::WarnLog("Postfix dir depth has not been set!");
    }
  }

  # No change for V4
  sub TFileName {
    my($this, $id) = @_;
    return "temp-$$-$id";
  }

  # Change for V4: returns lower-case $from and @to
  sub ReadQf {
    my($this, $message, $getipfromheader) = @_;

    my($RQf) = $message->{store}{inhdhandle};

    my(@results, $msginfo, $from);
    my($ip, $TOline);
    my($Line, $Flags);
    my($MsgContSize, $DataOffset, $NumRecips);
    # ORIGFound stuff courtesy of Juan Pablo Abuyeres 23/7/2006
    # Should improve handling of virtual domains.
    my($ORIGFound, $TOFound, $FROMFound, $IPFound, $TIMEFound);
    my($ErrorFound, $ERecordFound, $rectype, $recdata, $mtime);
    my $InSubject = 0; # Are we adding continuation subject lines?
    my $pRecordsFound = 0; # p record spin-through of body? //Glenn
    my $OriginalPos = 0; # p record jumpoff point //Glenn
    my $MaxpRecPos = 0; # Max position where a p record might occur.
    my @npos = (); # save all p record positions, although we only
                   # look at/use the first and last.
    #my $ipfromheader = ''; # The IP address from the first Received: line
    #my $read1strcvd = 0; # Have we read the 1st Received: line?
    my(@rcvdiplist);

    #print STDERR "In ReadQf\n";
    #$message->{store}->print();
    $message->{nobody} = 0; # If there is no message body we just get X at end of headers
    $ERecordFound = 0;

    # Just in case we get a message with no headers at all
    @{$message->{headers}} = ();

    # seek to end of file and save position, to make sure p records don't
    # try go past this point. 17 is the record size for a p record.
    seek $RQf, -17, 2;
    $MaxpRecPos = tell $RQf;

    # Seek to the start of the file in case anyone read the file
    # between me opening it and locking it.
    seek $RQf, 0, 0;

    # Read the initial record.
    # Provides Message content size, data offset and recipient count
    ($rectype, $recdata) = ReadRecord($RQf);
    #print "1st $rectype is \"$recdata\"\n";
    MailScanner::Log::WarnLog("Syntax error in Postfix queue file, didn't " .
                              "start with a C record") unless $rectype eq 'C';
    #$recdata =~ /^([0-9 ]{15}) ([0-9 ]{15}) ([0-9 ]{15})( ([0-9 ]{15}))?$/;
    #($MsgContSize, $DataOffset, $NumRecips) = ($1+0, $2+0, $3+0);

    my @numbers = split " ", $recdata;
    ($MsgContSize, $DataOffset, $NumRecips) =
      ($numbers[0]+0, $numbers[1]+0, $numbers[2]+0);

    # If $5 is set then we have a new data structure in the file
    $MailScanner::Postfix::DataStructure = 0;
    #if ($5 ne "") {
    #  $MailScanner::Postfix::DataStructure = 1;
    #  $message->{PostfixQmgrOpts} = $5+0;
    #}

    if (defined $numbers[3]) {
      $MailScanner::Postfix::DataStructure = 1;
      $message->{PostfixQmgrOpts} = $numbers[3]+0;
    }

    #$MsgContSize =~ s/^\s*//;
    #$DataOffset  =~ s/^\s*//;
    #$NumRecips   =~ s/^\s*//;
    #print STDERR "MsgContSize=$MsgContSize DataOffset=$DataOffset NumRecips=$NumRecips\n";
    push @{$message->{metadata}}, "$rectype$recdata";
    #print STDERR "Content size = $MsgContSize\n";
    #print STDERR "Data offset  = $DataOffset\n";
    #print STDERR "Num Recips   = $NumRecips\n";

    # If the data offset is 0 then Postfix definitely hasn't finished
    # writing the message.
    unless ($DataOffset+0 > 10) { # 10 == arbitrary small number
      # JKF 5/12/2005 This could fail with an unblessed reference error
      # JKF 5/12/2005 so do it by hand.
      # JKF 5/12/2005 $message->DropFromBatch();
      $message->{deleted} = 1;
      $message->{gonefromdisk} = 1; # Don't try to delete the original
      $message->{store}->Unlock(); # Unlock it so other processes can pick it up
      #20090421 $message->{abandoned} = 1;
      return 0;
    }

    # Read records until we hit the start of the message M record
    #print STDERR "Reading pre data\n";
    while(($rectype, $recdata) = ReadRecord($RQf)) {
      #print STDERR "Got $rectype $recdata\n";
      if ($rectype eq 'M') {
        # Message starts here
        push @{$message->{metadata}}, "$rectype$recdata";
        last;
      } elsif ($rectype eq 'S') {
        # Sender address
        $recdata =~ s/^\<//;
        $recdata =~ s/\<$//;
        $message->{from} = lc($recdata);
        $FROMFound = 1;
      #JKF 20040322 } elsif ($rectype eq 'R') {
      } elsif ($rectype eq 'O') {
        # Recipient address
        $recdata =~ s/^\<//;
        $recdata =~ s/\<$//;
        push @{$message->{to}}, lc($recdata);
        push @{$message->{metadata}}, "$rectype$recdata";
        $TOFound = 1;
        $ORIGFound = 1;
        #print STDERR "Pre R Recip $recdata\n";
      #JKF 20040322 } elsif ($rectype eq 'O') {
      } elsif ($rectype eq 'R') {
        # Original recipients are handled by MS as normal recipients,
        # but are put back into the 'O' originalrcpts list in the
        # replacement message.
        # Original recipient address
        $recdata =~ s/^\<//;
        $recdata =~ s/\<$//;
        $recdata = lc($recdata);
        push @{$message->{to}}, lc($recdata) unless $ORIGFound;
        push @{$message->{metadata}}, "$rectype$recdata";
        #JKF 20040322 $message->{originalrecips}{"$recdata"} = 1;
        $message->{postfixrecips}{lc("$recdata")} = 1;
        $TOFound = 1;
        #print STDERR "Pre O Recip $recdata\n";
      } elsif ($rectype eq 'p') {
	# //Glenn 2007-01-16
	# Handle p records (GOTO like in-place edit thing) by reading
	# the pointed to data into the main message object, and
	# silently discarding the actual p record.
	# This p record should only point to added recipients, or
	# moved records of the same type already handled in this
	# segment, so lets just store the jumpoff point and loop.
	# When we hit the next p record it should be the "jump back to
        # original pos" one, or another forward p record... so we'll
	# check that and act accordingly..
        $pRecordsFound = 1; # If we find a p record we need remember this to handle body ...
	next if ($recdata+0 == 0); # Ignore zero (placeholder) jumps
	if ($recdata+0 > $MaxpRecPos) {
	    MailScanner::Log::WarnLog("p record handling: Attempt to jump beyond end of file, aborting file (for now).");
	    $ErrorFound = 1;
	    last;
	}
	if ($OriginalPos == 0) {
	   # Jump to after E record and commence
	   $OriginalPos = tell $RQf;
	   seek $RQf, $recdata+0, 0; # jump. we should check this works.
	   next;
	} else {
	  # We're at the return point, or moving even furtehr away...
	  if ($recdata+0 < $OriginalPos) {
	     MailScanner::Log::WarnLog("p record handling: $recdata < $OriginalPos, this cannot be! Aborting this file.");
	     #seek $RQf, $OriginalPos, 0; # jump back up. we should chk this.
	     $OriginalPos = 0;
	     @npos = ();
	     $ErrorFound = 1;
	     last;
	  } else {
	    seek $RQf, $recdata+0, 0; # jump back or forward. we should chk this works.
            foreach $_ (@npos) {
              if ($_+0 eq $recdata+0) {
		  $ErrorFound = 1;
		  last;
	       }
	    }
            if ($ErrorFound) {
		  MailScanner::Log::WarnLog("p record handling: Loop condition found, aborting file.");
		  $OriginalPos = 0; # Reset to not fool next segment loop
	       @npos = ();
		  last;
	    }
	  }
	}
	push @npos, $recdata+0; # save jumpto position, for loop detection.
      } else {
        # Some other record type. Just store it and move on.
        push @{$message->{metadata}}, "$rectype$recdata";
      }
    }

    # We are now at the start of the message. Read the headers until
    # we get an empty N record which is the blank line just after the
    # headers.
    #print STDERR "Reading message body\n";
    while(!$message->{nobody} && (($rectype, $recdata) = ReadRecord($RQf))) {
      #print STDERR "Reading headers: $rectype, $recdata\n";
      if ($rectype eq 'X') {
        #push @{$message->{metadata}}, "$rectype$recdata";
        $message->{nobody} = 1; # Found end of message before message body text
        last;
      }
      last if $rectype eq 'N' && $recdata eq "";
      if (!defined($rectype)) {
         $ErrorFound = 1;
      #print STDERR "RECTYPER ERROR: $rectype, $recdata\n";
         last;
      }
      if ($rectype eq 'p') {
	 # //Glenn 2007-01-16
	 # Handle p records (GOTO like in-place edit thing) by reading
	 # the pointed to data into the main message object, and
	 # silently discarding the actual p record.
	 # This p record should only point to added headers, or
	 # moved records of the same type already handled in this
	 # segment, so lets just store the jumpoff point and loop.
	 # When we hit the next p record it should be the "jump back to
         # original pos" one, or another forward p record... so we'll
	 # check that and act accordingly..
         $pRecordsFound = 1; # If we find a p record we need remember this to handle body ...
	 next if ($recdata+0 == 0); # Ignore zero (placeholder) jumps
	 if ($recdata+0 > $MaxpRecPos) {
	    MailScanner::Log::WarnLog("p record handling: Attempt to jump beyond end of file, aborting file (for now).");
	    $ErrorFound = 1;
	    last;
	 }
	 if ($OriginalPos == 0) {
	    # Jump to after E record and commence
	    $OriginalPos = tell $RQf;
	    seek $RQf, $recdata+0, 0; # jump. we should check this works.
	 } else {
	   # We're at the return point, or moving even further away...
	   if ($recdata+0 < $OriginalPos) {
	     MailScanner::Log::WarnLog("p record handling: $recdata < $OriginalPos, this cannot be! Aborting this file.");
	     #seek $RQf, $OriginalPos, 0; # jump back up. we should chk this.
	     $OriginalPos = 0;
	      @npos = ();
	     $ErrorFound = 1;
	     last;
	   } else {
	     seek $RQf, $recdata+0, 0; # jump back or forward. we should chk this works.
            foreach $_ (@npos) {
              if ($_+0 eq $recdata+0) {
		   $ErrorFound = 1;
		   last;
	        }
	    }
            if ($ErrorFound) {
		  MailScanner::Log::WarnLog("p record handling: Loop condition found, aborting file.");
		  $OriginalPos = 0; # Reset to not fool next segment loop
	        @npos = ();
		  last;
	     }
	   }
	 }
	 push @npos, $recdata+0; # save jumpto position, for loop detection.
	 next; # done, don't add a spurious "converted p to N" record.
      }
      next if ($rectype eq 'w'); # Skip deleted (w) records ... Else they will be transformed to Normal (N) records.
      push @{$message->{headers}}, $recdata; # Headers have no leading N
      if ($recdata =~ /^Subject:\s*(\S.*)?$/i) {
        $message->{subject} = $1;
        $InSubject = 1;
        next;
      }
      if ($InSubject) {
        if ($recdata =~ /^\s/) {
          # We are in a continuation line, so remove the leading whitespace
          $recdata =~ s/^\s//;
          $message->{subject} .= $recdata;
          next;
        } else {
          # Line did not start with continuation character so we're not in Subj
          $InSubject = 0;
        }
      }
      #if ($recdata =~ /^Received: .+\[(\d+\.\d+\.\d+\.\d+)\]/i) {
      #  unless ($read1strcvd) {
      #    $ipfromheader = $1;
      #    $read1strcvd = 1;
      #  }
      #  unless ($IPFound) {
      #    $message->{clientip} = $1;
      #    $IPFound = 1;
      #  }
      #} elsif ($recdata =~ /^Received: .+\[([\dabcdef.:]+)\]/i) {
      # Linux adds "IPv6:" on the front of the IPv6 address, so remove it
      if ($recdata =~ /^Received:/i) {
        my $rcvdip = '127.0.0.1';
        if ($recdata =~ /^Received: .+?\(.*?\[(?:IPv6:)?([0-9a-f.:]+)\]/i) {
          $rcvdip = $1;
          #unless ($read1strcvd) {
          #  $ipfromheader = $1;
          #  $read1strcvd = 1;
          #}
          #15 if ($getipfromheader && $getipfromheader <= @rcvdiplist) {
          #15   $message->{clientip} = $rcvdiplist[$getipfromheader-1];
          #15   $IPFound = 1;
          #15 }
          #unless ($IPFound) {
          #  $message->{clientip} = $1;
          #  $IPFound = 1;
          #}
        }#15  elsif (!$IPFound &&
         #15         $getipfromheader==1 &&
         #15         $recdata =~ /^Received: .+\(Postfix/i) {
         #15  $message->{clientip} = '127.0.0.1';  #spoof local sender from localhost
         #15  $rcvdip = '127.0.0.1';
         #15  $IPFound = 1;
        #15 }
        push @rcvdiplist, $rcvdip;
      }
    }
    # Must remember to add empty "X" record after the message data.

    # We are now at the end of the headers. Jump straight to the metadata
    # after the message.
#    seek $RQf, $MsgContSize+$DataOffset, 0;

# Inelegant, but working. Instead of an efficient seek, we spinn through to
# after X record. Unless we don't have a body to spin through. Also skip
# the spin if we don't have any p records already (to not punish the normal
# case). Don't spin if error found either.
    if (!$message->{nobody} && $pRecordsFound && !$ErrorFound) {
      while(($rectype, $recdata) = ReadRecord($RQf)) {
        #print STDERR "Metadata type $rectype data \"$recdata\"\n";
        if (!defined($rectype) or $rectype eq 'X') {
	  $ErrorFound = 1 if(!defined($rectype));
          last;
        }
        if ($rectype eq 'p') {
	  # //Glenn 2007-01-16
	  # Handle p records (GOTO like in-place edit thing) by reading
	  # the pointed to data into the main message object, and
	  # silently discarding the actual p record.
	  # This p record should only point to a new body record, or
	  # moved records of the same type already handled in this
	  # segment, so lets just store the jumpoff point and loop.
	  # When we hit the next p record it should be the "jump back to
          # original pos" one, or another forward p record... so we'll
	  # check that and act accordingly..
	  next if ($recdata+0 == 0); # Ignore zero (placeholder) jumps
	  if ($recdata+0 > $MaxpRecPos) {
	      MailScanner::Log::WarnLog("p record handling: Attempt to jump beyond end of file, aborting file (for now).");
	      $ErrorFound = 1;
	      last;
	  }
	  if ($OriginalPos == 0) {
	     # Jump to after E record and commence
	     $OriginalPos = tell $RQf;
	     seek $RQf, $recdata+0, 0; # jump. we should check this works.
	     next;
	  } else {
	    # We're at the return point, or moving even furtehr away...
	    if ($recdata+0 < $OriginalPos) {
	       MailScanner::Log::WarnLog("p record handling: $recdata < $OriginalPos, this cannot be! Aborting this file.");
	       #seek $RQf, $OriginalPos, 0; # jump back up. we should chk this.
	       $OriginalPos = 0;
	       @npos = ();
	       $ErrorFound = 1;
	       last;
	    } else {
	      seek $RQf, $recdata+0, 0; # jump back or forward. we should chk this works.
              foreach $_ (@npos) {
                if ($_+0 eq $recdata+0) {
		    $ErrorFound = 1;
		    last;
	         }
	      }
              if ($ErrorFound) {
		 MailScanner::Log::WarnLog("p record handling: Loop condition found, aborting file.");
		 $OriginalPos = 0; # Reset to not fool next segment loop
	         @npos = ();
		 last;
	      }
	    }
	  }
	  push @npos, $recdata+0; # save jumpto position, for loop detection.
        }
      }
      #print STDERR "\n\nErrorFound=$ErrorFound and rectype=$rectype\n\n";
      # Found errors above, means the file isn't complete... remove it from the batch and return immediately.
      if ($ErrorFound || $rectype ne 'X') {
        #MailScanner::Log::WarnLog("No end-of-message record found in %s, " .
        #                          "retrying", $message->{id});
        # JKF 5/12/2005 This could fail with an unblessed reference error
        # JKF 5/12/2005 so do it by hand.
        # JKF 5/12/2005 $message->DropFromBatch();
        $message->{deleted} = 1;
        $message->{gonefromdisk} = 1; # Don't try to delete the original
        $message->{store}->Unlock(); # Unlock it so other processes can pick it up
        #20090421 $message->{abandoned} = 1; # JKF 20090301 This message was scrapped

        return 0;
      }
    }
    # "safety" seek, in case things go badly above. We also need to return "before" the X record, so that it is copied over below.
    #my $CurrentPos = tell $RQf;
    #print STDERR "MsgContSize+DataOffset = ",$MsgContSize+$DataOffset,"\nCuurentPos = ",$CurrentPos+0,"\n";
    seek $RQf, $MsgContSize+$DataOffset, 0; # if ($MsgContSize+$DataOffset ne $CurrentPos+0);

    # We are now in the metadata after the message.
    #print STDERR "Reading post data\n";
    while(($rectype, $recdata) = ReadRecord($RQf)) {
      #print STDERR "Metadata type $rectype data \"$recdata\"\n";
      if ($rectype eq 'E') {
        push @{$message->{metadata}}, "$rectype$recdata";
        $ERecordFound = 1;
        last;
      }
      # JKF 20050621 Must only ever find 1 timestamp or the message is corrupt
      if ($rectype eq 'T') {
        if ($TIMEFound) {
          $ErrorFound = 1;
          last;
        }
        $TIMEFound = 1;
      }
      #JKF 20040322 if ($rectype eq 'R') {
      if ($rectype eq 'O') {
        # Recipient address
        $recdata =~ s/^\<//;
        $recdata =~ s/\<$//;
        push @{$message->{to}}, lc($recdata);
        push @{$message->{metadata}}, "$rectype$recdata";
        $TOFound = 1;
        $ORIGFound = 1;
        #print STDERR "Post R Recip $recdata\n";
      #JKF 20040322 } elsif ($rectype eq 'O') {
      } elsif ($rectype eq 'R') {
        # These recipients are used in the message handling in MS,
        # but must be put back in the 'O' list in the new message.
        # Original recipient address
        $recdata =~ s/^\<//;
        $recdata =~ s/\<$//;
        $recdata = lc($recdata);
        #push @{$message->{to}}, $recdata;
        push @{$message->{to}}, lc($recdata) unless $ORIGFound;
        push @{$message->{metadata}}, "$rectype$recdata";
        #JKF 20040322 $message->{originalrecips}{"$recdata"} = 1;
        $message->{postfixrecips}{"$recdata"} = 1;
        $TOFound = 1;
        #print STDERR "Post O Recip $recdata\n";
      } elsif ($rectype eq 'p') {
	# //Glenn 2007-01-16
	# Handle p records (GOTO like in-place edit thing) by reading
	# the pointed to data into the main message object, and
	# silently discarding the actual p record.
	# This p record should only point to added recipients, or
	# moved records of the same type already handled in this
	# segment, so lets just store the jumpoff point and loop.
	# When we hit the next p record it should be the "jump back to
        # original pos" one, or another forward p record... so we'll
	# check that and act accordingly..
	# I'm not sure this segment can have p records, but better
	# safe than sorry.
	next if ($recdata+0 == 0); # Ignore zero (placeholder) jumps
	if ($recdata+0 > $MaxpRecPos) {
	    MailScanner::Log::WarnLog("p record handling: Attempt to jump beyond end of file, aborting file (for now).");
	    $ErrorFound = 1;
	    last;
	}
	if ($OriginalPos == 0) {
	   # Jump to after E record and commence
	   $OriginalPos = tell $RQf;
	   seek $RQf, $recdata+0, 0; # jump. we should check this works.
	   next;
	} else {
	  # We're at the return point, or moving even further away...
	  if ($recdata+0 < $OriginalPos) {
	     MailScanner::Log::WarnLog("p record handling: $recdata < $OriginalPos, this cannot be! Aborting this file.");
	     #seek $RQf, $OriginalPos, 0; # jump back up. we should chk this.
	     $OriginalPos = 0;
	     @npos = ();
	     $ErrorFound = 1;
	     last;
	  } else {
	    seek $RQf, $recdata+0, 0; # jump back or forward. we should chk this works.
            foreach $_ (@npos) {
              if ($_+0 eq $recdata+0) {
		  $ErrorFound = 1;
		  last;
	       }
	    }
            if ($ErrorFound) {
		  MailScanner::Log::WarnLog("p record handling: Loop condition found, aborting file.");
		  $OriginalPos = 0; # Reset to not fool next segment loop
	       @npos = ();
		  last;
	    }
	  }
	}
	push @npos, $recdata+0; # save jumpto position, for loop detection.
      } else {
        # Some other record type. Just store it and move on.
        push @{$message->{metadata}}, "$rectype$recdata";
      }
    }
    #print STDERR "\n\nErrorFound=$ErrorFound and rectype=$rectype\n\n";
    # Found errors above, means the file isn't complete... remove it from the batch and return immediately.
    if ($ErrorFound) {
      #MailScanner::Log::WarnLog("No end-of-message record found in %s, " .
      #                          "retrying", $message->{id});
      # JKF 5/12/2005 This could fail with an unblessed reference error
      # JKF 5/12/2005 so do it by hand.
      # JKF 5/12/2005 $message->DropFromBatch();
      $message->{deleted} = 1;
      $message->{gonefromdisk} = 1; # Don't try to delete the original
      $message->{store}->Unlock(); # Unlock it so other processes can pick it up
      #20090421 $message->{abandoned} = 1; # JKF 20090301 This message was scrapped

      return 0;
    }
      
    # Remove all the duplicates from ->{to}
    my %uniqueto;
    foreach (@{$message->{to}}) {
      $uniqueto{$_} = 1;
    }
    @{$message->{to}} = keys %uniqueto;

    # We now have all the pre-message records followed by the M record
    # followed by the post-message records including the X record and the
    # terminating E record. We can add recipient R records just before
    # the last last metadata record (so we keep the E at the end).
    # The message headers and body get put in just after the M record.

    # Every postfix file should at least define the sender, 1 recipient and
    # the IP address. Everything else is optional, and is preserved as
    # MailScanner may not understand all the types of line.
    #print STDERR "Found FROM\n" if $FROMFound;
    #print STDERR "Found TO\n"   if $TOFound;
    #print STDERR "Found IP\n"   if $IPFound;
    #print STDERR "Successfully ReadQf!\n" if $FROMFound && $TOFound && $IPFound;

    # If we didn't find an IP address, then put in 0.0.0.0 so that at least
    # we have something there

    # There will always be at least 1 Received: header, even if 127.0.0.1
    push @rcvdiplist, '127.0.0.1' unless @rcvdiplist;
    # Don't fall off the end of the list
    $getipfromheader = @rcvdiplist if $getipfromheader>@rcvdiplist;
    # Don't fall off the start of the list
    $getipfromheader = 1 if $getipfromheader<1;
    $message->{clientip} = $rcvdiplist[$getipfromheader-1];
    $IPFound = 1;
    #print STDERR "Using IP " . $message->{clientip} . "\n";

    #$message->{clientip} = '0.0.0.0' unless $IPFound;
    # If we were told to get the IP address from the headers, and there was one
    #$getipfromheader = @rcvdiplist if $getipfromheader>@rcvdiplist;
    # If they wanted the 2nd Received from address, give'em element 1 of list
    #$message->{clientip} = $rcvdiplist[$getipfromheader-1] if
    #  $getipfromheader>0;
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

    # If we never found the E (end of message file) record, then
    # Postfix is definitely still writing the message.
    unless ($ERecordFound) {
      MailScanner::Log::WarnLog("No end-of-message record found in %s, " .
                                "retrying", $message->{id});
      # JKF 5/12/2005 This could fail with an unblessed reference error
      # JKF 5/12/2005 so do it by hand.
      # JKF 5/12/2005 $message->DropFromBatch();
      $message->{deleted} = 1;
      $message->{gonefromdisk} = 1; # Don't try to delete the original
      $message->{store}->Unlock(); # Unlock it so other processes can pick it up
      #20090421 $message->{abandoned} = 1; # Retry this message as it was ditched

      return 0;
    }

    #20090421 $message->{abandoned} = 1 if $ErrorFound; # Mark message as scrapped

    return 1 if $FROMFound && $TOFound && !$ErrorFound; # && $IPFound;
    #MailScanner::Log::WarnLog("Batch: Found invalid queue file for " .
    #                          "message %s", $message->{id});
    return 0;
  }


  # Read a Postfix record. These are structured as follows:
  # First 1 byte to show the record type. These are nice easy-to-read ASCII.
  # Then 1 or more bytes to show the length. These are encoded so that
  # the bottom 7 bits of each byte hold length data, and the 8th (top) bit
  # is 1 if there is another length byte. The most significant bytes are
  # given first.
  # Then 0 or more bytes of data. No terminator.
  sub ReadRecord {
    my($fh) = @_;
    my($type, $len, $shift, $len_byte, $data);

    # Get the record type
    read $fh, $type, 1 or return (undef,undef);

    # Get the length
    $len = 0;
    $shift = 0;
    while (1) {
      read $fh, $len_byte, 1 or return (undef, undef);
      $len_byte = ord $len_byte;
      if ($shift >= 39) {
        MailScanner::Log::WarnLog("Postfix record too long in ReadRecord()");
        return (undef, undef);
      }
      #print STDERR "ReadRecord: Got length byte $len_byte\n";
      #sleep 1;
      $len |= (($len_byte & 0x7F) << $shift);
      last if ($len_byte & 0x80) == 0;
      $shift += 7;
    }

    # Get the data
    $data = "";
    read $fh, $data, $len if $len;

    $data =~ s/\0//g; # Remove any null bytes
    #print STDERR "ReadRecord: $type \"$data\"\n";
    return ($type, $data);
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
  sub AddHeadersToQf {
    my $this = shift;
    my($message, $headers) = @_;

    my($header, $h, @headerswithouth);
    my($records, $pos);

    if ($headers) {
      #print STDERR "AddHeadersToQf: Headers are $headers\n";
      @headerswithouth = split(/\n/, $headers);
    } else {
      #print STDERR "AddHeadersToQf: Message-Headers are " .
      #             join("\n", @{$message->{headers}}) . "\n";;
      @headerswithouth = @{$message->{headers}};
    }

    # Make complete records ready for insertion in the metadata
    foreach (@headerswithouth) {
      s/^/N/;
    }

    # Look through for the M record that indicates start of message.
    # Insert each line of the headers as an N record just after that.
    $pos = 0;
    $pos++ while($message->{metadata}[$pos] !~ /^M/);
    # $pos now points at M record
    $pos++;
    # Now at position to insert header records
    #print STDERR "Adding headers at $pos\n";
    splice @{$message->{metadata}}, $pos, 0, @headerswithouth;
    #print STDERR "Metadata is now:\n" . join("\n", @{$message->{metadata}}) . "End of metadata\n";
  }

  # Add a header. Needs to look for the position of the M record again
  # so it knows where to insert it.
  sub AddHeader {
    my($this, $message, $newkey, $newvalue) = @_;

    # Find the X record
    my($pos);

    # DKIM: This is for adding the header at the position of the first N record
    # DKIM: Find the first N (or else the X as a safeguard)
    if ($message->{newheadersattop}) {
      $pos = 0;
      while ($pos < $#{$message->{metadata}} &&
             $message->{metadata}[$pos] !~ /^[NX]/) {
        $pos++;
      }
    } else {
      # DKIM: This is for adding the header at the end, pos-->X record
      $pos = $#{$message->{metadata}};
      $pos-- while ($pos >= 0 && $message->{metadata}[$pos] !~ /^X/);
    }
    #print STDERR "*** AddHeader $newkey $newvalue at position $pos\n";

    # Need to split the new header data into the 1st line and a list of
    # continuation lines, creating a new N record for each continuation
    # line.
    my(@lines, $line, $firstline);
    @lines = split(/\n/, $newvalue);
    $firstline = shift @lines;
    # We want a list of N records
    foreach (@lines) {
      s/^/N/;
    }

    # Insert the lines at position $pos
    splice @{$message->{metadata}}, $pos, 0, "N$newkey $firstline", @lines;
  }

  # Delete a header. Must be in an N line plus any continuation N lines
  # that immediately follow it.
  sub DeleteHeader {
    my($this, $message, $key) = @_;

    my $usingregexp = ($key =~ s/^\/(.*)\/$/$1/)?1:0;

    # Add a colon if they forgot it.
    $key .= ':' unless $usingregexp || $key =~ /:$/;
    # If it's not a regexp, then anchor it and sanitise it.
    $key = '^' . quotemeta($key) unless $usingregexp;

    my($pos, $line);
    $pos = 0;
    $pos++ while ($message->{metadata}[$pos] !~ /^M/);
    # Now points at the M record
    $pos++;
    # Now points at first N record
    while ($pos < @{$message->{metadata}}) {
      $line = $message->{metadata}[$pos];
      if ($line =~ s/^N//) {
        unless ($line =~ /$key/i) {
          $pos++;
          next;
        }
        # We have found the start of 1 occurrence of this header
        splice @{$message->{metadata}}, $pos, 1;
        # Delete continuation lines
        while($message->{metadata}[$pos] =~ /^N\s/) {
          splice @{$message->{metadata}}, $pos, 1;
        }
        next;
      }
      $pos++;
    }
  }

  sub UniqHeader {
    my($this, $message, $key) = @_;

    my($pos, $foundat);
    $pos = 0;
    $pos++ while ($message->{metadata}[$pos] !~ /^M/);
    # Now points at the M record
    $pos++;
    # Now points at first N record
    $foundat = -1;
    while ($pos < @{$message->{metadata}}) {
      if ($message->{metadata}[$pos] =~ /^N$key/i) {
        if ($foundat == -1) { # Skip 1st occurrence
          $foundat = $pos;
          $pos++;
          next;
        }
        # We have found the start of 1 occurrence of this header
        splice @{$message->{metadata}}, $pos, 1;
        # Delete continuation lines
        while($message->{metadata}[$pos] =~ /^N\s/) {
          splice @{$message->{metadata}}, $pos, 1;
        }
        next;
      }
      $pos++;
    }
  }

  sub ReplaceHeader {
    my($this, $message, $key, $newvalue) = @_;

    # DKIM: Don't do DeleteHeader if adding headers at top
    $this->DeleteHeader($message, $key) unless $message->{dkimfriendly};
    $this->AddHeader($message, $key, $newvalue);
  }

  # Append to the end of a header if it exists.
  sub AppendHeader {
    my($this, $message, $key, $newvalue, $sep) = @_;

    my($linenum, $oldlocation, $totallines);

    # Try to find the old header
    $oldlocation = -1;
    $totallines = @{$message->{metadata}};

    # Find the start of the header
    for($linenum=0; $linenum<$totallines; $linenum++) {
      last if $message->{metadata}[$linenum] =~ /^M/;
    }
    for($linenum++; $linenum<$totallines; $linenum++) {
      next unless $message->{metadata}[$linenum] =~ /^N$key/i;
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
            $message->{metadata}[$oldlocation] =~ /^N\s/);
    $oldlocation--;

    # Need to split the new header data into the 1st line and a list of
    # continuation lines, creating a new N record for each continuation
    # line.
    my(@lines, $line, $firstline);
    @lines = split(/\n/, $newvalue);
    $firstline = shift @lines;
    # We want a list of N records
    foreach (@lines) {
      s/^/N/;
    }
    # Add 1st line onto the end of the header
    $message->{metadata}[$oldlocation] .= "$sep$firstline";
    # Insert any continuation lines into the metadata just after the 1st line
    splice @{$message->{metadata}}, $oldlocation+1, 0, @lines;
  }

  # Insert text at the start of a header if it exists.
  sub PrependHeader {
    my($this, $message, $key, $newvalue, $sep) = @_;

    my($linenum, $oldlocation, $totallines);

    # Try to find the old header
    $oldlocation = -1;
    $totallines = @{$message->{metadata}};

    # Find the start of the header
    for($linenum=0; $linenum<$totallines; $linenum++) {
      last if $message->{metadata}[$linenum] =~ /^M/;
    }
    for($linenum++; $linenum<$totallines; $linenum++) {
      next unless $message->{metadata}[$linenum] =~ /^N$key/i;
      $oldlocation = $linenum;
      last;
    }

    # Didn't find it?
    if ($oldlocation<0) {
      $this->AddHeader($message, $key, $newvalue);
      return;
    }

    $message->{metadata}[$oldlocation] =~ s/^N$key\s*/N$key $newvalue$sep/i;
  }

  sub TextStartsHeader {
    my($this, $message, $key, $text) = @_;

    my($linenum, $oldlocation, $totallines);

    # Try to find the old header
    $oldlocation = -1;
    $totallines = @{$message->{metadata}};

    # Find the start of the header
    for($linenum=0; $linenum<$totallines; $linenum++) {
      last if $message->{metadata}[$linenum] =~ /^M/;
    }
    for($linenum++; $linenum<$totallines; $linenum++) {
      next unless $message->{metadata}[$linenum] =~ /^N$key/i;
      $oldlocation = $linenum;
      last;
    }

    # Didn't find it?
    return 0 if $oldlocation<0;

    return 1 if $message->{metadata}[$oldlocation] =~
                                   /^N$key\s+\Q$text\E/i;
    return 0;
  }

  # BUG BUG BUG This contains a problem where it will not
  # find the text on the end of a multi-line header. Need to
  # flag multi-line headers so change the final regexp.
  sub TextEndsHeader {
    my($this, $message, $key, $text) = @_;

    my($linenum, $oldlocation, $lastline, $totallines);

    # Try to find the old header
    $oldlocation = -1;
    $totallines = @{$message->{metadata}};

    # Find the start of the header
    for($linenum=0; $linenum<$totallines; $linenum++) {
      last if $message->{metadata}[$linenum] =~ /^M/;
    }
    for($linenum++; $linenum<$totallines; $linenum++) {
      next unless $message->{metadata}[$linenum] =~ /^N$key/i;
      $oldlocation = $linenum;
      last;
    }

    # Didn't find it?
    return 0 if $oldlocation<0;

    # Find the last line of the header
    $lastline = $oldlocation;
    do {
      $lastline++;
    } while($lastline<$totallines &&
            $message->{metadata}[$lastline] =~ /^N\s/);
    $lastline--;
    $key = '\s' unless $lastline == $oldlocation;

    return 1 if $message->{metadata}[$lastline] =~
                                   /^N$key.+\Q$text\E$/i;
    return 0;
  }


  # Add recipient R records to the end of the metadata, just before
  # the terminating E record
  sub AddRecipients {
    my $this = shift;
    my($message, @recips) = @_;

    # Remove all the duplicates @recips
    my %uniqueto;
    foreach (@recips) {
      $uniqueto{$_} = 1;
    }
    @recips = keys %uniqueto;

    my $totallines = @{$message->{metadata}};

    foreach (@recips) {
      s/^/R/;
    }

    # Changed 2 to 1 in next line for Postfix 2.1
    splice @{$message->{metadata}}, $totallines-1, 0, @recips;
    #print STDERR "AddRecipients: " . join(',',@recips) . "\n";
    #print STDERR "metadata is \"" . join("\n", @{$message->{metadata}}) . "\n";
  }

  # Delete the original recipients from the message. We'll add some
  # using AddRecipients later.
  sub DeleteRecipients {
    my $this = shift;
    my($message) = @_;

    #print STDERR "Deleting Recipients!\n";
    my($linenum);
    for ($linenum=0; $linenum<@{$message->{metadata}}; $linenum++) {
      # Looking for "recipient" lines
      # Should allow 'O' here as well
      # JKF 30/08/2006 next unless $message->{metadata}[$linenum] =~ /^[RO]/;
      # Thanks to Holger Gebhard for this.
      #BUGGY: next unless $message->{metadata}[$linenum] =~ /^[ARO].+@(?:\w|-|\.)+\.\w{2,})/;
      #next unless $message->{metadata}[$linenum] =~ /^[ARO]/;
      next unless $message->{metadata}[$linenum] =~ /^[ARO].+@(?:\w|-|\.)+\.\w{2,}/;
      # Have found the right line
      #print STDERR "Deleting recip " . $message->{metadata}[$linenum] . "\n";
      splice(@{$message->{metadata}}, $linenum, 1);
      $linenum--; # Study the same line again
    }
  }


  # Send an I down the FIFO to the Postfix queue manager, so that it reads
  # its incoming queue.
  # I am passed a hash of queues --> space-separated string of message ids
  sub KickMessage {
    my($queue2ids, $sendmail2) = @_;
    my($queue);

    # Do a kick for every queue that contains some message ids
    foreach $queue (keys %$queue2ids) {
      next unless $queue2ids->{$queue};

      # Using the spool directory with the last element chopped off,
      # find the public directory wth the qmgr FIFO in it. Send an I
      # to that FIFO.
      my $public = $queue;
      $public =~ s/[^\/]+$/public/;
      next unless $public; # Sanity checking!
      my $fh = new FileHandle;
      $fh->open(">$public/qmgr") or
        MailScanner::Log::WarnLog("KickMessage failed as couldn't write to " .
                                  "%s, %s", "$public/qmgr", $!);
      print $fh "I";
      $fh->close;
    }
    return 0;
  }

  # Does not exist in Postfix as there is only 1 file per message.
  #sub CreateQf {
  #  my($message) = @_;
  #
  #  return join("\n", @{$message->{metadata}}) . "\n\n";
  #}

  # Produce a string containing everything that goes before the first
  # N record of the message, including all the headers and the separator
  # line.
  sub PreDataString {
    #my $this = shift;
    my($message) = @_;

    my($linenum, $result, $type, $data, $to, $preNlen);
    my $TimestampFound = 0;

    #print STDERR "In PreDataString\n";
    # Output all the metadata records up until (& including) the M record.
    $linenum = 0;
    $result  = '';
    foreach (@{$message->{metadata}}) {
      /^(.)(.*)$/;
      ($type, $data) = ($1, $2);
      $TimestampFound++ if $type eq 'T'; # Must only ever have 1 timestamp
      #print STDERR "PreData1 Type $type Data $data\n";
      last if $type eq 'M';
      $result .= Record2String($type, $data);
      # Make the S record appear just after the T record
      # as that's where Postfix likes to see it.
      $result .= Record2String('S', $message->{from}) if $type eq 'T';
      #print STDERR "PreData $type $data\n";
      $linenum++;
    }
    # The recipients are already in the pre-message string.
    ## Add the recipients
    ## If there is more than 1 recipient, then place original recips in the
    ## 'O' list. If only 1 then just put it in an 'R' record.
    #if (scalar(@{$message->{to}}) > 1 && defined($message->{originalrecips})) {
    #  # There are several recips and there is an originalrecips list
    #  my $RecordType;
    #  foreach $to (@{$message->{to}}) {
    #    $RecordType = $message->{originalrecips}{"$to"}?'O':'R';
    #    $result .= Record2String($RecordType, $to);
    #  }
    #} else {
    #  foreach $to (@{$message->{to}}) {
    #    $result .= Record2String('R', $to);
    #  }
    #}

    # Add the M record to mark the start of the headers
    $result .= Record2String('M', $data);
    $linenum++;

    # Store the length of th estring so far as we need to return it
    $preNlen = length($result);

    my $totallines = scalar(@{$message->{metadata}});
    # Add the headers
    for ($linenum=$linenum; $linenum<$totallines; $linenum++) {
      #$_ = $message->{metadata}[$linenum];
      $message->{metadata}[$linenum] =~ /^(.)(.*)$/;
      ($type, $data) = ($1, $2);
      #print STDERR "PreData2 Type $type Data $data\n";
      last if $type eq 'X';
      $result .= Record2String($type, $data);
      #print STDERR "Pre $type $data\n";
    }

    # Add the header-body separator line if there is a message body
    #print STDERR "No body flag is " . $message->{nobody} . "\n";
    $result .= Record2String('N', "") unless $message->{nobody};

    #print STDERR "Result of PreDataString is $result\n";
    # Return the string and the length of the data before any N records
    return ($result, $preNlen, $TimestampFound);
  }

  sub PostDataString {
    #my $this = shift;
    my($message) = @_;

    my($result, $type, $data);
    my($record, $recordnum);
    my $TimestampFound = 0;
    $result = Record2String('X', "");

    $recordnum = @{$message->{metadata}} - 1;
    $recordnum-- while($message->{metadata}[$recordnum] !~ /^X/);
    for($recordnum++; $recordnum<@{$message->{metadata}}; $recordnum++) {
      $record = $message->{metadata}[$recordnum];
      $record =~ /^(.)(.*)$/;
      ($type, $data) = ($1, $2);
      $result .= Record2String($type, $data);
      $TimestampFound++ if $type eq 'T';
      #print STDERR "Post $type $data\n";
    }

    return($result, $TimestampFound);
  }


  sub Record2String {
    my($rectype, $recdata) = @_;

    return "" if $rectype eq ""; # Catch empty records

    my($result, $len_byte, $len_rest);
    $result = "";
    $result .= $rectype;

    $len_rest = length($recdata);
    do {
        $len_byte = $len_rest & 0x7F;
        $len_byte |= 0x80 if $len_rest >>= 7;
        $result .= pack 'C', $len_byte;
    } while ($len_rest != 0);
    $result .= $recdata;
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

    $fh = new FileHandle;
    $fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
              " $SendmailOptions '" . $sender . "'")
      or MailScanner::Log::WarnLog("Could not send email message, %s", $!),
         return 0;
    $fh->print($email);
    $fh->close();

    1;
  }


  # Send an email message containing the attached MIME entity.
  # Also passed in the sender's address.
  sub SendMessageEntity {
    my $this = shift;
    my($message, $entity, $sender) = @_;

    my($fh);

    $fh = new FileHandle;
    $fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
              " $SendmailOptions '" . $sender . "'")
      or MailScanner::Log::WarnLog("Could not send email entity, %s", $!),
           return 0;
    $entity->print($fh);
    $fh->close();

    1;
  }


# Work out the hash directory depth from the current directory.
# It is either ./dir1/files or ./dir1/dir2/files.
# I need to open ./dir then read from it. If I find a dir in there
# then the depth must be 2. Otherwise the depth is 1?
# If I find nothing then sleep and work it out again.
sub FindHashDirDepth {
  my($mta) = @_;

  my($delay, $foundanything, $here, $dir1name, $filename, $dir1, $filecount);

  $delay = MailScanner::Config::Value('queuescaninterval');
  $foundanything = 0;
  $here = new DirHandle;
  $dir1 = new DirHandle;

  #MailScanner::Log::WarnLog("JKF: Hash dir depth value being calculated");
  while(1) {
    $filecount = 0;
    $here->open('.')
      or MailScanner::Log::DieLog("Cannot open directory . when finding depth");
    while(defined($dir1name = $here->read())) {
      #MailScanner::Log::WarnLog("JKF: Reading %s from dir .", $dir1name);
      next if $dir1name eq '.' || $dir1name eq '..';
      $filecount++ if -f $dir1name && $dir1name =~ /$mta->{HDFileRegexp}/;
      next unless -d $dir1name;
      $dir1->open($dir1name)
        or MailScanner::Log::DieLog("Cannot open dir %s when finding depth",
                                    $dir1name);
      while(defined($filename = $dir1->read())) {
        #MailScanner::Log::WarnLog("JKF: Reading %s from inner dir %s",
        #                          $filename, $dir1name);
        next if $filename eq '.' || $filename eq '..';
        if (-f "$dir1name/$filename" && $filename =~ /$mta->{HDFileRegexp}/) {
          # We have found a queue file inside dir1
          $dir1->close();
          $here->close();
          #MailScanner::Log::InfoLog("Postfix queue structure is depth 1");
          return 1;
        }
        if (-d "$dir1name/$filename" && $filename =~ /^.$/) {
          # We have found another hashing directory, so it must be depth 2
          $dir1->close();
          $here->close();
          #MailScanner::Log::InfoLog("Postfix queue structure is depth 2");
          return 2;
        }
      }
      $dir1->close();
    }
    $here->close();

    # Didn't find anything at all, so sleep waiting for a file or a dir
    # to appear in the queue.
    # Can now be 0, 1 or 2: MailScanner::Log::WarnLog("Messages found but no hashed queue directories. Please enable hashed queues for incoming and deferred with a depth of 1 or 2. See the Postfix documentation for hash_queue_names and hash_queue_depth")
    return 0
      if $filecount>0;
    sleep($delay);
  }
}


  # Create a MessageBatch object by reading the queue and filling in
  # the passed-in batch object.
  sub CreateBatch {
    my $this = shift;
    my($batch, $onlyid) = @_;

    my($queuedirname, $queuedir, $queue1dir, $queue2dir, $MsgsInQueue);
    my($getipfromheader, $DirtyMsgs, $DirtyBytes, $CleanMsgs, $CleanBytes);
    my($HitLimit1, $HitLimit2, $HitLimit3, $HitLimit4);
    my($MaxCleanB, $MaxCleanM, $MaxDirtyB, $MaxDirtyM);
    my(%ModDate, $mta, $file, $file1, $file2, $tmpdate);
    my(@SortedFiles, $id, $newmessage, @queuedirnames);
    my($batchempty, $h1, $h2, $delay, $CriticalQueueSize);
    my($nlinks, $headerfileumask, $invalidfiles, $mtime);

    $queuedir  = new DirHandle;
    $queue1dir = new DirHandle;
    $queue2dir = new DirHandle;
    $MsgsInQueue = 0;
    $delay     = MailScanner::Config::Value('queuescaninterval');
    $getipfromheader = MailScanner::Config::Value('getipfromheader');
    #print STDERR "Inq = " . $global::MS->{inq} . "\n";
    #print STDERR "dir = " . $global::MS->{inq}{dir} . "\n";
    @queuedirnames = @{$global::MS->{inq}{dir}};

    ($MaxCleanB, $MaxCleanM, $MaxDirtyB, $MaxDirtyM)
                      = MailScanner::MessageBatch::BatchLimits();

    # If there are too many messages in the queue, start processing in
    # directory storage order instead of date order.
    $CriticalQueueSize = MailScanner::Config::Value('criticalqueuesize');

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
        $mta = $global::MS->{mta};

        # If we haven't found the hash directory depth yet, then work it out
        #MailScanner::Log::WarnLog("JKF: About to work out hash dir depth");
        $MailScanner::SMDiskStore::HashDirDepth = FindHashDirDepth($mta)
          unless $MailScanner::SMDiskStore::HashDirDepth >= 0;
        #MailScanner::Log::WarnLog("JKF: Hash dir depth is %d",
        #  $MailScanner::SMDiskStore::HashDirDepth);

        $queuedir->open('.')
          or MailScanner::Log::DieLog("Cannot open queue dir %s for reading " .
                                      "message batch, %s", $queuedirname, $!);
        #print STDERR "Searching " . $queuedirname . " for messages\n";

        # Got to read directories and child directories here and find
        # files in the the child directories.
        while(defined($file = $queuedir->read())) {
          next if $file eq '.' || $file eq '..';
          if ($MailScanner::SMDiskStore::HashDirDepth==0) {
            next unless $file =~ /$mta->{HDFileRegexp}/;
            push @SortedFiles, "$queuedirname/$file";
            if ($UnsortedBatchesLeft<=0) {
              # Running normally
              ($nlinks, $tmpdate) = (stat($file))[3,9]; # 9 = mtime
              next if -z _;
              next unless -f _;
              next unless -R _;
              next if $nlinks>1; # Catch files being moved into "deferred"
              $ModDate{"$queuedirname/$file"} = $tmpdate;
            }
            $MsgsInQueue++;
            #print STDERR "Stored depth 0 message file $file\n";
            next;
          }
          next unless -d $file;
          $queue1dir->open($file) or next;
          while(defined($file1 = $queue1dir->read())) {
            next if $file1 eq '.' || $file1 eq '..' || $file1 eq 'core';
            if ($MailScanner::SMDiskStore::HashDirDepth==1) {
              next unless $file1 =~ /$mta->{HDFileRegexp}/;
              push @SortedFiles, "$queuedirname/$file/$file1";
              if ($UnsortedBatchesLeft<=0) {
                # Running normally
                ($nlinks, $tmpdate) = (stat("$file/$file1"))[3,9]; # 9 = mtime
                next if -z _;
                next unless -f _;
                next unless -R _;
                next if $nlinks>1; # Catch files being moved into "deferred"
                $ModDate{"$queuedirname/$file/$file1"} = $tmpdate;
              }
              $MsgsInQueue++;
              #print STDERR "Stored depth 1 message file $file1\n";
              next;
            } else {
              # It is depth 2 so read another dir down
              next unless -d "$file/$file1";
              $queue2dir->open("$file/$file1") or next;
              while(defined($file2 = $queue2dir->read())) {
                next if $file2 eq '.' || $file2 eq '..' || $file2 eq 'core';
                next unless $file2 =~ /$mta->{HDFileRegexp}/;
                push @SortedFiles, "$queuedirname/$file/$file1/$file2";
                if ($UnsortedBatchesLeft<=0) {
                  # Running normally
                  ($nlinks, $tmpdate) = (stat("$file/$file1/$file2"))[3,9];
                  next if -z _; # Skip 0-length queue files
                  next unless -f _;
                  next unless -R _;
                  next if $nlinks>1; # Files being moved into "deferred"
                  $ModDate{"$queuedirname/$file/$file1/$file2"} = $tmpdate;
                }
                $MsgsInQueue++;
                #print STDERR "Stored depth 2 message file $file2\n";
              }
              $queue2dir->close;
            }
          }
          $queue1dir->close;
        }
        $queuedir->close;
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
      while(defined($file = shift @SortedFiles) &&
            $HitLimit1+$HitLimit2+$HitLimit3+$HitLimit4<1) {

        # In accelerated queue-clearing mode, so we don't know anything yet
        if ($UnsortedBatchesLeft>0) {
          ($nlinks, $mtime) = (stat $file)[3,9];
          next if -z _; # Skip 0-length queue files
          next unless -f _;
          next unless -R _;
          next if $nlinks>1; # Files being moved into "deferred"
        } else {
          $mtime = $ModDate{$file};
        }

        # Yes I know this is a hack but it will help isolate the problem
        #next if $ModDate{$file} > time-3;

        # must separate next two lines or $1 gets re-tainted by being part of
        # same expression as $file [mumble mumble grrr mumble mumble]
        #print STDERR "Reading file $file from list\n";
        # Split pathname into dir and file again
        my $fullpath = $file;
        ($queuedirname, $h1, $h2, $file) = ($1,$2,$3,$4)
          if $MailScanner::SMDiskStore::HashDirDepth == 2 &&
             $file =~ /^(.*)\/(.)\/(.)\/([^\/]+)$/;
        ($queuedirname, $h1, $file) = ($1,$2,$3)
          if $MailScanner::SMDiskStore::HashDirDepth == 1 &&
             $file =~ /^(.*)\/(.)\/([^\/]+)$/;
        ($queuedirname, $file) = ($1,$2)
          if $MailScanner::SMDiskStore::HashDirDepth == 0 &&
             $file =~ /^(.*)\/([^\/]+)$/;
        next unless $file =~ /$mta->{HDFileRegexp}/;
        # Put the real message id in $idorig and the unique name in $id
        # JKF Add a dot followed by a random number to try to get a unique
        # JKF filename, as Postfix re-uses filenames too often.
        my $idtemp = $1;
        # If they want a particular message id, ignore it if it doesn't match
        next if $onlyid ne "" && $idtemp ne $onlyid;

        #my $id = $idtemp . sprintf(".%05X", int(rand 1000000)+1);
        # Don't put a random number on the end, put a reasonable hash of
        # the file on the end.
        # JKF 20090423 Add a "P" in the middle of so it cannot be a number.
        my $id = $idtemp . '.' . PostfixKey($fullpath);
        #print STDERR "ID = $id\n";
        my $idorig = $idtemp;

        #print STDERR "Adding $id to batch\n";

        # Lock and read the qf file. Skip this message if the lock fails.
        $newmessage = MailScanner::Message->new($id, $queuedirname,
                                                $getipfromheader);
        if ($newmessage && $newmessage->{INVALID}) {
          #$invalidfiles .= "$id ";
          $invalidfiles .= "$idorig ";
          undef $newmessage;
          next;
        }
        next unless $newmessage;
        next if $newmessage->{INVALID};
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
        #print STDERR "Added $id to batch\n";
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
      sleep($delay) if $batchempty;
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

# Given a filename, read the first 256 bytes of the file and calculate a
# checksum based on those bytes. It must consist of a string of 5 digits
# from the range 0-9.
sub PostfixKey {
  my($fname) = @_;

  my($fh, $data, $bytesread);

  $fh = new FileHandle;
  open($fh, "< " . $fname) or return '00000';
  seek($fh, 0, 0) or return '00000';
  
  $data = '0' x 256;
  $bytesread = read $fh, $data, 256;
  return '00000' unless $bytesread;

  # This is the "Fletcher" checksum algorithm, in case you want to look it up
  # Thanks to jd@oddlittle.me for this one!
  my($acc1, $acc2, $char, $checksum);
  foreach $char (unpack "C*", $data) {
    $acc1 = ($acc1 + $char) & 0xFF;
    $acc2 = ($acc2 + $acc1) & 0xFF;
  }
  $checksum = uc(sprintf("A%04X", (($acc1<<8) + $acc2) & 0xFFFF));

  close($fh);

  return $checksum;
}


# Return the array of headers from this message, optionally with a
# separator on the end of each one.
# This is in Sendmail.pm as the storage of the headers array is specific
# to the MTA being used.
sub OriginalMsgHeaders {
  my $this = shift;
  my($message, $separator) = @_;

  # No separator so just return the array
  return @{$message->{headers}} unless $separator;

  # There is a separator
  my($h,@result);
  foreach $h (@{$message->{headers}}) {
    push @result, $h . $separator;
  }
  #print STDERR "OriginalMsgHeaders: Result is \"" . @result . "\"\n";
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
sub CheckQueueIsFlat {
  my($dir) = @_;

  # This is a no-op for Postfix as we have to support the hash
  # directory structure.
  return 1;
}

1;
