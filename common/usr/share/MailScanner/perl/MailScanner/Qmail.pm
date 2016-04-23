#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   OpenProtect - Server Side E-Mail Protection	
#   Copyright (C) 2003 Opencomputing Technologies
#
#   $Id: Qmail.pm 5080 2011-02-05 19:35:17Z sysjkf $
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
#   The authors, KM Ganesh, S Karthikeyan can be contacted by email at
#      email@opencompt.com
#   or by snail mail at
#      Opencomputing Technologies
#      #1, 8th Street, Gopalapuram,
#      Chennai-86, India.


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
my $SendmailOptions = "-A -f";
my $SendmailOptionsNoBounce = "-A";
my $RunAsUser = 0;
my $UnsortedBatchesLeft;

# Attributes are
#
# $HDFileRegexp                 set by new
# $LockType                     set by new
#


# If the sendmail and/or sendmail2 config variables aren't set, then
# set them to something sensible. This will need to be different
# for Exim.
sub initialise {
  $RunAsUser = MailScanner::Config::Value('runasuser');
  $RunAsUser = $RunAsUser?getpwnam($RunAsUser):0;

  MailScanner::Config::Default('sendmail', '/var/qmail/bin/qmail-inject.openprotect');
  MailScanner::Config::Default('sendmail2',
                               MailScanner::Config::Value('sendmail'));
  $MailScanner::SMDiskStore::HashDirDepth = 1;
  $UnsortedBatchesLeft = 0; # Disable queue-clearing mode
}

# Constructor.
# Takes dir => directory queue resides in
sub new {
  my $type = shift;
  my $this = {};

  # These need to be improved
  # No change for V4
  $this->{HDFileRegexp} = '^(\d+)$';
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
# HDFileName:
# Take a queue ID and return
# filename for envelope and data queue file (input)
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
# KickMessage:
# Given id, tell MTA to make a delivery attempt.
#


  sub HDFileName {
    my($this, $id) = @_;
    return "$id";
  }

  # Give it a temp file name, changes the file name to 
  # a new one for the outgoing queue.
  sub HDOutFileName {
    my($file) = @_;
    

    #print STDERR "Qmail.pm: HDOutFileName $file\n";

    my $dir = $file;
    $dir =~ s/\/[^\/]+$//;
    $dir =~ s/pid/mess/;

    #KMG: get the inode number of the temporary file in pid/ directory just as qmail-queue algo
    #KMG: Guarantee: mess/457 will be in inode 457 - qmail INTERNALS file
    $file = sprintf("%d", (stat($file))[1]);
    #print STDERR "Qmail.pm: New Filename is $file\n";
    #print STDERR "\nQmail.pm: QmailHashDirectoryNumber=". MailScanner::Config::Value('qmailhashdirectorynumber');
    my $hash = $file%MailScanner::Config::Value('qmailhashdirectorynumber');
    my $intdhash;
    if (MailScanner::Config::Value('qmailintdhashnumber') == 1)       {
    	$intdhash = -1;
    } else {
    	$intdhash = $file%MailScanner::Config::Value('qmailintdhashnumber');
    }
    return ($dir,$hash,$file, $intdhash);
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
    my($Rintdf) = $message->{store}{intdhandle};
    my($intdline) = readline($Rintdf);
    #print STDERR $message->{id} . "\n";	
    my($temp,@headers,$line,@qfarr);
    my($ipfromheader,$read1strcvd);
    
    @qfarr = <$RQf>;
    my($FIELD_NAME) = '[^\x00-\x1f\x7f-\xff :]+:';
    shift @qfarr while scalar(@qfarr) && $qfarr[0] =~ /\A[ \t]+/o && $qfarr[1] =~ /\A$FIELD_NAME/o;
    while(scalar(@qfarr) && $qfarr[0] =~ /\A$FIELD_NAME|From /o) {
    	$line = shift @qfarr;
	$line .= shift @qfarr while(scalar(@qfarr) && $qfarr[0] =~ /\A[ \t]+/o);
	push @headers, $line;
    }
    
    my($from,$to);
    my($ip);
    my($Line);
    my($TOFound, $FROMFound, $IPFound);
    #print STDERR "Qmail.pm: In ReadQf\n";
    #$message->{store}->print();
    # Just in case we get a message with no headers at all
    
    @{$message->{headers}} = ();
    @{$message->{wheaders}}= ();
    @{$message->{metadata}} = $intdline;
    @{$message->{wheaders}} = @headers;
    
    #chomp @headers;
    @{$message->{headers}} = @headers;
    chomp @{$message->{headers}};
    
    $from = $intdline;
    if($from =~ /F(.*?)\0T/) {
    	$message->{from} = $1;
        $FROMFound = 1;
    }
    $to = $intdline;
    if($to =~ /T/) {
	$to =~ s/(u.*?F.*?\0)//;
        do {
            if($to =~ s/^T((.*?)\0)//) {
 		$TOFound = 1;
    	        push @{$message->{to}}, $2;
	    }
        } while ($to =~ /^T.*?\0/);
    } 
    
    my($reccount) = 0;
    while (scalar(@headers))
    {
    	$line = shift @headers;
	$line .= shift @headers while(scalar(@headers) && $headers[0] =~ /\A[ \t]+/o);
	if ($line =~ /\AReceived:/i) {
		if($reccount == 1) {
			$ip = $line;
			$reccount++;
		} else {
			$reccount++;
		}
	}
	if ($line =~ /\ASubject:(.*)/i) {
		$message->{subject} = $1;
    		chomp $message->{subject};
	}
        if ($line =~ /\AReceived: .+\[(\d+\.\d+\.\d+\.\d+)\]/i) {
          unless ($read1strcvd) {
            $ipfromheader = $1;
            $read1strcvd = 1;
          }
        } elsif ($line =~ /\AReceived: .+\[([\dabcdef.:]+)\]/i) {
          unless ($read1strcvd) {
            $ipfromheader = $1;
            $read1strcvd = 1;
          }
        }
    } 
			
	    
    if($ip =~ /(\d+\.\d+\.\d+\.\d+)/) {
#KMG: Again heads up to christophe @ digital network for this pattern
	$message->{clientip} = $1;
        $IPFound = 1;
    } elsif (!$IPFound && $ip =~ /([\dabcdef.:]+)/) { 
#KMG: IPV6 ppl kindly test this
	$message->{clientip} = $1;
        $IPFound = 1;
    } else {
	$message->{clientip} = '127.0.0.1';
        $IPFound = 1;
    }
    # If we were told to get the IP from the header, and it was there...
    $message->{clientip} = $ipfromheader
      if $getipfromheader && $read1strcvd && $ipfromheader ne "";

    return 1 if $TOFound;
    
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
    $message->{subject} = MIME::WordDecoder::unmime($message->{subject});

    $message->{store}->DeleteUnlock();
    
    #KMG: three cheers to christophe @ digital network for his persistence and resourcefulness :)    
    #MailScanner::Log::WarnLog("Batch: Deleted queue file with no RCPT TO: address " .
    # "message %s", $message->{id});
    #print "\nNo to found.\n";
    return 0;
  }
  
  #KMG: AddHeadersToQf isnt needed in Qmail since the intd file doesnt contain the additional headers
  #KMG: Still some testing needs to be done
  sub AddHeadersToQf {
  }
  
  # KMG: wheaders is assumed to be without \n, tread with care
  # Add a header. Needs to look for the position of the M record again
  # so it knows where to insert it.
  sub AddHeader {
    my($this, $message, $newkey, $newvalue) = @_;
    push @{$message->{wheaders}}, "$newkey $newvalue\n"; 
  }

  # Delete a header. Must be in an N line plus any continuation N lines
  # that immediately follow it.
  sub DeleteHeader {
    my($this, $message, $key) = @_;
    my($linenum);
    for($linenum=0; $linenum<@{$message->{wheaders}}; $linenum++) {
    	next unless $message->{wheaders}[$linenum] =~ /^$key/i;
	splice(@{$message->{wheaders}}, $linenum, 1);
	while($message->{wheaders}[$linenum] =~ /^\s/) {
		splice(@{$message->{wheaders}}, $linenum, 1);
	}
	$linenum--;
    }
  }

  # Delete all duplicates of a header.
  sub UniqHeader {
    my($this, $message, $key) = @_;
    my($linenum, $foundat);
    $foundat = -1;
    for($linenum=0; $linenum<@{$message->{wheaders}}; $linenum++) {
    	next unless $message->{wheaders}[$linenum] =~ /^$key/i;
        ($foundat = $linenum), next if $foundat == -1;
	splice(@{$message->{wheaders}}, $linenum, 1);
	while($message->{wheaders}[$linenum] =~ /^\s/) {
		splice(@{$message->{wheaders}}, $linenum, 1);
	}
	$linenum--;
    }
  }

  sub ReplaceHeader {
    my($this, $message, $key, $newvalue) = @_;

    $this->DeleteHeader($message, $key);
    $this->AddHeader($message, $key, $newvalue);
  }

  # Append to the end of a header if it exists.
  sub AppendHeader {
    my($this, $message, $key, $newvalue, $sep) = @_;
    my($linenum, $oldlocation, $totallines); 
    
    $sep =~ s/\,/ /;
    $oldlocation = -1;
    $totallines = @{$message->{wheaders}};

    for($linenum=0; $linenum<$totallines; $linenum++) {
          next unless $message->{wheaders}[$linenum] =~ /^$key/i;
          $oldlocation = $linenum;
	  last;
    }

    if ($oldlocation<0) {
          $this->AddHeader($message, $key, $newvalue);
	  return;
    }
		    
    do {
         $oldlocation++;
    } while($linenum<$totallines &&
		$message->{wheaders}[$oldlocation] =~ /^\s/);
    $oldlocation--;

    # KMG: the ugly hack of \n fiddling :(
    if($newvalue =~ /^\s*$/) {
        chomp $message->{wheaders}[$oldlocation];
	$sep = ',' . $sep;
    }
    
    $message->{wheaders}[$oldlocation] .= "$sep$newvalue\n";
    
  }

  # Insert text at the start of a header if it exists.
  sub PrependHeader {
    my($this, $message, $key, $newvalue, $sep) = @_;
  
    my($linenum, $oldlocation);

    $sep =~ s/\,/ /;
    $oldlocation = -1;
    for($linenum=0; $linenum<@{$message->{wheaders}}; $linenum++) {
            next unless $message->{wheaders}[$linenum] =~ /^$key/i;
            $oldlocation = $linenum;
            last;
    }
    
    if ($oldlocation<0) {
            $this->AddHeader($message, $key, $newvalue);
            return;
    }
		      
    $message->{wheaders}[$oldlocation] =~
      s/^$key\s+/$key $newvalue$sep/i;
  }

  sub TextStartsHeader {
    my($this, $message, $key, $text) = @_;
 
    my($linenum, $oldlocation);

    $oldlocation = -1;
  
    for($linenum=0; $linenum<@{$message->{wheaders}}; $linenum++) {
            next unless $message->{wheaders}[$linenum] =~ /^$key/i;
            $oldlocation = $linenum;
            last;
    }
    if ($oldlocation<0) {
            return 0;
    }

    return 1 if $message->{wheaders}[$oldlocation] =~
                                   /^$key\s+\Q$text\E/i;

    return 0;
  }

  sub TextEndsHeader {
    my($this, $message, $key, $text) = @_;
  
    my($linenum, $oldlocation, $lastline, $totallines);
     
    $oldlocation = -1;
    $totallines = @{$message->{wheaders}};
  
    for($linenum=0; $linenum<$totallines; $linenum++) {
            next unless $message->{wheaders}[$linenum] =~ /^$key/i;
            $oldlocation = $linenum;
            last;
    }
    if ($oldlocation<0) {
            return 0;
    }

    $lastline = $oldlocation;
    do {
        $lastline++;
    } while($lastline<$totallines &&
      $message->{wheaders}[$lastline] =~ /^\s/);
    $lastline--;
    $key = '\s' unless $lastline == $oldlocation;				

    return 1 if $message->{wheaders}[$lastline] =~
                                        /^$key.+\Q$text\E$/i;
    return 0;
  }

  sub AddRecipients {
    my $this = shift;
    my ($message, @recips) = @_;
    
    my $tempintd = @{$message->{metadata}}[0];
    my $temprecip;
    foreach $temprecip (@recips) {
       $tempintd = $tempintd . "T" . $temprecip . "\0";
    }
    @{$message->{metadata}}[0] = $tempintd;
		 		
  }

  sub DeleteRecipients {
    my $this = shift;
    my($message) = @_;
   
    my $tempintd = @{$message->{metadata}}[0];
    $tempintd =~ s/T.*$//g;
    
    @{$message->{metadata}}[0] = $tempintd;
  }


  # Send a byte down the trigger FIFO of the Qmail Lock Director, so that it reads
  # its incoming queue.
  sub KickMessage {
     my($empty) = 1;

    # Using the outgoing queue directory with 'mess' replaced with 'lock',
    my $lock = MailScanner::Config::Value('outqueuedir');
    $lock =~ s/mess/lock/;
    my $fh = new FileHandle;
    $fh->open(">$lock/trigger") or
      MailScanner::Log::WarnLog("KickMessage failed as couldn't write to " .
                                "%s, %s", "$lock/trigger", $!);
    # not doing a SETFL, as it sets qmail-send to 100% cpu busy
    # not exactly by the bookas in triggerpull.c 
    # fcntl($fh, F_SETFL,fcntl($fh,F_GETFL, 0) | O_NONBLOCK) or
    #  MailScanner::Log::WarnLog("KickMessage FCNTL Fail as couldn't get it" .
    #                            "%s", $!);
    syswrite $fh,$empty, 1;  
    # KMG: This works most of the time 
    $fh->close;

    return 0;
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

    # qmail-inject.openprotect
    # Set Environment Variables
    # QMAILINJECT = sf
    # s - delete ReturnPath:
    # f - delete From:
    # QMAILUSER = default sender
    
    if($sender eq '<>')
    {
    
    	use Env qw($QMAILINJECT $QMAILUSER);
    	$QMAILINJECT = 'sf';
    	$QMAILUSER = '';
    
    	$fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
              " $SendmailOptionsNoBounce")
              or MailScanner::Log::WarnLog("Could not send email message, %s", $!),
	
    }
    else
    {
   	 use Env qw($QMAILINJECT $QMAILUSER);
   	 $QMAILINJECT = 'sf';
   	 $QMAILUSER = $sender;
	 
   	 $fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
              " $SendmailOptions '" . $sender . "'")
              or MailScanner::Log::WarnLog("Could not send email message, %s", $!),
    }
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


    # qmail-inject.openprotect
    # Set Environment Variables
    # QMAILINJECT = sf
    # s - delete ReturnPath:
    # f - delete From:
    # QMAILUSER = default sender
    
    if($sender eq '<>')
    {
    	    use Env qw($QMAILINJECT $QMAILUSER);
    	    $QMAILINJECT = 'sf';
    	    $QMAILUSER = '';
	    
	    $fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
              " $SendmailOptionsNoBounce")
              or MailScanner::Log::WarnLog("Could not send email message, %s", $!),
	
    }
    else
    {
    	    use Env qw($QMAILINJECT $QMAILUSER);
    	    $QMAILINJECT = 'sf';
    	    $QMAILUSER = $sender;
	    
	    $fh->open('|' . MailScanner::Config::Value('sendmail', $message) .
	            " $SendmailOptions '" . $sender . "'")
      			or MailScanner::Log::WarnLog("Could not send email entity, %s", $!),
    }
    $entity->print($fh);
    $fh->close();

    1;
  }



  # Create a MessageBatch object by reading the queue and filling in
  # the passed-in batch object.
  sub CreateBatch {
    my $this = shift;
    my($batch) = @_;

    my($queuedirname, $queuedir, $queue1dir, $queue2dir, $MsgsInQueue);
    my($DirtyMsgs, $DirtyBytes, $CleanMsgs, $CleanBytes);
    my($HitLimit1, $HitLimit2, $HitLimit3, $HitLimit4);
    my($MaxCleanB, $MaxCleanM, $MaxDirtyB, $MaxDirtyM);
    my(%ModDate, $mta, $file, $file1, $file2, $tmpdate, $hash);
    my(@SortedFiles, $id, $newmessage, @queuedirnames);
    my($batchempty, $h1, $h2, $delay, $CriticalQueueSize);
    my($nlinks, $invalidfiles);
    my($getipfromheader);

    $queuedir  = new DirHandle;
    $queue1dir = new DirHandle;
    $queue2dir = new DirHandle;
    $MsgsInQueue = 0;
    $delay     = MailScanner::Config::Value('queuescaninterval');
    #print STDERR "Qmail.pm: Inq = " . %$global::MS->{inq} . "\n";
    #print STDERR "Qmail.pm: dir = " . @{$global::MS->{inq}{dir}} . "\n";
    @queuedirnames = @{$global::MS->{inq}{dir}};

    ($MaxCleanB, $MaxCleanM, $MaxDirtyB, $MaxDirtyM)
                      = MailScanner::MessageBatch::BatchLimits();

    # If there are too many messages in the queue, start processing in
    # directory storage order instead of date order.
    $CriticalQueueSize = MailScanner::Config::Value('criticalqueuesize');
    $getipfromheader = MailScanner::Config::Value('getipfromheader');

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
    
      # http://www.qmail.org/man/misc/INTERNALS.txt
      # From qmail Internals:
      # States a queue file goes through:
      # + means a file exists;
      # - means it does not exist;
      # ? means it may or may not exist.
      # S1. -mess -intd -todo -info -local -remote -bounce
      # S2. +mess -intd -todo -info -local -remote -bounce
      # S3. +mess +intd -todo -info -local -remote -bounce
      # S4. +mess ?intd +todo ?info ?local ?remote -bounce (queued)
      # So MailScanner should process only when it finds a file in todo
      
      # Loop through each of the inq directories
      foreach $queuedirname (@queuedirnames) {
        #print STDERR "Qmail.pm: Scanning dir $queuedirname\n";
	my($todoqueuedirname) = $queuedirname;
	
	$todoqueuedirname =~ s/mess/todo/;
	
	#KMG: Assuming todo directory in incoming queue directories are flat with no conf-splits

	unless (chdir $todoqueuedirname) {
          MailScanner::Log::WarnLog("Cannot cd to dir %s to read messages, %s",
                                    $todoqueuedirname, $!);
          next;
        }
        $mta = $global::MS->{mta};

        $queuedir->open('.')
          or MailScanner::Log::DieLog("Cannot open queue dir %s for reading " .
                                      "message batch, %s", $todoqueuedirname, $!);

        # Got to read incoming todo directory and calculate mess directory hash
	
        while(defined($file = $queuedir->read())) {

	      next unless $file =~ /$mta->{HDFileRegexp}/;
	      $hash = $1%MailScanner::Config::Value('qmailhashdirectorynumber');
	      push @SortedFiles, "$queuedirname/$hash/$file";
              if ($UnsortedBatchesLeft<=0) {
                 $tmpdate = (stat($file))[9]; # 9 = mtime
                 next if -z _;
                 next unless -f _;
                 next unless -R _;
                 $ModDate{"$queuedirname/$hash/$file"} = $tmpdate;
              }
              $MsgsInQueue++;
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

      # Keep going until end of dir or have reached every imposed limit. This
      # now processes the files oldest first to make for fairer queue cleanups.
      #print STDERR "Qmail.pm: Files are " . join(', ', @SortedFiles) . "\n";
      while(defined($file = shift @SortedFiles) &&
            $HitLimit1+$HitLimit2+$HitLimit3+$HitLimit4<1) {

        # In accelerated queue-clearing mode, so we don't know anything yet
        if ($UnsortedBatchesLeft>0) {
	  stat $file;
          next if -z _; # Skip 0-length queue files
          next unless -f _;
          next unless -R _;
        }

        # must separate next two lines or $1 gets re-tainted by being part of
        # same expression as $file [mumble mumble grrr mumble mumble]
        #print STDERR "Qmail.pm: Reading file $file from list\n";
        # Split pathname into dir and file again
        ($queuedirname, $h1, $file) = ($1,$2,$3)
             if $file =~ /^(.*)\/(\d+)\/(\d+)$/;
	$queuedirname = $queuedirname . '/' . $h1;
        next unless $file =~ /$mta->{HDFileRegexp}/;
        $id = $1;

         
        #print STDERR "Qmail.pm: Adding $id to batch\n";
        # Lock and read the qf file. Skip this message if the lock fails.
        $newmessage = MailScanner::Message->new($id, $queuedirname,
                                                $getipfromheader);
        if ($newmessage eq 'INVALID') {
          $invalidfiles .= "$id ";
          next;
        }
        next unless $newmessage;
        $newmessage->WriteHeaderFile(); # Write the file of headers
        $batch->{messages}{"$id"} = $newmessage;
        #print STDERR "Qmail.pm: Added $id to batch\n";
        $batchempty = 0;

        if (MailScanner::Config::Value("virusscan", $newmessage) ||
            MailScanner::Config::Value("dangerscan", $newmessage)) {
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

    #print STDERR "Qmail.pm: Dirty stats are $DirtyMsgs msgs, $DirtyBytes bytes\n";
  }


# Return the array of headers from this message, optionally with a
# separator on the end of each one.
# This is in Sendmail.pm as the storage of the headers array is specific
# to the MTA being used.
sub OriginalMsgHeaders {
  my $this = shift;
  my($message, $separator) = @_;

  # No separator so just return the array
  return @{$message->{headers}};

}

# KMG: incoming todo is assumed to be flat
# KMG: but this sub is called on both incoming and outgoing :(

sub CheckQueueIsFlat{
    my($dir) = @_;
    
    if($dir eq MailScanner::Config::Value('outqueuedir')) {
    	return 1;
    }
    $dir =~ s/mess/todo/;
    my($dirhandle, $f);

    $dirhandle = new DirHandle;
    $dirhandle->open($dir)
          or MailScanner::Log::DieLog("Cannot read queue directory $dir");
    
    while($f = $dirhandle->read()) {
    	next if $f =~ /^\.\.?$/;
	MailScanner::Log::DieLog("Queue directory %s cannot contain sub-" .
                          "directories, currently contains dir %s",
                          $dir, $f)
	      if -d "$dir/$f";
    }
    $dirhandle->close();
    return 1;
}
1;
