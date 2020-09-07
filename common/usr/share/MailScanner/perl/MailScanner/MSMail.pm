#   MailScanner - SMTP Email Processor
#   Copyright (C) 2018-2020 MailScanner project
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
#    Contributed by Shawn Iverson for MailScanner <shawniverson@efa-project.org>
#    Adapted from Postfix.pm


package MailScanner::Sendmail;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use DirHandle;
use Encode;

use vars qw($VERSION);

use IO::Socket::UNIX;
use IO::Socket::INET;
use Net::Domain qw(hostname hostfqdn hostdomain domainname);

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
    #$file = sprintf("%05X%lX", int(rand 1000000)+1, (stat($file))[1]);
    #print STDERR "New Filename is $file\n";

    #
    # Alvaro Marin alvaro@hostalia.com - 2016/08/25
    # 
    # Support for Postfix's long queue IDs format (enable_long_queue_ids).
    # The name of the file created in the outgoing queue will be the queue ID. 
    # We'll generate it like Postfix does. From src/global/mail_queue.h :
    #
    # The long non-repeating queue ID is encoded in an alphabet of 10 digits,
    # 21 upper-case characters, and 21 or fewer lower-case characters. The
    # alphabet is made "safe" by removing all the vowels (AEIOUaeiou). The ID
    # is the concatenation of:
    #
    # - the time in seconds (base 52 encoded, six or more chars),
    # 
    # - the time in microseconds (base 52 encoded, exactly four chars),
    # 
    # - the 'z' character to separate the time and inode information,
    #
    # - the inode number (base 51 encoded so that it contains no 'z').
    #
    #
    # We don't know if Postfix has long queue IDs enabled so we must check it 
    # using the temporaly filename:
    # Short queue IDs: /var/spool/postfix/incoming/temp-14793-6773D15E4E9.A3F46
    # Long queue IDs: /var/spool/postfix/incoming/temp-17735-3sK9pc0mftzJX5P.A38B9
    #
    my $long_queue_id=0;
    my $hex;
    if ($file !~ /\-[A-F0-9]+\.[A-Za-z0-9]{5}$/) {
        my $file_orig=$file;
        # Long queue IDs
        $long_queue_id=1;
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

        $file_out.="z";

        my $inode=(stat("$file"))[1];
        $encoded='';
        $count=0;
        while ($count < 4) {
                $encoded.=$BASE52_CHARACTERS[$inode%51];
                $inode/=51;
                $count++;
        }
        $file=$file_out.reverse $encoded;
	# We need this for later use...
	$hex = sprintf("%05X", $microseconds_orig);
      	#print STDERR "long_queue_id: New Filename is $file\n";

        # We check the generated ID...
        if ($file !~ /[A-Za-z0-9]{12,20}/) {
                # Something has gone wrong, back to short ID for safety
                MailScanner::Log::WarnLog("ERROR generating long queue ID ($file), back to short ID ($file_orig)");
                $file = sprintf("%05X%lX", int(rand 1000000)+1, (stat($file_orig))[1]);
                $long_queue_id=0;
        }
    }
    else {
        # Short queue IDs
        # Bad hash key $file = sprintf("%05X%lX", time % 1000000, (stat($file))[1]);
        # Add 1 so the number is never zero (defensive programming)
        $file = sprintf("%05X%lX", int(rand 1000000)+1, (stat($file))[1]);
        #print STDERR "New Filename is $file\n";
    }

    if ($MailScanner::SMDiskStore::HashDirDepth == 2) {
	if ($long_queue_id){
		# hash queues with long queue IDs
		$hex =~ /^(.)(.)/;
		return ($dir,$1,$2,$file);
	}
	else {
		# hash queues with short queue IDs
		$file =~ /^(.)(.)/;
		return ($dir,$1,$2,$file);
	}
    } elsif ($MailScanner::SMDiskStore::HashDirDepth == 1) {
	if ($long_queue_id){
		# hash queues with long queue IDs
                $hex =~ /^(.)/;
      		return ($dir,$1,$file);
	}
	else {
		# hash queues with short queue IDs
		$file =~ /^(.)/;
		return ($dir,$1,$file);
	}
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

    my($from);
    my($ip);
    # ORIGFound stuff courtesy of Juan Pablo Abuyeres 23/7/2006
    # Should improve handling of virtual domains.
    my($ORIGFound, $TOFound, $FROMFound, $IPFound);
    my($recdata);
    my $InSubject = 0; # Are we adding continuation subject lines?
    my $InTo = 0;
    my $InFrom = 0;
    my(@rcvdiplist);
    my $RecvFound = 0;
    my $UnfoldBuffer = '';

    my $org = MailScanner::Config::DoPercentVars('%org-name%');

    MailScanner::Log::DebugLog("MSMail: ReadQf: org = $org");

    $message->{nobody} = 1; #assume no body unless detected

    # Just in case we get a message with no headers at all
    @{$message->{headers}} = ();

    # Seek to the start of the file in case anyone read the file
    # between me opening it and locking it.
    seek $RQf, 0, 0;

    # Read milter pre-data headers until we hit the start of the message header
    my $pos - 0;
    while($recdata = ReadRecord($RQf)) {
        if ($recdata =~ /^O/) {
            # Recipient address
            $recdata =~ s/^O//;
            $recdata =~ s/^.*\<//;
            $recdata =~ s/^\<//;
            $recdata =~ s/\>.*$//;
            $recdata =~ s/\>$//;
            # If recipient is empty only add metadata
            push @{$message->{to}}, lc($recdata);
            next unless $recdata ne '';
            $TOFound = 1;
            $ORIGFound = 1;
            MailScanner::Log::DebugLog("MSMail: ReadQf: orig rcpt = $recdata");
            # Postfix compat
            push @{$message->{metadata}}, "O$recdata";
            $pos = tell $RQf
        } elsif ($recdata =~ /^S/) {
            $recdata =~ s/^S//;
            $recdata =~ s/^.*\<//;
            $recdata =~ s/^\<//;
            $recdata =~ s/\>.*$//;
            $recdata =~ s/\>$//;
            $message->{from} = lc($recdata);
            $FROMFound = 1;
            # Postfix compat
            push @{$message->{metadata}}, "S$recdata";
            MailScanner::Log::DebugLog("MSMail: ReadQf: from = $recdata");
            $pos = tell $RQf
        } elsif ($recdata =~ /^E</) {
            $recdata =~ s/^E<//;
            $recdata =~ s/\>$//;
            push @{$message->{metadata}}, "E$recdata";
            MailScanner::Log::DebugLog("MSMail: ReadQf: from = $recdata");
            $pos = tell $RQf
        } else {
            last;
        }
    }

    # Seek to previous line
    seek $RQf, $pos, 0;

    # Read records until we hit the start of the message record
    my $headerComplete = 0;
    while($recdata = ReadRecord($RQf)) {
       if ($headerComplete == 0) {
           push @{$message->{headers}}, $recdata;

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

          if ($InTo) {
            if ($recdata =~ /^\s/) {
                # In a continuation line
                $recdata =~ s/^\s//;
                $UnfoldBuffer .= ' ' . $recdata;
            } else {
                # End of To field
                my $to = $UnfoldBuffer;
                $to =~ s/^To: //;
                foreach $recdata (split /,/, $to) {
                    $recdata =~ s/^.*\<//;
                    $recdata =~ s/^\<//;
                    $recdata =~ s/\>.*$//;
                    $recdata =~ s/\>$//;
                    $recdata = lc($recdata);
                    push @{$message->{to}}, lc($recdata) unless $ORIGFound;
                    # Postfix compat
                    push @{$message->{metadata}}, "R$recdata";
                    $message->{postfixrecips}{lc("$recdata")} = 1;
                    $TOFound = 1;
                    MailScanner::Log::DebugLog("MSMail: ReadQf: to = $recdata");
                }
                $InTo=0;
             }
         }

         if ($recdata =~ m/^To: /i) {
            # RFC 822 unfold address field
            $UnfoldBuffer = $recdata;
            $InTo = 1;
            next;
          } elsif ($recdata =~ /^Received:/i) {
             my $rcvdip = '127.0.0.1';
             if ($recdata =~ /^Received: .+?\(.*?\[(?:IPv6:)?([0-9a-f.:]+)\]/i) {
                 $rcvdip = $1;
                 push @rcvdiplist, $rcvdip;
                 MailScanner::Log::DebugLog("MSMail: ReadQf: ip = $rcvdip");
            }
            next;
          } elsif ($recdata eq '') {
            # Empty line signals end of header
            $headerComplete = 1;
            MailScanner::Log::DebugLog("MSMail: ReadQf: End of Header found");
            next;
          } elsif ($recdata =~ /^Subject:\s*(\S.*)?$/i) {
              $message->{subject} = $1;
              $InSubject = 1;
              MailScanner::Log::DebugLog("MSMail: ReadQf: subject found");
              next;
          }
        } else {
            # if we landed here, there's a body
            $message->{nobody} = 0; 
            MailScanner::Log::DebugLog("MSMail: ReadQf: body found");
            last;
        }
    }
    # Remove all the duplicates from ->{to}
    my %uniqueto;
    foreach (@{$message->{to}}) {
      $uniqueto{$_} = 1;
    }
    @{$message->{to}} = keys %uniqueto;

    # There will always be at least 1 Received: header, even if 127.0.0.1
    push @rcvdiplist, '127.0.0.1' unless @rcvdiplist;
    # Don't fall off the end of the list
    $getipfromheader = @rcvdiplist if $getipfromheader>@rcvdiplist;
    # Don't fall off the start of the list
    $getipfromheader = 1 if $getipfromheader<1;
    $message->{clientip} = $rcvdiplist[$getipfromheader-1];
    $IPFound = 1;

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

    return 1 if $FROMFound && $TOFound; 

    return 0;
  }

  # Read a Message record. These are structured as follows:
  # Plain old newline terminated message
  sub ReadRecord {
    my($fh) = @_;
    my($data);

    return undef if eof($fh);
    
    # Get the data
    $data = "";
    $data = readline $fh;
    $data =~ s/\n//;
  
    return ($data);
  }

  sub AddHeadersToQf {
      my $this = shift;
      my($message, $headers) = @_;

      my($header, $h, @headers);
      my($records, $pos);

      if ($headers) {
        @headers = split(/\n/, $headers);
      } else {
        @headers = @{$message->{headers}};
      }

      # Add to end of metadata, skipping over postfix compat lines
      foreach $header (@headers) {
          push @{$message->{metadata}}, 'H' . $header;
      }
  }

  # Add a header to the message
  sub AddHeader {
      my($this, $message, $newkey, $newvalue) = @_;
      
      my($pos);
  
      # DKIM friendly add?
      if ($message->{newheadersattop}) {
          $pos = 0;
          while ($pos < $#{$message->{metadata}} &&
               $message->{metadata}[$pos] !~ /^H/) {
               $pos++;
          }
      } else {
           $pos = $#{$message->{metadata}};
           $pos++;
      }

      # Need to split the new header data into the 1st line and a list of
      # continuation lines, creating a new H record for each continuation
      # line.
      my(@lines, $line, $firstline);
      @lines = split(/\n/, $newvalue);
      $firstline = shift @lines;
      foreach (@lines) {
        s/^/H/;
      }

      splice @{$message->{metadata}}, $pos, 0, "H$newkey $firstline", @lines;
  }

  sub DeleteHeader {
      my($this, $message, $key) = @_;
      my $usingregexp = ($key =~ s/^\/(.*)\/$/$1/)?1:0;

      # Add a colon if they forgot it.
      $key .= ':' unless $usingregexp || $key =~ /:$/;
      # If it's not a regexp, then anchor it and sanitise it.
      $key = '^' . quotemeta($key) unless $usingregexp;
     
      my($pos, $line);
      $pos = 0;
      $pos++ while ($message->{metadata}[$pos] !~ /^H/);
      while ($pos < @{$message->{metadata}}) {
          $line = $message->{metadata}[$pos];
          if ($line =~ s/^H//) {
              unless ($line =~ /$key/i) {
                  $pos++;
                  next;
              }
          }
          # We have found the start of 1 occurrence of this header
          splice @{$message->{metadata}}, $pos, 1;
          # Delete continuation lines
          while($message->{metadata}[$pos] =~ /^H\s/) {
              splice @{$message->{metadata}}, $pos, 1;
          }
          next;
      }
  }

  sub UniqHeader {
      my($this, $message, $key) = @_;

      my($pos, $foundat);
      $pos = 0;
      $pos++ while ($message->{metadata}[$pos] !~ /^H/);
      $foundat = -1;
      while ($pos < @{$message->{metadata}}) {
          if ($message->{metadata}[$pos] =~ /^H$key/i) {
              if ($foundat == -1) { # Skip 1st occurrence
                  $foundat = $pos;
                  $pos++;
                  next;
              }
              # We have found the start of 1 occurrence of this header
              splice @{$message->{metadata}}, $pos, 1;
              # Delete continuation lines
              while($message->{metadata}[$pos] =~ /^H\s/) {
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

  sub AppendHeader {
      my($this, $message, $key, $newvalue, $sep) = @_;

      my($linenum, $oldlocation, $totallines);

      # Try to find the old header
      $oldlocation = -1;
      $totallines = @{$message->{metadata}};

      for($linenum=0; $linenum<$totallines; $linenum++) {
          last if $message->{metadata}[$linenum] =~ /^H/;
      }

      for($linenum++; $linenum<$totallines; $linenum++) {
        next unless $message->{metadata}[$linenum] =~ /^H$key/i;
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
          $message->{metadata}[$oldlocation] =~ /^H\s/);
      $oldlocation--;

      my(@lines, $line, $firstline);
      @lines = split(/\n/, $newvalue);
      $firstline = shift @lines;
      foreach (@lines) {
          s/^/H/;
      }
      $message->{metadata}[$oldlocation] .= "$sep$firstline";
      splice @{$message->{metadata}}, $oldlocation+1,0, @lines;
  }

  sub PrependHeader {
      my($this, $message, $key, $newvalue, $sep) = @_;

      my($linenum, $oldlocation, $totallines);

      # Try to find the old header
      $oldlocation = -1;
      $totallines = @{$message->{metadata}};

      # Find the start of the header
      for($linenum=0; $linenum<$totallines; $linenum++) {
          last if $message->{metadata}[$linenum] =~ /^H/;
      }

      for($linenum++; $linenum<$totallines; $linenum++) {
          next unless $message->{metadata}[$linenum] =~ /^H$key/i;
          $oldlocation = $linenum;
          last;
      }

      # Didn't find it?
      if ($oldlocation<0) {
         $this->AddHeader($message, $key, $newvalue);
         return;
       }

       $message->{metadata}[$oldlocation] =~ s/^H$key\s*/H$key $newvalue$sep/i;
  }

  sub TextStartsHeader {
      my($this, $message, $key, $text) = @_;

      my($linenum, $oldlocation, $totallines);

      # Try to find the old header
      $oldlocation = -1;
      $totallines = @{$message->{metadata}};

      for($linenum=0; $linenum<$totallines; $linenum++) {
          last if $message->{metadata}[$linenum] =~ /^H/;
      }

      for($linenum++; $linenum<$totallines; $linenum++) {
        next unless $message->{metadata}[$linenum] =~ /^H$key/i;
        $oldlocation = $linenum;
        last;
      }

      # Didn't find it?
      return 0 if $oldlocation<0;

      return 1 if $message->{metadata}[$oldlocation] =~
                                   /^H$key\s+\Q$text\E/i;
      return 0;
  }

  sub TextEndsHeader {
      my($this, $message, $key, $text) = @_;
      my($linenum, $oldlocation, $lastline, $totallines);

      # Try to find the old header
      $oldlocation = -1;
      $totallines = @{$message->{metadata}};
      
      for($linenum=0; $linenum<$totallines; $linenum++) {
          last if $message->{metadata}[$linenum] =~ /^H/;
      }

      for($linenum++; $linenum<$totallines; $linenum++) {
        next unless $message->{metadata}[$linenum] =~ /^H$key/i;
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
            $message->{metadata}[$lastline] =~ /^H\s/);
      $lastline--;
      $key = '\s' unless $lastline == $oldlocation;

      return 1 if $message->{metadata}[$lastline] =~
                                   /^H$key.+\Q$text\E$/i;
      return 0;
  }

  # Delete the original recipients from the message. We'll add some
  # using AddRecipients later.
  sub DeleteRecipients {
    my $this = shift;
    my($message) = @_;

    my($linenum);
    for ($linenum=0; $linenum<@{$message->{metadata}}; $linenum++) {
      next unless $message->{metadata}[$linenum] =~ /^O/;
      # Have found the right line
      splice(@{$message->{metadata}}, $linenum, 1);
      $linenum--; # Study the same line again
    }
  }

  # Add the recipient records back to the metadata
  sub AddRecipients {
    my $this = shift;
    my($message, @recips) = @_;

    # Remove all the duplicates @recips
    my %uniqueto;
    foreach (@recips) {
      $uniqueto{$_} = 1;
    }
    @recips = keys %uniqueto;

    #my $totallines = @{$message->{metadata}};

    foreach (@recips) {
      s/^/O/;
    }

    splice @{$message->{metadata}}, 0, 0, @recips;

  }

  sub KickMessage {
      my($queue2ids, $sendmail2) = @_;
      my($queue);
      my(@Files);
      my($queuedir);
      my($queuedirname);
      my($file);
      my($sendmail);
      my($queuehandle);
      my($line);
      my @recipient;
      my $recipientfound = 0;
      my $permfail = 0;
      my($sender);
      my $opts = '';
      my $messagesent = 0;
      my $InFrom = 0;
      my $response = '';
      my $orgname = MailScanner::Config::DoPercentVars('%org-name%');
      my $port = MailScanner::Config::Value('msmailrelayport');
      my $address = MailScanner::Config::Value('msmailrelayaddress');
      my $method = MailScanner::Config::Value('msmaildeliverymethod');
      my $sockettype = MailScanner::Config::Value('msmailsockettype');
      my $socketdir = MailScanner::Config::Value('msmailsocketdir');

      MailScanner::Log::DebugLog("MSMail: KickMessage:\n org = $orgname\n port = $port\n address = $address");
      foreach $queue (keys %$queue2ids) {
          next unless $queue2ids->{$queue};
          $queuedir  = new DirHandle;
          unless (chdir $queue) {
              MailScanner::Log::WarnLog("Cannot cd to dir %s to kick messages, %s",
                                    $queue, $!);
          }

          $queuedir->open('.')
              or MailScanner::Log::DieLog("Cannot open queue dir %s for kicking messages " .
                                      "message batch, %s", $queue, $!);
          while(defined($file = $queuedir->read())) {
              next if $file eq '.' || $file eq '..';
              push @Files, $file;
          }
          # Should be only one queuedir in this setup
          $queuedirname = $queue;
          $queuedir->close;

      }

      $queuehandle = new FileHandle();

      foreach $file (@Files) {

          undef(@recipient);

          my $filename = $file;
          my $file = $queuedirname . '/' . $file;
          # Open file
          my $ret = MailScanner::Lock::openlock($queuehandle,'+<' . $file, 'w');
          if ($ret != 1) {
              MailScanner::Log::WarnLog("Cannot open $file for relaying, will try again later");
              next;
          }
          $recipientfound = 0;
          # Read in pre-data header
          my $msgstart = 0;
          while(!eof($queuehandle)) {
              $line = readline $queuehandle;
              $line =~ s/\n//;
              if ($line =~ m/^O/) {
                  $line =~ s/^O//;
                  push @recipient, $line;
                  $recipientfound = 1;
                  MailScanner::Log::DebugLog("MSMail: KickMessage: recipient = $line");
                  $msgstart = tell $queuehandle;
                  next;
              } elsif ($line =~ /^S/) {
                  $line =~ s/^S//;
                  $sender = $line;
                  MailScanner::Log::DebugLog("MSMail: KickMessage: sender = $sender");
                  $msgstart = tell $queuehandle;
              } elsif ($line =~ /^E</) {
                  $line =~ s/^E<//;
                  $line =~ s/\>$//;
                  $opts = $line;
                  MailScanner::Log::DebugLog("MSMail: KickMessage: options = $opts");
                  $msgstart = tell $queuehandle;
              } else {
                  last;
              }
          }

          # Move to previous line
          seek $queuehandle, $msgstart, 0;

          $permfail = 0;
          # Determine delivery method
          if ( $method =~ m/^SMTP$/i ) {

              # Process the rest of the header
              while(!eof($queuehandle)) {
                  $line = readline $queuehandle;
                  $line =~ s/\n//;
                  if ($line eq '') {
                        MailScanner::Log::DebugLog("MSMail: KickMessage: found end of header");
                        # At end of header, bail out
                        last;
                  }
              }

              # This is the safe approach using SMTP protocol for relay
              # If relay bombs out or doesn't respond, messages are preserved
              # and tried again on next attempt
              if ($recipientfound) {
                  $messagesent = 0;
                  my $socket = new IO::Socket::INET (
                      PeerHost => $address,
                      PeerPort => $port,
                      Proto => 'tcp',
                  );

                  if(!defined($socket)) {
                      MailScanner::Log::WarnLog("Cannot connect to Socket at $address on port $port, is MTA running?");
                      MailScanner::Lock::unlockclose($queuehandle);
                      last;
                  }

                  my $server = hostfqdn();
                  if(!defined($server)) {
                      MailScanner::Log::WarnLog("Cannot determine local fqdn! Unable to kick messages.");
                      MailScanner::Lock::unlockclose($queuehandle);
                      last;
                  }
                  $response = '';
                  $socket->recv($response, 1024);
                  if ($response =~ /^220/) {
                     MailScanner::Log::DebugLog("MSMail: KickMessage: Connect success 220 received");

                      my $req = 'ehlo ' . $server . "\n";
                      $socket->send($req);

                      $socket->recv($response, 1024);
                      if ($response =~ /^250/) {
                          MailScanner::Log::DebugLog("MSMail: KickMessage: ehlo success 250 received");
                          # ehlo receive success
                          $req = 'MAIL FROM: ' . $sender . "\n";
                          $socket->send($req);
                          $socket->recv($response, 1024);
                          if ($response =~ /^250/) {
                              MailScanner::Log::DebugLog("MSMail: KickMessage: MAIL FROM success 250 received");
                              # From received success
                              my $recipientsok = 1;
                              foreach my $myrecipient (@recipient) {
                                  $req = 'RCPT TO: ' . $myrecipient;

                                  # RFC 3461
                                  if ($opts ne '') {
                                      $req = $req . ' ' . $opts;
                                  }

                                  $req = $req . "\n";

                                  $socket->send($req);
                                  $socket->recv($response, 1024);
                                  if ($response =~ /^250/ ) {
                                      MailScanner::Log::DebugLog("MSMail: KickMessage: RCPT TO success 250 received");
                                  } else {
                                      $recipientsok = 0;
                                  }
                              }

                              if ($recipientsok == 1) {
                                  # Rcpt To success
                                  $req='DATA' . "\n";
                                  $socket->send($req);
                                  $socket->recv($response, 1024);
                                  if ($response =~ /^354/ ) {
                                      MailScanner::Log::DebugLog("MSMail: KickMessage: DATA success 354 received");
                                      # Ready to send data
                                      # Position at start of message
                                      seek $queuehandle, $msgstart, 0;

                                      while(!eof($queuehandle)) {
                                          $req = readline $queuehandle;
                                          # rfc 5321, section 4.5.2
                                          # Handle dots in DATA \./ :D
                                          if ($req =~ /^\./) {
                                              $req = '.' . $req;
                                          }
                                          $socket->send($req);
                                      }
                                      $req = "\r\n.\r\n";
                                      $socket->send($req);

                                      $socket->recv($response, 1024);
                                      if ($response =~ /^250/ && !($response =~ /Error/)) {
                                          MailScanner::Log::DebugLog("MSMail: KickMessage: Message send successful");
                                          $messagesent = 1;
                                      }
                                  }
                              }
                          }
                      }
                  }
                  $socket->close();
              }
              # Was message rejected?
              if ($response =~ /^450/) {
                  $permfail = 1;
              }
          } elsif ( $method =~ m/^QMQP$/i ) {
              $messagesent = 0;
              my $socket;
              if ( $sockettype =~ m/^unix$/i ) {
                  $socket = IO::Socket::UNIX->new (Peer => $socketdir);
                  MailScanner::Log::WarnLog("Unable to open QMQP socket $socketdir")
                    if !defined($socket);
              } elsif ( $sockettype =~ m/^inet$/i ) {
                  $socket = new IO::Socket::INET (
                      PeerAddr => $address,
                      PeerPort => $port,
                  );
                  MailScanner::Log::WarnLog("Unable to open QMQP socket at $address on port $port")
                    if !defined($socket);
              } else {
                  MailScanner::Log::WarnLog("Unknown socket type, check MailScanner.conf MSMail Socket Type.");
              }
              if (defined($socket)) {
                  # Prepare to read rest of file
                  local $/ = undef;
                  # Remove backets
                  $sender =~ s/^\<//;
                  $sender =~ s/\>$//;
                  foreach (@recipient) {
                     s/^\<//;
                     s/\>$//;
                  }
                  my $payload = join '', map {sprintf "%d:%s,", length $_, $_} <$queuehandle>, $sender, @recipient;
                  MailScanner::Log::DebugLog("MSMail: payload ready");
                  eval {
                      $socket->printf ('%d:%s,', length $payload, $payload)
                  };
                  if ( $@ ) {
                      MailScanner::Log::WarnLog("Unable to write to QMQP socket!");
                  } else {
                      MailScanner::Log::DebugLog("MSMail: Payload sent");
                      my $response = $socket->getline;
                      if (my ($length, $code, $detail) = $response =~ m/^(\d+):(\S)(.+),$/) {
                          if ($code eq "K") {
                              $messagesent = 1;
                          } elsif ($code eq "D") {
                              $messagesent = 0;
                              $permfail = 1;
                          }
                      } else {
                          $messagesent = 0;
                      }
                      $socket->close();
                  }
              }
          } else {
              MailScanner::Log::WarnLog("Unable to determine delivery method! No messages delivered. Check MailScanner.conf for MSMail Delivery Method.");
          }

          # Test reject logging
          # $messagesent = 0;
          if ($messagesent == 0) {
              # Look for a rejection
              # Debug rejection process
              # $response = "450 1.2.3 This is a test reject";
              if ($permfail == 1) {
                 # Something went wrong cannot deliver message
                 # Prefix email with Reject header to flag for quarantine
                 MailScanner::Log::WarnLog("Unable to kick message $file, rejected by local relay, quarantining message");
                 seek $queuehandle, 0, 0;
                 # Open a new file in inbound queue
                 my $inqueuedir = MailScanner::Config::Value('inqueuedir');
                 my $test = @{$inqueuedir}[0] . '/' . $filename;
                 my $queuehandle2 = new FileHandle;
                 my $ret = MailScanner::Lock::openlock($queuehandle2,'>' . $test, 'w');
                 if ($ret != 1) {
                     MailScanner::Log::WarnLog("Unable to requeue message rejected by relay, will try again later");
                     MailScanner::Lock::unlockclose($queuehandle);
                 } else {
                     MailScanner::Log::DebugLog("MSMail: KickMessage: Message rejected! Requeuing to quarantine.");
                     $response =~ s/\r\n.*$//;
                     $response =~ s/\n.*$//;
                     $response =~ s/\n//;
                     while(!eof($queuehandle)) {
                         $line = readline $queuehandle;
                         last unless ($line =~ /^(?:O|S|E)</);
                         $queuehandle2->print($line);
                     }
                     $queuehandle2->print('X-'. $orgname . '-MailScanner-Relay-Reject: ' . $response . "\n");
                     $queuehandle2->print($line);
                     while(!eof($queuehandle)) {
                         $line = readline $queuehandle;
                         $queuehandle2->print($line);
                     }
                     MailScanner::Lock::unlockclose($queuehandle);
                     unlink $file;
                     $queuehandle2->flush();
                     MailScanner::Lock::unlockclose($queuehandle2);
                     $queuehandle2=undef;
                     next;
                 }
             }
 
             MailScanner::Log::WarnLog("Unable to kick message $file, will retry soon...");
             MailScanner::Lock::unlockclose($queuehandle);
         } else {
              # Delivered :D
              MailScanner::Lock::unlockclose($queuehandle);
              unlink $file;
         }
      }
  }

  # Unused in MSMail
  sub PreDataString {
      return;
  }

  # Unused in MSMail, just return
  sub PostDataString {
      return;
  }

  # Unused in MSMail, just return
  sub Record2String {
      return;
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
          next if $file eq '.' || $file eq '..' || $file =~ /^temp-/;
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
            next if $file1 eq '.' || $file1 eq '..' || $file1 eq 'core' || $file1 =~ /^temp-/;
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
                next if $file2 eq '.' || $file2 eq '..' || $file2 eq 'core' || $file2 =~ /^temp-/;
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

        # Don't do this with long queue ids
        # Apply to short queue ids
        my $id;
        if ($idtemp =~ /^[A-F0-9]+$/) {
            $id = $idtemp . '.' . PostfixKey($fullpath);
        } else {
            $id = $idtemp;
        }

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

        #if (MailScanner::Config::Value("scanmail", $newmessage) =~ /[12]/ ||
        #    MailScanner::Config::Value("virusscan", $newmessage) =~ /1/ ||
        #    MailScanner::Config::Value("dangerscan", $newmessage) =~ /1/) {
        #
        # alvarosplit fix
        if ($newmessage->{"scanmail"} =~ /[12]/ ||
			$newmessage->{"virusscan"} =~ /1/ ||
			$newmessage->{"dangerscan"} =~ /1/) {
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
