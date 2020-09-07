#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2018  MailScanner Project
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
#    Adapted from PFDiskStore.pm

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
$VERSION = substr q$Revision: 5098 $, 10;

# List of pending delete operations so we can clear up properly when killed
@DeletesPending = ();

#################################
#package MailScanner::SMDiskStore;
#
#@MailScanner::SMDiskStore::ISA = qw(MailScanner::DiskStore);
#
#use vars qw($VERSION);
#
#### The package version, both in 1.23 style *and* usable by MakeMaker:
#$VERSION = substr q$Revision: 5098 $, 10;

# Attributes are
#
# $dir                 set by new (incoming queue dir in case we use it)
#ZZ $dname             set by new (filename component only)
# $hdname              set by new (filename component only)
# $tname               set by new (filename component only)
#ZZ $dpath             set by new (full path)
# $hdpath              set by new (full path)
# $size                        set by size
# $inhdhandle          set by lock
#ZZ $indhandle         set by lock
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

  #print STDERR "Creating SMDiskStore($id)\n";
  $this->{hdname} = $mta->HDFileName($id);
  $this->{tname} = $mta->TFileName($id);
  #
  # Alvaro Marin alvaro@hostalia.com - 2016/08/25
  #
  # Long queue IDs and hash queue support
  #
  my $long_queue_id=0;
  my $hex=$this->{hdname}; 
  if ($this->{hdname} !~ /^[A-F0-9]+$/) {
   # long queue id
   $long_queue_id=1;
   # With long queue IDs, when hash queues is enabled, the directory hierarchy
   # is not generated with first characters of the ID (as with short queue IDs):
   # we have to get the 4 characters that represent the microseconds and then:
   # reverse them + decode from base 52 + convert to hexadecimal
   my $msecs=reverse substr $this->{hdname},6,4;
   my $total=0;
   my $count=0;
   my %BASE52_CHARACTERS = (0 => "0",1 => "1",2 => "2",3 => "3",4 => "4",5 => "5",6 => "6",7 => "7",8 => "8",9 => "9",
				10 => "B",11 => "C",12 => "D",13 => "F",14 => "G",15 => "H",16 => "J",17 => "K",18 => "L",
				19 => "M",20 => "N",21 => "P",22 => "Q",23 => "R",24 => "S",25 => "T",26 => "V",27 => "W",
				28 => "X",29 => "Y",30 => "Z",31 => "b",32 => "c",33 => "d",34 => "f",35 => "g",36 => "h",
				37 => "j",38 => "k",39 => "l",40 => "m",41 => "n",42 => "p",43 => "q",44 => "r",45 => "s",
				46 => "t",47 => "v",48 => "w",49 => "x",50 => "y",51 => "z");
    # To avoid using external modules...reverse the hash
    my %rBASE52_CHARACTERS = reverse %BASE52_CHARACTERS;
    for my $c (split //, $msecs) {
        my $index = $rBASE52_CHARACTERS{$c};
	      $total+=$index * (52**$count);
	      $count++;
    }
    $hex = sprintf("%05X", $total); # 5 chars...from Postfix's code!
    #print STDERR "Microseconds of ".$this->{hdname}.":$msecs -> HEX: $hex\n";
  }
  if ($MailScanner::SMDiskStore::HashDirDepth == 2) {
    if ($long_queue_id){
	    $hex =~ /^(.)(.)(.*)$/;
	    $this->{hdpath} = "$dir/$1/$2/" . $this->{hdname};
    } else {
	    $this->{hdname} =~ /^(.)(.)(.*)$/;
	    $this->{hdpath} = "$dir/$1/$2/" . $this->{hdname};
   }
  } 
  elsif ($MailScanner::SMDiskStore::HashDirDepth == 1) {
    if ($long_queue_id){
      $hex =~ /^(.)(.*)$/;
	    $this->{hdpath} = "$dir/$1/" . $this->{hdname};
    } else {
	    $this->{hdname} =~ /^(.)(.*)$/;
	    $this->{hdpath} = "$dir/$1/" . $this->{hdname};
    }
  } 
  elsif ($MailScanner::SMDiskStore::HashDirDepth == 0) {
    $this->{hdname} =~ /^(.*)$/;
    $this->{hdpath} = "$dir/" . $this->{hdname};
  }
  #print STDERR "Created new message object at " . $this->{hdpath} . "\n";

  $this->{inhdhandle} = new FileHandle;

  bless $this, $type;
  return $this;
}
 

# Print the contents of the structure
sub print {
  my $this = shift;

  print STDERR "hdpath = " . $this->{hdpath} . "\n" .
               "inhdhandle = " . $this->{inhdhandle} . "\n" .
               "size = " . $this->{size} . "\n";
}


# Open and lock the message
sub Lock {
  my $this = shift;

  #print STDERR "About to lock " . $this->{hdpath} . "\n";
  MailScanner::Lock::openlock($this->{inhdhandle}, '+<' . $this->{hdpath},
    'w', 'quiet') or return undef;
  #print STDERR "Got hdlock\n";

  return undef unless $this->{inhdhandle};
  return 1;
}


# Close and unlock the message
sub Unlock {
  my $this = shift;

  MailScanner::Lock::unlockclose($this->{inhdhandle});
}


# Delete a message (from incoming queue)
sub Delete {
  my $this = shift;

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  my $path = $this->{hdpath};
  my $deferpath = $path;
  $deferpath =~ s/deferred/defer/gi;
  @DeletesPending = ($path, $deferpath);

  unlink $path, $deferpath;

  # Clear list of pending deletes
  @DeletesPending = ();
}

# Delete and unlock a message (from the incoming queue)
# This will almost certainly be called more than once for each message
sub DeleteUnlock {
  my $this = shift;

  #print STDERR "DeleteUnlock message\n";

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  my $path = $this->{hdpath};
  my $deferpath = $path;
  $deferpath =~ s/deferred/defer/gi;
  @DeletesPending = ($path, $deferpath);

  $path =~ /^(.*)$/;
  $path = $1;
  $deferpath =~ /^(.*)$/;
  $deferpath = $1;
  unlink $path, $deferpath; # TAINT

  MailScanner::Lock::unlockclose($this->{inhdhandle});

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

# Link at least the data portion of the message
# There are not separate part for the data and headers in ZMailer
# so, we do nothing.
# TODO: LEOH
# I don't think this is good, but the call to this function is in
# Messages (I'm trying to modify only ZMailer* files)
sub LinkData {
  my $this = shift;
  my($OutQ) = @_;
  #print STDERR "Marking body as original data in LinkData\n";
  $this->{body}=[ "ORIGINAL", $OutQ ];
  return;
}

# Build a plain message file
# Uses postfix recommended methods to requeue message
sub WriteHeader {
  my $this = shift;
  my($message, $Outq) = @_;

  my($tfile, $Tf);

  $tfile = $Outq . '/' . $this->{tname};

  umask 0077; # Add this to try to stop 0666 qf files
  $Tf = new FileHandle;
  MailScanner::Lock::openlock($Tf, "+>$tfile", "w")
    or MailScanner::Log::DieLog("Cannot create + lock clean tempfile %s, %s",
                                $tfile, $!);

  # Flush the filehandle to save duplicate writes in some Perls
  $Tf->flush();
  
  # We have the complete headers in memory, let use that instead
  # This allows headers to be modified in memory and written back out
  
  # Headers
  my $line;
  foreach $line (@{$message->{metadata}}) {
       if ($line =~ /^H/) {
          $line =~ s/^H//;
          $Tf->print($line . "\n");
       } elsif ($line =~ /^O/) {
          $line =~ s/^O//;
          $line = 'O<' . $line . '>';
          $Tf->print($line . "\n");
       } elsif ($line =~ /^S/) {
          $line =~ s/^S//;
          $line = 'S<' . $line . '>';
          $Tf->print($line . "\n");
       } elsif ($line =~ /^E/) {
          $line =~ s/^E//;
          $line = 'E<' . $line . '>';
          $Tf->print($line . "\n");
       }
  }
  if ($this->{body}[0] eq "ORIGINAL") {
    $Tf->print("\n");
    my $b = Body->new( $this->{inhdhandle} );
    if ($b) {
      $b->Start();
      while(defined($line = $b->Next())) {
          # Remove CRs to prep for delivery
          $line =~ s/\r+$//g;
          $Tf->print($line . "\n");
      }
      $b->Done();
    }
  $Tf->flush();
  } elsif ($this->{body}[0] eq "MIME") {
      my ($type, $id, $entity, $outq)= @{$this->{body}};
      # This needs re-writing, as we need to massage every line

      # Create a pipe to squirt the message body through
      my $pipe = new IO::Pipe;
      my $pid;

      if (not defined $pipe or not defined ($pid = fork)) {
          MailScanner::Log::WarnLog("Pipe creation failed in WriteHeader, %s", $!);
      } elsif ($pid) { # Parent
          $Tf->flush(); # JKF 20050317
          $pipe->reader();
          # Read the pipe a line at a time and write an N record for each line.
          while(<$pipe>) {
              chomp;
              # Remove CRs to prep for delivery
              s/\r+$//g;
              $Tf->print($_ . "\n");
          }
          # We have to tell the caller what the child's pid is in order to
          # reap it. Although IO::Pipe does this for us when it is told to
          # fork and exec, it unfortunately doesn't have a neat hook for us
          # to tell it the pid when we do the fork. Bah.
          $pipe->close();
          $Tf->flush(); # JKF 20050307
          waitpid $pid, 0;
       } else { # Child
          $Tf->flush(); # JKF 20050317
          $pipe->writer();
          $entity->print_body($pipe)
             or MailScanner::Log::WarnLog("WriteMIMEBody to %s possibly failed, %s",
                                     $tfile, $!);
          $pipe->close();
          #$Tf->flush(); # JKF 20050307
          exit;
       }
   }

  MailScanner::Lock::unlockclose($Tf);
  undef $Tf; # Try to ensure Tf is completely closed, flushed, everything

  my $hdoutfile;
  my $hddirbase; 
  ($hddirbase, $hdoutfile) =
      MailScanner::Sendmail::HDOutFileName($tfile);
  rename "$tfile", "$hddirbase/$hdoutfile"
      or MailScanner::Log::DieLog("Cannot rename clean %s to %s, %s",
                                  $tfile, $hdoutfile, $!);
  MailScanner::Log::InfoLog("Requeue: %s to %s", $message->{id},$hdoutfile);
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

  my $line;
  my $lastlineread = undef;
  my $b = Body->new( $this->{inhdhandle} );
  return unless $b;
  
  # Restraint is disabled, do the whole message.
  #print STDERR "max message size is '$max'\n";
  unless ($max) {
    while(defined($lastlineread = $b->Next())) {
      # End of line characters are already there, so don't add them
      push @{$body}, $lastlineread . "\n";
      #print STDERR "Line read is ****" . $_ . "****\n";
    }
    $b->Done();
    return;
  }

  my @configwords = split(" ", $max);
  $max = $configwords[0];
  $max =~ s/_//g;
  $max =~ s/k$/000/ig;
  $max =~ s/m$/000000/ig;
  $max =~ s/g$/000000000/ig;
  #print STDERR "Words are " . join(',',@configwords) . "\n";

  # Read the body up to the limit
  my($line, $size);
  $size = 0;

  while(defined($line = $b->Next()) && $size<$max) {
    push @{$body}, $line . "\n";
    $size += length($line);
    #print STDERR "Line read2 is ****" . $line . "****\n";
  }
  $lastlineread = $line;

  #print STDERR "Initially read $size bytes\n";

  # Handle trackback -- This is the tricky one
  if ($configwords[1] =~ /tr[ua]/i) {
    #print STDERR "Trackback:\n";
    my $i;
    for ($i=(@{$body}-1); $i>=0; $i--) {
      last if $body->[$i] =~ /^\s*$/i;
      pop @{$body};
    }
    #my $bodysize = $#{@$body}-1;
    #while (${@{$body}}[$bodysize+1] !~ /^\s*@/) { 
    #while(${@{$body}}[$#{@$body}] !~ /^\s*$/) {
      #print "Line is ****" . ${@{$body}}[scalar(@{$body})-1] . "****\n";
    #  pop @{$body};
      #print STDERR ".";
    #}

    #print STDERR "\n";
    $b->Done();
    return;
  }

  # Handle continue
  if ($configwords[1] =~ /con/i) {
    #print STDERR "Continue:\n";
    my $maxsizes = 0;
    my $maxsize  = 0;

    # Work out the number they have put in the .conf line after "continue"
    $maxsizes = $configwords[2] if $configwords[2] =~ /^[0-9]/;
    $maxsizes =~ s/_//g;
    if ($maxsizes =~ s/k$//i) {
      $maxsize = $maxsizes * 1000;
    } elsif ($maxsizes =~ s/m$//i) {
      $maxsize = $maxsizes * 1000000;
    } elsif ($maxsizes =~ s/g$//i) {
      $maxsize = $maxsizes * 1000000000;
    } elsif ($maxsizes =~ s/[^0-9]*//g) {
      $maxsize = $maxsizes;
    }

    # Value provided in .conf is the number of extra bytes to read.
    $maxsize += $max;
    #print STDERR "Maxsize = $maxsize\n";

    # Now need to read extra bytes up to $maxsize bytes
    while(defined $lastlineread && $lastlineread !~ /^\s*$/) {
      #print "Continue added '$lastlineread'\n";
      $size += length($lastlineread);
      last if $size > $maxsize;
      push @{$body}, $lastlineread . "\n";
      $lastlineread = $b->Next();
      #print STDERR "Added $lastlineread";
    }

    $b->Done();
    return;
  }
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
#REVISO LEOH
# JKF This is wrong, it should copy not rename.
# JKF Have decided that the hdname will contain *just* the filename
# JKF and no directory components.
# JKF The hashing directory components will be extracted when needed.
# JKF Is now much simpler, just calls the functions that do the job already.
# $targetfile can be 'message' or undef which indicates we are storing in the
# main quarantine, not in the outgoing mail dir.
sub CopyEntireMessage {
  my $this = shift;
  my($message, $targetdir, $targetfile, $uid, $gid, $changeowner) = @_;
  
  #$targetfile =~/([\w\d]{9,15}\.[\w\d]{5})/;
  #$targetfile = $1;
  if ($targetfile =~ /([A-F\d]{8,15}\.[A-F\d]{5})/) {
  	$targetfile = $1;
  } else {
	if ($targetfile =~ /([\w\d\.]{4,32})/) {
		$targetfile = $1;
	} else {
		$targetfile = "fallback";
	}
  }

  #print STDERR "Copying to $targetdir $targetfile\n";
  if (MailScanner::Config::Value('storeentireasdfqf')) {
    #print STDERR "Copying to dir $targetdir\n";
    return ($this->CopyToDir($targetdir, $targetfile, $uid, $gid,
                             $changeowner));
  } else {
    #print STDERR "Copying to file $targetdir/$targetfile\n";
    my $target = new IO::File "$targetdir/$targetfile", "w";
    MailScanner::Log::WarnLog("writing to $targetdir/$targetfile: $!")
      if not defined $target;
    $this->WriteEntireMessage($message, $target);
    return $targetdir . '/' . $targetfile;
  }
}

#  my $hdfile = $this->{hdpath};
#
#  if ($MailScanner::SMDiskStore::HashDirDepth == 2) {
#    $hdfile =~ /(.)\/(.)\/[^\/]+$/;
#    mkdir "$targetdir/$1";
#    mkdir "$targetdir/$1/$2";
#    rename("$hdfile", "$targetdir/$1/$2/$$this{hdname}");
#  } elsif ($MailScanner::SMDiskStore::HashDirDepth == 1) {
#    $hdfile =~ /(.)\/[^\/]+$/;
#    mkdir "$targetdir/$1";
#    rename("$hdfile", "$targetdir/$1/$$this{hdname}");
#  }
#}

# Writes the whole message to a handle.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
sub ReadMessageHandle {
  my $this = shift;
  my ($message, $handle) = @_;

  # we use already opened handles
  my $hdhandle = $this->{inhdhandle};

  # Where did we start?
  my $oldpos = sysseek $hdhandle, 0, 1;
  #print STDERR "Old position = $oldpos\n";

  # rewind files to read and write with File::Copy
  sysseek($hdhandle, 0, 0) or die "$!,$^E"; # Rewind the file

  # Write the whole message in RFC822 format to the handle.
  # That means 1 CR-terminated line for every N record in the file.
  my $b = Body->new($hdhandle);
  #if ($b) {
    $b->Start(1); # 1 says we want the headers as well as the body
    my $line;
    #print STDERR "\n\n\n\n\n";
    while(defined($line = $b->Next())) {
      #print STDERR "print $line\n";
      print $handle "$line\n" or die "$!, $^E";
    }
    $b->Done();
  #} else {
  #  die "Couldn't create new body object from $hdhandle, $!, $^E";
  #}

  # rewind tmpfile to read it later
  $handle->seek(0,0) or die "$!, $^E"; # Rewind the file
  #print STDERR "\n\n\nTmp File is this:\n";
  #while(<$handle>) {
  #  print STDERR $_;
  #}
  #print STDERR "Tmp File End\n";
  #$handle->seek(0,0) or die "$!, $^E"; # Rewind the file

  # rewind source files
  sysseek($hdhandle, 0, 0); # Rewind the file
  sysseek($hdhandle, $oldpos, 0); # Rewind the file

  #print STDERR "Done ReadMessageHandle\n";
  return 1;
}



# Produce a pipe that will read the whole message.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
# REVISO LEOH
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
  my $b= Body->new( $this->{inhdhandle} );
  if ($b) {
    $b->Start(1); # 1 says we want the headers as well as the body
    my $line;
    #print STDERR "WriteEntireMessage\n";
    while(defined($line = $b->Next())) {
      $handle->print($line . "\n");
      #print STDERR "BODY:  $line\n";
    }
    $b->Done();
  }
}

# Copy a hdfile to a directory
# The Postfix version of this needs to know the destination filename too
# so it can work out whether to use the hdpath as the destination filename
# (which just has the 10 hex digits in it) or the message id, which has
# the random number added to the end of it too.
sub CopyToDir {
  my($this,$dir,$file,$uid,$gid,$changeowner) = @_;
  my($hdpath, $hdfile);
  $hdpath = $this->{hdpath};
  if ($file && $file ne 'message') {
    #$hdfile = basename($hdpath);
    $hdfile = $file;
  } else {
    # We weren't passed a sensible filename, so work one out for ourselves.
    $hdfile = basename($hdpath); #$hdfile = $this->{id}; #basename($hdpath);
    #print STDERR "hdfile = $hdfile\n";
  }
  copy($hdpath, "$dir/$hdfile");
  chown $uid, $gid, "$dir/$hdfile" if $changeowner;
  return "$dir/$hdfile";
}

package Body;

# Stefan Baltus, October 2003
#
# This package opens the body message. Multiple instances of this 
# packges can exist at the same time on the same file. If this file
# is already open and locked in the same process, the lock will be
# released when the file is re-opened and consequently closed.
#
# (from man fcntl in solaris 9):
#
#     All locks associated with a file for  a  given  process  are
#     removed  when  a  file descriptor for that file is closed by
#     that process or the process  holding  that  file  descriptor
#     terminates.  Locks  are  not  inherited  by  a child process
#     created using fork(2).
#
# These semantics don't seem to hold for various other systems, like
# BSD and Linux, so the original code works fine.
#
# This package is changed in such a way that you need an open file-
# descriptor to the file you have probably already open (and locked).

# Returns () if it fails
sub new {
  my $type = shift;
  my $self=();
  my ($handle) = @_;          # take handle as parameter
  seek $handle, 0, 0;         # reset the handle

  if (defined $handle) {
    $self={ _handle     => $handle,
           _startpos   => -1,
           _donestart  => 0 };
    bless $self, $type;
    return $self;
  } else {
    #MailScanner::Log::DieLog("Cannot open %s, %s", $hdpathname, $!);
    return undef;
  }
}

# Find the start of the real message text.
# If $entiremessage is true, then it looks for the start of the headers,
# otherwise it looks for the start of the body after all the headers.
sub Start {
  my($this, $entiremessage) = @_;

  my($offset);
  my($data);

  $$this{_donestart} = 1;
  if ($$this{_startpos} == -1) {
    seek $$this{_handle}, 0, 0;
  }

  # Locate predata header
  while($data = MailScanner::Sendmail::ReadRecord($$this{_handle})) {
    last if $data !~ /^(O<|S<|E<)/;
    $$this{_startpos}= tell $$this{_handle};
  }

  seek $$this{_handle}, $$this{_startpos}, 0;

  # IF they want the headers as well, then just get out now
  if ($entiremessage) {
    return;
  }
  while($data = MailScanner::Sendmail::ReadRecord($$this{_handle})) {
    last if $data eq "";
  }

  $$this{_startpos}= tell $$this{_handle};
  
  seek $$this{_handle}, $$this{_startpos}, 0;
}

sub Next {
  my($this) = @_;
  $this->Start() unless $$this{_donestart};
  my($data) = MailScanner::Sendmail::ReadRecord($$this{_handle});
  return $data;
}

sub Done {
  my ($this) = @_;
  undef $$this{_handle};
  $$this{_startpos}  = -1;
  $$this{_donestart} = 0;
}

1;
