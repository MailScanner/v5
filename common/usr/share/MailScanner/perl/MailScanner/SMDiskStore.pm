#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: SMDiskStore.pm 4694 2009-03-11 12:15:22Z sysjkf $
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
$VERSION = substr q$Revision: 4694 $, 10;

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
#$VERSION = substr q$Revision: 4694 $, 10;

# Attributes are
#
# $dir			set by new (incoming queue dir in case we use it)
# $dname		set by new (filename component only)
# $hname		set by new (filename component only)
# $tname		set by new (filename component only)
# $dpath		set by new (full path)
# $hpath		set by new (full path)
# $size			set by size
# $inhhandle		set by lock
# $indhandle		set by lock
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
  # The Sendmail version of these 3 functions take an extra parameter,
  # the directory in which the message resides, to allow for nesting.
  $this->{dname} = $mta->DFileName($id, $dir);
  $this->{hname} = $mta->HFileName($id, $dir);
  $this->{tname} = $mta->TFileName($id, $dir);

  $this->{dpath} = $dir . '/' . $this->{dname};
  $this->{hpath} = $dir . '/' . $this->{hname};

  $this->{inhhandle} = new FileHandle;
  $this->{indhandle} = new FileHandle;

  bless $this, $type;
  return $this;
}
 

# Print the contents of the structure
sub print {
  my $this = shift;

  print STDERR "dpath = " . $this->{dpath} . "\n" .
               "hpath = " . $this->{hpath} . "\n" .
               "inhhandle = " . $this->{inhhandle} . "\n" .
               "indhandle = " . $this->{indhandle} . "\n" .
               "size = " . $this->{size} . "\n";
}


# Open and lock the message
sub Lock {
  my $this = shift;

  #print STDERR "About to lock " . $this->{hpath} . " and " .
  #             $this->{dpath} . "\n";
  MailScanner::Lock::openlock($this->{inhhandle}, '+<' . $this->{hpath}, 'w', 'quiet')
    or return undef;
  #print STDERR "Got hlock\n";

  # If locking the dfile fails, then must close and unlock the qffile too
  # 14/12/2004 Try putting this back in for now.
  unless (MailScanner::Lock::openlock($this->{indhandle},
                     '+<' . $this->{dpath}, 'w', 'quiet')) {
        #JKF 14/12/2004 open($this->{indhandle}, '+<' . $this->{dpath})) {
    MailScanner::Lock::unlockclose($this->{inhhandle});
    return undef;
  }
  #print STDERR "Got dlock\n";
  return undef unless $this->{inhhandle} && $this->{indhandle};
  return 1;
}


# Close and unlock the message
sub Unlock {
  my $this = shift;

  # Now we lock the df file as well, we must unlock it too.
  MailScanner::Lock::unlockclose($this->{indhandle});
  #close($this->{indhandle});
  MailScanner::Lock::unlockclose($this->{inhhandle});
}


# Delete a message (from incoming queue)
sub Delete {
  my $this = shift;

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  @DeletesPending = ($this->{hpath}, $this->{dpath});

  unlink($this->{hpath});
  #  or MailScanner::Log::WarnLog("Unlinking %s failed",
  #                               $this->{hpath});
  unlink($this->{dpath});
  #  or MailScanner::Log::WarnLog("Unlinking %s failed",
  #                               $this->{dpath});

  # Clear list of pending deletes
  @DeletesPending = ();
}

# Delete and unlock a message (from the incoming queue)
# This will almost certainly be called more than once for each message
sub DeleteUnlock {
  my $this = shift;

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  @DeletesPending = ($this->{hpath}, $this->{dpath});

  unlink($this->{hpath})
    or MailScanner::Log::WarnLog("Unlinking %s failed: %s",
                                 $this->{hpath}, $!);
  MailScanner::Lock::unlockclose($this->{inhhandle});
  unlink($this->{dpath})
    or MailScanner::Log::WarnLog("Unlinking %s failed: %s",
                                 $this->{dpath}, $!);
  MailScanner::Lock::unlockclose($this->{indhandle});

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
sub LinkData {
  my $this = shift;
  my($OutQ) = @_;

  my($InDPath, $OutDPath);

  $InDPath = $this->{dpath};
  # If the incoming queue was nested, the dname will have any of qf,df,xf,tf
  # pre-pended to it, so we have to get rid of this before we produce the
  # outgoing queue directory name.
  $OutDPath = $this->{dname};
  $OutDPath =~ s/^[qdxt]f\///;
  $OutDPath = $OutQ . '/' . $OutDPath;
  #print STDERR "OutQ = $OutQ and OutDPath = $OutDPath\n";

  # If the link fails for some reason (usually caused by sendmail calling
  # 2 messages the same thing in a very short time), then just skip this
  # message and move on to the next one. This one will get delivered when
  # the previous one with the same name has been delivered.
  unless (link $InDPath, $OutDPath) {
    # The link failed, so get the inode numbers of the two files
    my($ininode, $outinode);
    $ininode = (stat $InDPath)[1];
    $outinode = (stat $OutDPath)[1];
    # If the files are the same, then just quietly delete the incoming one
    if ($ininode == $outinode) {
      $this->DeleteUnlock();
    } else {
      MailScanner::Log::WarnLog("Failed to link message body between queues " .
                   "($OutDPath --> $InDPath)");
    }
    return;
  }
}


# Write the temporary header data file, before it is made "live" by
# renaming it.
# Passed the parent message object we are working on, and the outqueue dir.
sub WriteHeader {
  my $this = shift;
  my($message, $Outq) = @_;

  my($hfile, $tfile, $Tf);

  #print STDERR "Writing header for message " . $message->{id} . "\n";
  $tfile = $this->{tname};
  $hfile = $this->{hname};
  # If the incoming queue was nested, the tname and hname will have
  # the qf,df,xf,tf prepended onto it, so we have to get rid of those.
  $tfile =~ s/^[qdxt]f\///;
  $hfile =~ s/^[qdxt]f\///;
  $tfile = $Outq . '/' . $tfile;
  $hfile = $Outq . '/' . $hfile;
  #print STDERR "tfile = $tfile and hfile = $hfile\n";

  umask 0077; # Add this to try to stop 0666 qf files
  $Tf = new FileHandle;
  MailScanner::Lock::openlock($Tf, ">$tfile", "w")
    or MailScanner::Log::DieLog("Cannot create + lock clean tempfile %s, %s",
                                $tfile, $!);

  $Tf->print(MailScanner::Sendmail::CreateQf($message))
    or MailScanner::Log::DieLog("Failed to write headers for unscanned " .
                                "message %s, %s", $message->{id}, $!);
  MailScanner::Lock::unlockclose($Tf);

  rename "$tfile", "$hfile"
    or MailScanner::Log::DieLog("Cannot rename clean %s to %s, %s",
                                $tfile, $hfile, $!);
}


# Return the size of the message
sub size {
  my $this = shift;

  my($size, $hpath, $dpath);

  # Return previous calculated value if it exists
  $size = $this->{size};
  return $size if $size;

  # Calculate it
  $hpath = $this->{hpath};
  $dpath = $this->{dpath};
  $size  = -s $hpath if -e $hpath;
  $size += -s $dpath if -e $dpath;

  # Store and return
  $this->{size} = $size;
  return $size;
}

# LEOH 26/03/2003 We do not have dpath in other mailers 
sub dsize {
  my $this = shift;
       return (stat($this->{dpath}))[7];
}

# Read the message body into an array.
# Passed a ref to the array.
# Read up to at least "$max" bytes, if the 2nd parameter is non-zero.
# The 2nd parameter is either
# 1) a number (with possible _ and k or m or g). Copy code from Config.pm
# 2) a number followed by "continue number"
# 3) a number followed by "trackback"
# 2 ==> Continue reading to the end of the encoding block (/^\s*$/) or number
#       of bytes whichever is the less
# 3 ==> Delete lines from the end of the encoding block back to the previous
#       blank line (/^\s*$/)
#
sub ReadBody {
  my $this = shift;
  my($body, $max) = @_;

  my $dh = $this->{indhandle};
  my $lastlineread = undef;

  seek($dh, 0, 0); # Rewind the file

  # Restraint is disabled, do the whole message.
  #print STDERR "max message size is '$max'\n";
  unless ($max) {
    while(defined($lastlineread = $dh->getline)) {
      # End of line characters are already there, so don't add them
      #push @{$body}, $lastlineread . "\n";
      push @{$body}, $lastlineread;
      #print STDERR "Line read is ****" . $_ . "****\n";
    }
    # A user reports SpamAssassin fails if the body doesn't end with an empty line
    if ($body->[@{$body}-1] !~ /^$/) {
      push @{$body}, "\n";
    }
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

  while(defined($line = <$dh>) && $size<$max) {
    push @{$body}, $line;
    $size += length($line);
    #print STDERR "Line read2 is ****" . $line . "****\n";
  }
  $lastlineread = $line;
  # A user reports SpamAssassin fails if the body doesn't end with an empty line
  if ($body->[@{$body}-1] !~ /^$/) {
    push @{$body}, "\n";
  }

  #print STDERR "Initially read $size bytes\n";

  # Handle trackback -- This is the tricky one
  if ($configwords[1] =~ /tr[ua]/i) {
    my $i;
    for ($i=(@{$body}-1); $i>=0; $i--) {
      last if $body->[$i] =~ /^\s*$/i;
      pop @{$body};
    }
    return;
  }

  #if ($configwords[1] =~ /tr[au]/i) {
  #  while (${@{$body}}[scalar(@{$body})-1] !~ /^\s*$/) {
  #    print "Line is ****" . ${@{$body}}[scalar(@{$body})-1] . "****\n";
  #    pop @{$body};
  #  }
  #  return;
  #}
  
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
      push @{$body}, $lastlineread;
      $lastlineread = <$dh>;
      #print STDERR "Added $lastlineread";
    }
    # A user reports SpamAssassin fails if the body doesn't end with an empty line
    if ($body->[@{$body}-1] !~ /^$/) {
      push @{$body}, "\n";
    }

    return;
  }

  ## Only use $max if it was set non-zero
  #if ($max) {
  #  my($line, $size);
  #  $size = 0;
  #  while(defined($line = <$dh>) && $size<$max) {
  #    push @{$body}, $line;
  #    $size += length($line);
  #  }
  #  # Continue copying until we hit a blank line, gives SA a complete
  #  # encoded attachment
  #  #while(defined $line) {
  #  #  $line = <$dh>;
  #  #  last if $line =~ /^\s+$/;
  #  #  push @{$body}, $line if defined $line;
  #  #}
  #}
}


# Write the message body to a file in the outgoing queue.
# Passed the message id, the root entity of the MIME structure
# and the outgoing queue directory.
sub WriteMIMEBody {
  my $this = shift;
  my($id, $entity, $outq) = @_;

  my($Df, $dfile, $InDPath, $OutDPath);

  # If the incoming queue was nested, the dname will have any of qf,df,xf,tf
  # pre-pended to it, so we have to get rid of this before we produce the
  # outgoing queue directory name.
  my $OutDPath = $this->{dname};
  $OutDPath =~ s/^[qdxt]f\///;
  $dfile = $outq . '/' . $OutDPath;

  #print STDERR "Writing MIME body of \"$id\" to $dfile\n";

  umask 0077; # Add this to try to stop 0666 df files
  $Df = new FileHandle;
  MailScanner::Lock::openlock($Df, ">$dfile", "w")
    or MailScanner::Log::DieLog("Cannot create + lock clean body %s, %s",
                                $dfile, $!);
  #print STDERR "File handle = $Df\n";
  $entity->print_body($Df)
    or MailScanner::Log::WarnLog("WriteMIMEBody to %s possibly failed, %s",
                                 $dfile, $!);
  MailScanner::Lock::unlockclose($Df);
}


# Copy a dfile and hfile to a directory
# Needs to be done inside a fork so as not to break locks.
# flock may be based on POSIX locks on some OS's (e.g. Solaris).
sub CopyToDir {
  my($this,$dir,$file,$uid,$gid,$changeowner) = @_;

  my $hpath = $this->{hpath};
  my $dpath = $this->{dpath};
  my $hfile = basename($hpath);
  my $dfile = basename($dpath);

  # Need to add this code if sendmail starts using POSIX locks
  my $pid = fork;
  MailScanner::Log::DieLog("fork: $!") if not defined $pid;
  if ($pid) {
    waitpid $pid, 0;
    return ("$dir/$hfile", "$dir/$dfile");
  }

  copy($hpath, "$dir/$hfile");
  copy($dpath, "$dir/$dfile");
  chown $uid, $gid, "$dir/$hfile", "$dir/$dfile" if $changeowner;
  exit;
}


# Write a message to a filehandle
sub WriteEntireMessage {
  my($this, $message, $handle, $pipe) = @_;

  # Uncomment this code if sendmail starts using POSIX locks
  # Do this in a subprocess in order to avoid breaking POSIX locks.
  # XXX: maybe conditionalize fork on the lock type & $pipe?
  my $pid = fork;
  MailScanner::Log::DieLog("fork: $!") if not defined $pid;
  if ($pid) {
    if ($pipe) {
      $handle->reader();
    } else {
      waitpid $pid, 0;
    }
    return $pid;
  }
  
  $handle->writer() if $pipe;

  copy($message->{headerspath}, $handle);
  copy($this->{dpath}, $handle);

  exit;
}



# Copy an entire copy of the message into a named file.
# The target directory name will already exist.
# May be more efficient to do this directly in perl
# rather than by invoking a shell to run cat.
# But it doesn't happen very often anyway.
sub CopyEntireMessage {
  my $this = shift;
  my($message, $targetdir, $targetfile, $uid, $gid, $changeowner) = @_;

  #my $hfile = $message->{headerspath};
  #my $dfile = $this->{dpath};
  #my $hpath = $this->{hpath};
  #
  if (MailScanner::Config::Value('storeentireasdfqf')) {
    # Don't need cp or cat any more! Yay :-)
    #system($global::cp . " \"$hpath\" \"$dfile\" \"$targetdir\"");
    return $this->CopyToDir($targetdir, $targetfile, $uid, $gid, $changeowner);
  } else {
    #system($global::cat . " \"$hfile\" \"$dfile\" > \"$targetdir/$targetfile\"");
    my $target = new IO::File "$targetdir/$targetfile", "w";
    MailScanner::Log::DieLog("writing to $targetdir/$targetfile: $!")
      if not defined $target;
    $this->WriteEntireMessage($message, $target);
    return ($targetdir . '/' . $targetfile);
  }
}


# Produce a pipe that will read the whole message.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
sub ReadMessagePipe {
  my $this = shift;
  my $message = shift;

  #my($hfile, $dfile);
  #my $pipe = new FileHandle;
  my $pipe = new IO::Pipe;
  my $pid;

  #$hfile = $message->{headerspath};
  #$dfile = $this->{dpath};
  #my $cmd = $global::cat . " \"$hfile\" \"$dfile\"";
  #
  #unless (open($pipe, "$cmd |")) {
  #  MailScanner::Log::WarnLog("Cannot build message from $hfile " .
  #                            "and $dfile, %s", $!);
  #}
  #return $pipe;

  if (not defined $pipe or not defined ($pid = fork)) {
    MailScanner::Log::WarnLog("Cannot build message from $this->{dpath} " .
                              "and $message->{headerspath}, %s", $!);
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

  #my $pipe = new IO::Pipe;
  #
  #MailScanner::Log::DieLog("Cannot build message from $this->{dpath} " .
  #                        "and $message->{headerspath}, %s", $!)
  #       unless defined $pipe;
  #
  #my $pid = $this->WriteEntireMessage($message, $pipe, 'pipe');
  #
  ## We have to tell the caller what the child's pid is in order to
  ## reap it. Although IO::Pipe does this for us when it is told to
  ## fork and exec, it unfortunately doesn't have a neat hook for us
  ## to tell it the pid when we do the fork. Bah.
  #return ($pipe,$pid);

}


# Writes the whole message to a handle.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
sub ReadMessageHandle {
  my $this = shift;
  my ($message, $handle) = @_;

  # we use already opened handles
  #my $hhandle = $this->{inhhandle};
  #my $dhandle = $this->{indhandle};

  my $hhandle = $message->{headerspath};
  my $dhandle = $this->{dpath};

  # rewind files to read and write with File::Copy
  sysseek($handle , 0, 0); # Rewind the file
  sysseek($hhandle, 0, 0); # Rewind the file
  sysseek($dhandle, 0, 0); # Rewind the file

  # File::Copy does not close our handles
  # so locks are preserved
  copy($hhandle , $handle);
  copy($dhandle , $handle);

  # rewind tmpfile to read it later
  sysseek($handle, 0, 0); # Rewind the file

  # rewind source files
  sysseek($hhandle, 0, 0); # Rewind the file
  sysseek($dhandle, 0, 0); # Rewind the file

  return 1;
  }



# This is now done much further up
## Copy a dfile and hfile to a directory
#sub CopyToDir {
#  my $this = shift;
#  my($dir) = @_;
#
#  system($global::cp . " \"" . $this->{dpath} . "\" \"" .
#         $this->{hpath} . "\" \"$dir\"");
#}

1;
