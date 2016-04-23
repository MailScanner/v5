#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   OpenProtect - Server Side E-Mail Protection
#   Copyright (C) 2003 Opencomputing Technologies
#
#   $Id: QMDiskStore.pm 3743 2006-10-09 15:42:09Z sysjkf $
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

package MailScanner::SMDiskStore;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use File::Basename;
use File::Copy;
use IO::File;
use IO::Pipe;

use MailScanner::Lock;
use MailScanner::Config;

use vars qw($VERSION @DeletesPending);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 3743 $, 10;

# List of pending delete operations so we can clear up properly when killed
@DeletesPending = ();

# Attributes are
# $archivid	       init by new, set by CopyToDir
# $dir                 set by new (incoming queue dir in case we use it)
# $hdname              set by new (filename component only)
# $tname               set by new (filename component only)
# $intdpath            set by new (full path)
# $hdpath              set by new (full path)
# $size                set by size
# $inhdhandle          set by lock
# $intdhandle	       set by lock   	
#
#

# Constructor.
# Takes message id and directory name.
sub new {
  my $type = shift;
  my($id, $dir) = @_;
  my $this = {};
  my $mta  = $global::MS->{mta};
  $this->{dir} = $dir;

  #print STDERR "QMDiskStore.pm: Creating SMDiskStore($id)\n";
  $this->{archivid} = 0;
  $this->{hdname} = $mta->HDFileName($id);
  $this->{tname} = $mta->TFileName($id);
  $this->{hdpath} = "$dir/" . $this->{hdname};
  $dir =~ m/^(.*)\/mess\/[0-9]+$/;
  $this->{intdpath} = $1 . '/intd/' . $this->{hdname};
  #print STDERR "QMDiskStore.pm: Created new message object at " . $this->{hdpath} . "\n";

  $this->{inhdhandle} = new FileHandle;
  $this->{intdhandle} = new FileHandle;

  bless $this, $type;
  return $this;
}
 

# Print the contents of the structure
sub print {
  my $this = shift;

  print STDERR "QMDiskStore.pm: hdpath = " . $this->{hdpath} . "\n" .
               "inhdhandle = " . $this->{inhdhandle} . "\n" .
               "size = " . $this->{size} . "\n";
}


# Open and lock the message
sub Lock {
  my $this = shift;

  #print STDERR "QMDiskStore.pm: About to lock " . $this->{hdpath} . "\n";
  MailScanner::Lock::openlock($this->{inhdhandle}, '+< ' . $this->{hdpath},
    'w', 'quiet') or return undef;
  #print STDERR "QMDiskStore.pm: Got hdlock\n";

  #print STDERR "QMDiskStore.pm: About to lock " . $this->{intdpath} . "\n";
  if (-f $this->{intdpath}){		#if the intd file is still being written by qmail-queue
  	MailScanner::Lock::openlock($this->{intdhandle}, '+< ' . $this->{intdpath},
    	'w', 'quiet') or return undef;
  }else {
  	#print STDERR "\nQMDiskStore.pm: Message is not yet ready.";
	return undef;
  }
  #print STDERR "QMDiskStore.pm: Got intdlock\n";
  return undef unless $this->{inhdhandle};
  return undef unless $this->{intdhandle};
  return 1;
}


# Close and unlock the message
sub Unlock {
  my $this = shift;

  MailScanner::Lock::unlockclose($this->{inhdhandle});
  MailScanner::Lock::unlockclose($this->{intdhandle});
}


# Delete a message (from incoming queue)
sub Delete {
  my $this = shift;

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  my $path = $this->{hdpath};
  my $intdpath = $this->{intdpath};;
  my $todopath = $intdpath;
  $todopath =~ s/intd/todo/gi;
  @DeletesPending = ($path, $intdpath, $todopath);

  unlink $todopath, $intdpath, $path;

  # Clear list of pending deletes
  @DeletesPending = ();
}

# Delete and unlock a message (from the incoming queue)
# This will almost certainly be called more than once for each message
sub DeleteUnlock {
  my $this = shift;

  #print STDERR "QMDiskStore.pm: DeleteUnlock message\n";

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  my $path = $this->{hdpath};
  my $intdpath = $this->{intdpath};;
  my $todopath = $intdpath;
  $todopath =~ s/intd/todo/gi;
  @DeletesPending = ($path, $intdpath, $todopath);

  unlink $todopath, $intdpath, $path;
  MailScanner::Lock::unlockclose($this->{inhdhandle});
  MailScanner::Lock::unlockclose($this->{intdhandle});
  # Clear list of pending deletes
  @DeletesPending = ();

}

# Carry out any pending delete operations so we leave the incoming queue
# nice and tidy. We don't do anything except the delete operations as
# the outgoing queue runner will pick up the messages eventually anyway.
sub DoPendingDeletes {
  unlink @DeletesPending if @DeletesPending;
  @DeletesPending = ();
}

sub LinkData {
  my $this = shift;
  my($OutQ) = @_;
#  print STDERR "QMDiskStore.pm: Marking body as original data in LinkData\n";
  $this->{body}=[ "ORIGINAL", $OutQ ];
  return;
}


# Write the temporary header data file, before it is made "live" by
# renaming it.
# Passed the parent message object we are working on, and the outqueue dir.
# There is only one message, so this function have to write "both"
sub WriteHeader {
  my $this = shift;
  my($message, $Outq) = @_;

  my($tfile, $Tf, $intdfile,$Intdf,$todofile, $intdline);
  
  #print STDERR "QMDiskStore.pm: Writing header for message " . $message->{id} . "\n";
  $intdfile = $Outq;
  $intdfile =~ s/mess//;

  $tfile = $intdfile . 'pid/' . $this->{tname};
  
  $todofile = $intdfile . 'todo/';
  
  #$file  .= '/' . $this->{tname};
  #print STDERR "QMDiskStore.pm: Writing header to temp file $tfile\n";

  umask 0077; # Add this to try to stop 0666 qf files
  $Tf = new FileHandle;
  $Intdf = new FileHandle;
  MailScanner::Lock::openlock($Tf, "+>$tfile", "w")
    or MailScanner::Log::DieLog("Cannot create + lock clean tempfile %s, %s",
                                $tfile, $!);
				
  print $Tf @{$message->{wheaders}};
  
  print $Tf "\n";
  
  if($this->{body}[0] eq "ORIGINAL") {
    my $handle = new FileHandle($this->{hdpath});

    my(@qfarr) = <$handle>;
    my($FIELD_NAME) = '[^\x00-\x1f\x7f-\xff :]+:';
    shift @qfarr while scalar(@qfarr) && $qfarr[0] =~ /\A[ \t]+/o && $qfarr[1] =~ /\A$FIELD_NAME/o;
    while(scalar(@qfarr) && $qfarr[0] =~ /\A$FIELD_NAME|From /o) {
	shift @qfarr;
	shift @qfarr while(scalar(@qfarr) && $qfarr[0] =~ /\A[ \t]+/o);
    }
    
    print $Tf @qfarr;
    
    close $handle;
    
  } elsif ($this->{body}[0] eq "MIME") {
    my ($type, $id, $entity, $outq) = @{$this->{body}};
    $entity->print_body($Tf);
  }
  MailScanner::Lock::unlockclose($Tf);
  undef $Tf; # Try to ensure Tf is completely closed, flushed, everything

  my($hddirbase, $hddir1, $hddir2, $hdoutfile, $now, $intdhash);
  # Postfix wants the message file to have perms 0700 for some reason
  chmod 0644, "$tfile";
  $now = time;
    ($hddirbase, $hddir1, $hdoutfile, $intdhash) = 
      MailScanner::Sendmail::HDOutFileName($tfile);
    #print STDERR "QMDiskStore.pm: tfile = $tfile and hdoutfile = $hdoutfile\n";
    # Update all the datestamps so that Postfix qmgr will see them
    utime $now, $now, "$hddirbase/$hddir1", "$tfile";
    rename "$tfile", "$hddirbase/$hddir1/$hdoutfile"
      or MailScanner::Log::DieLog("Cannot rename clean %s to %s, %s",
                                  $tfile, $hdoutfile, $!);
    #print STDERR "\nRenamed file $tfile to $hddirbase/$hddir1/$hdoutfile";
  if($intdhash == -1) {
  	$intdfile = $intdfile . 'intd/' . $hdoutfile;
  	$todofile = $todofile . $hdoutfile; 
  } else {
  	$intdfile = $intdfile . 'intd/' . $intdhash . '/' .  $hdoutfile;
  	$todofile = $todofile . $intdhash . '/' . $hdoutfile; 
  }
  MailScanner::Lock::openlock($Intdf, "+>$intdfile", "w")
    or MailScanner::Log::DieLog("Cannot create + lock clean intdfile %s, %s",$intdfile, $!);
  $intdline = $message->{metadata}[0];
  $Intdf->print($intdline)
    or MailScanner::Log::DieLog("Failed to write headers for" .
                                "message %s:%s, %s", $message->{id},$hdoutfile, $!);
  
  MailScanner::Lock::unlockclose($Intdf);
  undef $Intdf; # Try to ensure If is completely closed, flushed, everything
  chmod 0644, "$intdfile";
  link $intdfile,$todofile
    or MailScanner::Log::DieLog("Failed to create hard todo link".
                                "message %s:%s, %s", $message->{id},$hdoutfile, $!);
  $this->{outid} = $hdoutfile;
}


# Return the size of the message (Header+body)
#REVISO LEOH
sub size {
  my $this = shift;

  my($size, $hdpath);

  # Return previous calculated value if it exists
  $size = $this->{size};
  return $size if $size;

  # Calculate it
  $hdpath = $this->{hdpath};
  $size  = -s $hdpath if -e $hdpath;

  # Store and return
  $this->{size} = $size;
  return $size;
}

# Return the size of the body (body)
sub dsize {
  my $this = shift;

  my($size, $hdpath);

  # Return previous calculated value if it exists
  $size = $this->{size};
  return $size if $size;

  # Calculate it
  $hdpath = $this->{hdpath};
  $size  = -s $hdpath if -e $hdpath;

  # Store and return
  $this->{size} = $size;
  return $size;
}


# Read the message body into an array.
# Passed a ref to the array.
# Read up to at least "$max" bytes, if the 2nd parameter is non-zero.
sub ReadBody {
  my $this = shift;
  my($body, $max) = @_;
  my($size) = 0;
  my($inhandle) = new FileHandle $this->{hdpath};
  
  my(@qfarr) = <$inhandle>;
  my($FIELD_NAME) = '[^\x00-\x1f\x7f-\xff :]+:';
  shift @qfarr while scalar(@qfarr) && $qfarr[0] =~ /\A[ \t]+/o && $qfarr[1] =~ /\A$FIELD_NAME/o;
  while(scalar(@qfarr) && $qfarr[0] =~ /\A$FIELD_NAME|From /o) {
	shift @qfarr;
	shift @qfarr while(scalar(@qfarr) && $qfarr[0] =~ /\A[ \t]+/o);
  }
  
  my @configwords = split(" ", $max);
  $max = $configwords[0];
  $max =~ s/_//g;
  $max =~ s/k$/000/ig;
  $max =~ s/m$/000000/ig;
  $max =~ s/g$/000000000/ig;
  #print STDERR "Words are " . join(',',@configwords) . "\n";

  my $line;
  while(($line = shift @qfarr) && $size<$max) {
        push @{$body}, $line;
        $size += length($line)+1;
  } 
  # Continue copying until we hit a blank line, gives SA a complete
  # encoded attachment
  #while(defined $line) {
  #  $line = shift @qfarr;
  #  last if $line =~ /^\s+$/;
  #  push @{$body}, $line if defined $line;
  #}
  close $inhandle;
}


# Write the message body to a file in the outgoing queue.
# Passed the message id, the root entity of the MIME structure
# and the outgoing queue directory.
sub WriteMIMEBody {
  my $this = shift;
  my($id, $entity, $outq) = @_;
  $this->{body}=[ "MIME", $id, $entity, $outq ];
  return;
}


# Copy an entire copy of the message into a named file.
# The target directory name will already exist.
# May be more efficient to do this directly in perl
# rather than by invoking a shell to run cat.
# But it doesn't happen very often anyway.
sub CopyEntireMessage {
  my $this = shift;
  my($message, $targetdir, $targetfile) = @_;

  #print STDERR "QMDiskStore.pm: Copying to $targetdir $targetfile\n";
  #if (MailScanner::Config::Value('storeentireasdfqf')) {
    #print STDERR "QMDiskStore.pm: Copying to dir $targetdir\n";
  #  $this->CopyToDir($targetdir);
  #} else {
    #print STDERR "QMDiskStore.pm: Copying to file $targetdir/$targetfile\n";
    #my $target = new IO::File "$targetdir/$targetfile", "w";
    #MailScanner::Log::WarnLog("writing to $targetdir/$targetfile: $!")
    #  if not defined $target;
    #$this->WriteEntireMessage($message, $target);
    #$this->CopyToDir($targetdir);
  #}
  return $this->CopyToDir($targetdir);
}

# Produce a pipe that will read the whole message.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
sub ReadMessagePipe {
  my $this = shift;
  my $message = shift;

  my $pipe = new IO::Pipe;
  my $pid;

  if (not defined $pipe or not defined ($pid = fork)) {
    MailScanner::Log::WarnLog("Cannot build message from $this->{hdpath}" .
                              ", %s", $!);
  } elsif ($pid) { # Parent
    $pipe->reader();
    # We have to tell the caller what the child's pid is in order to
    # reap it. Although IO::Pipe does this for us when it is told to
    # fork and exec, it unfortunately doesn't have a neat hook for us
    # to tell it the pid when we do the fork. Bah.
    return ($pipe,$pid);
  } else { # Child
    $pipe->writer();
    $this->WriteEntireMessage($message, $pipe);
    $pipe->close();
    exit;
  }
}

# Write a message to a filehandle
sub WriteEntireMessage {
  my($this, $message, $handle) = @_;

  # Write the whole message in RFC822 format to the filehandle.
  # That means 1 CR-terminated line for every N record in the file.
  my $inhandle = new FileHandle $this->{hdpath};
  my $line;
  #print STDERR "QMDiskStore.pm: WriteEntireMessage\n";
  while($line = <$inhandle>) {
      $handle->print($line);
      #print STDERR "QMDiskStore.pm: BODY:  $line\n";
  }
}

# Copy a hdfile to a directory
sub CopyToDir {
  my($this,$dir,$file) = @_;
  my $hdpath = $this->{hdpath};
  if($this->{archivid} != 0)
  {
  	my $arhdfilename = $this->{archivid};
	copy($hdpath, "$dir/$arhdfilename");
#  	print STDERR "queue.in id" . $hdpath  . "copy archiv id:" . $arhdfilename . "\n";
        return "$dir/$arhdfilename";
  } else {
  	my $tmpfile = $this->{tname};
  	copy($hdpath, "$dir/$tmpfile");
  	my $tmpfilepath = $dir . '/' . $tmpfile;
  	my $inodefile = (stat($tmpfilepath))[1];
  	$this->{archivid} = $inodefile;
  	rename "$dir/$tmpfile", "$dir/$inodefile"
  	    or MailScanner::Log::DieLog("Cannot rename archive clean %s to %s, %s",
                                  $tmpfile, $inodefile, $!);
#  	print STDERR "queue.in id" . $hdpath . "orig archiv id:" . $inodefile . "\n";
        return "$dir/$inodefile";
  }
}


1;
