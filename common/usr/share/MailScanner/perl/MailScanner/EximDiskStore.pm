#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: EximDiskStore.pm 4446 2008-05-08 19:15:02Z sysjkf $
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
$VERSION = substr q$Revision: 4446 $, 10;

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
#$VERSION = substr q$Revision: 4446 $, 10;

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
  $this->{dname} = $mta->DFileName($id);
  $this->{hname} = $mta->HFileName($id);
  $this->{tname} = $mta->TFileName($id);
  $this->{lname} = $mta->LFileName($id); # Per-message log file for Exim

  $this->{dpath} = $dir . '/' . $this->{dname};
  $this->{hpath} = $dir . '/' . $this->{hname};
  $this->{lpath} = $dir . '/' . $this->{lname}; # Per-message log file for Exim

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
  MailScanner::Lock::openlock($this->{inhhandle}, '+<' . $this->{hpath},
                              'w', 'quiet')
    or return 0;
  #print STDERR "Got hlock\n";

  # If locking the dfile fails, then must close and unlock the qffile too
  unless (MailScanner::Lock::openlock($this->{indhandle},
                      '+<' . $this->{dpath}, 'w', 'quiet')) {
    MailScanner::Lock::unlockclose($this->{inhhandle});
    return 0;
  }
  #print STDERR "Got dlock\n";
  return 0 unless $this->{inhhandle} && $this->{indhandle};
  return 1;
}


# Close and unlock the message
sub Unlock{
  my $this = shift;

  MailScanner::Lock::unlockclose($this->{indhandle});
  MailScanner::Lock::unlockclose($this->{inhhandle});
}


# Delete a message (from incoming queue)
sub Delete {
  my $this = shift;

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  @DeletesPending = ($this->{hpath}, $this->{dpath}, $this->{lpath});

  unlink($this->{hpath});
  unlink($this->{dpath});
  unlink($this->{lpath});

  # Clear list of pending deletes
  @DeletesPending = ();
}

# Unlock and delete a message (from incoming queue)
# This will almost certainly be called more than once for each message
sub DeleteUnlock {
  my $this = shift;

  # FIXME: should probably check that we have a lock first.

  # Exim use the -H files for finding things, and -D files
  # for locking. We currently lock both (saves confusion as
  # sendmail locks qfiles)

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  @DeletesPending = ($this->{hpath}, $this->{dpath}, $this->{lpath});

  # Once -H file is unlinked Exim won't start to try anything
  # with this message...
  # NB: unlinking *can* fail in some cases, even if we're root.
  unlink($this->{hpath});
  #  or MailScanner::Log::WarnLog("Unlinking %s failed: %s",
  #                               $this->{hpath}, $!);
  MailScanner::Lock::unlockclose($this->{inhhandle});

  # Now lose the -D file...
  unlink($this->{dpath});
  #  or MailScanner::Log::WarnLog("Unlinking %s failed: %s",
  #                               $this->{dpath}, $!);
  MailScanner::Lock::unlockclose($this->{indhandle});

  # What happens if Exim opens -H file before we unlink it,
  # opens -D file before we unlink it, then gets pre-empted
  # while we unlink and unlock both, then locks the FD it
  # has for the open (but unlinked) -D file??
  # What happens if we do the same?

  #print STDERR "Per-message log file is " . $this->{lpath} . "\n";
  unlink($this->{lpath});

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

# Work out the name of an output queue subdirectory, depending on
# whether the spool is split or not.
sub OutQDir {
  my $name = shift;

  if (MailScanner::Config::Value('spliteximspool')) {
    return '/' . substr($name,-13,1) . '/';
  } else {
    return '/';
  }
}
sub OutQName {
  my $dir = shift;
  my $name = shift;
  return $dir . OutQDir($name) . $name;
}

# Link at least the data portion of the message
sub LinkData {
  my $this = shift;
  my($OutQ) = @_;

  my($InDPath, $OutDPath);

  $InDPath = $this->{dpath};
  #$OutDPath = $OutQ . '/' . $this->{dname};
  $OutDPath = OutQName($OutQ, $this->{dname});
  #MailScanner::Log::DebugLog("LinkData to $OutDPath");

  # If the link fails for some reason, then skip this message and
  # move on to the next one. This one will get delivered when
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
  #$tfile = $Outq . '/' . $this->{tname};
  #$hfile = $Outq . '/' . $this->{hname};
  $tfile = OutQName($Outq, $this->{tname});
  $hfile = OutQName($Outq, $this->{hname});
  #print STDERR "tfile = $tfile and hfile = $hfile\n";
  #MailScanner::Log::DebugLog("WriteHeader to $hfile");

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
sub ReadBody {
  my $this = shift;
  my($body, $max) = @_;
  my $dh = $this->{indhandle};

  seek($dh, 0, 0); # Rewind the file

  my $line = <$dh>;
  # FIXME: check that id is correct here

  my @configwords = split(" ", $max);
  $max = $configwords[0];
  $max =~ s/_//g;
  $max =~ s/k$/000/ig;
  $max =~ s/m$/000000/ig;
  $max =~ s/g$/000000000/ig;
  #print STDERR "Words are " . join(',',@configwords) . "\n";

  # Only use $max if it was set non-zero
  if ($max) {
    my $size = 0;
    while(defined($line = <$dh>) && $size<$max) {
      push @{$body}, $line;
      $size += length($line);
    }
    # Continue copying until we hit a blank line, gives SA a complete
    # encoded attachment
    #while(defined $line) {
    #  $line = <$dh>;
    #  last if $line =~ /^\s+$/;
    #  push @{$body}, $line if defined $line;
    #}
  } else {
    while(<$dh>) {
      # End of line characters are already there, so don't add them
      #push @{$body}, $_ . "\n";
      push @{$body}, $_;
    }
  }
}


# Write the message body to a file in the outgoing queue.
# Passed the message id, the root entity of the MIME structure
# and the outgoing queue directory.
sub WriteMIMEBody {
  my $this = shift;
  my($id, $entity, $outq) = @_;

  my($Df, $dfile);

  #$dfile = $outq . '/' . $this->{dname};
  $dfile = OutQName($outq, $this->{dname});
  #MailScanner::Log::DebugLog("WriteMIMEBody $id to $dfile");
  #print STDERR "Writing MIME body of \"$id\" to $dfile\n";

  $Df = new FileHandle;
  MailScanner::Lock::openlock($Df, ">$dfile", "w")
    or MailScanner::Log::DieLog("Cannot create + lock clean body %s, %s",
                                $dfile, $!);
  #print STDERR "File handle = $Df\n";
  $Df->print($global::MS->{mta}->DFileName($id)."\n");
  $entity->print_body($Df);
  MailScanner::Lock::unlockclose($Df);
}


# Copy a dfile and hfile to a directory
# This has to be done in a subprocess in order to avoid breaking POSIX locks.
# XXX: maybe conditionalize fork on the lock type?
sub CopyToDir {
  my($this,$dir,$file,$uid,$gid,$changeowner) = @_;
  my $hpath = $this->{hpath};
  my $dpath = $this->{dpath};
  my $hfile = basename($hpath);
  my $dfile = basename($dpath);
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
  #my($this, $message, $handle) = @_;

  my($this, $message, $handle, $pipe) = @_;

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

  my $body = new IO::File $this->{dpath}, "r";
  # We have to strip the message-ID off the beginning of the file
  # using sysread since that is what File::Copy uses and it doesn't
  # play nicely with stdio operations such as $body->getline. The
  # magic number 19 is from the length of NNNNNN-NNNNNN-NN-D\n.
  my $discard;
  sysread($body, $discard, 19);

  copy($body, $handle);

  # Now we have to ensure there was a newline on the end of the $handle
  # or the $body. $body is an IO::File which makes it an IO::Seekable too!
  # So seek to EOF and read the last byte. If not \n or \r then add a
  # \n on the end, to make sure the last line is properly terminated.
  my $lasteol = ' ';
  # UTF16 may bite here, beware...
  $body->sysseek(-1, 2); # 2 = SEEK_END. -1 ==> just before last byte
  if ($body->sysread($lasteol, 1) && $lasteol !~ /[\n\r]/s) {
    $lasteol = "\n";
    $body->syswrite($lasteol);
  }
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
  #my $cmd;
  #
  #if (MailScanner::Config::Value('storeentireasdfqf')) {
  #  $cmd = $global::cp . " \"$hpath\" \"$dfile\" \"$targetdir\"";
  #}
  #else {
  #  $global::sed='/bin/sed'; $global::cat='/bin/cat';
  #  $cmd = $global::sed . " -e '1d' \"$dfile\" | $global::cat \"$hfile\" - > \"$targetdir/$targetfile\"";
  #}
  ##print STDERR "About to 'CopyEntireMessage'...\n$cmd\n";
  #
  #system($cmd);

  if (MailScanner::Config::Value('storeentireasdfqf')) {
    return $this->CopyToDir($targetdir, $targetfile, $uid, $gid, $changeowner);
  } else {
    my $target = new IO::File "$targetdir/$targetfile", "w";
    MailScanner::Log::DieLog("writing to $targetdir/$targetfile: $!")
      if not defined $target;
    $this->WriteEntireMessage($message, $target);
    return "$targetdir/$targetfile";
  }

  return 1;
}

# Writes the whole message to a handle.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
sub ReadMessageHandle {
  my $this = shift;
  my ($message, $handle) = @_;

  my $hhandle = $message->{headerspath};
  my $dhandle = $this->{dpath};

  # File::Copy does not close our handles
  # so locks are preserved
  copy($hhandle , $handle);

  # We have to strip the message-ID off the beginning of the file
  # using sysread since that is what File::Copy uses and it doesn't
  # play nicely with stdio operations such as $body->getline. The
  # magic number 19 is from the length of NNNNNN-NNNNNN-NN-D\n.
  my $from_h = \do { local *FH1 };
  open($from_h, "< $dhandle");
  binmode $from_h or die "($!,$^E)";

  sysseek($from_h, 19, 0);

  my $size;
  my $buf = "";
  my $lasteol = ' ';
  my $dlength = -s $dhandle; # Catch case where -D file is 0 (ie 19) bytes
  $size = $dlength;
  $size = 1024 if ($size < 512);
  $size = 1024*1024*2 if $size > 1024*1024*2;
  local($\) = '';
  my $to_h   = $handle;

  for (;;) {
    my ($r, $w, $t);
    $r = sysread($from_h, $buf, $size);
    last unless $r;
    $lasteol = substr($buf, -1); # Copy last byte of string $buf
    for ($w = 0; $w < $r; $w += $t) {
      $t = syswrite($to_h, $buf, $r - $w, $w);
    }
  }

  # Need to ensure the end of the file is and new-line character,
  # unless it's a 0 length file.
  if ($lasteol !~ /[\n\r]/s && $dlength>19) {
    $lasteol = "\n";
    syswrite($to_h, $lasteol);
  }

  # rewind tmpfile to read it later
  sysseek($handle, 0, 0); # Rewind the file

  return 1;
}



# Produce a pipe that will read the whole message.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
sub ReadMessagePipe {
  my $this = shift;
  my $message = shift;

  #my($hfile, $dfile);
  #my $pipe = new FileHandle;
  #
  #$hfile = $message->{headerspath};
  #$dfile = $this->{dpath};
  #$global::sed = '/bin/sed'; $global::cat = '/bin/cat';
  #my $cmd = $global::sed . " -e '1d' \"$dfile\" | $global::cat \"$hfile\" -";
  ##my $cmd = $global::cat . " \"$hfile\" \"$dfile\"";
  #
  #unless (open($pipe, "$cmd |")) {
  #  MailScanner::Log::WarnLog("Cannot build message from $hfile " .
  #                            "and $dfile, %s", $!);
  #}
  #return $pipe;

  my $pipe = new IO::Pipe;
  #my $pid;
  #
  #if (not defined $pipe or not defined ($pid = fork)) {
  #  MailScanner::Log::WarnLog("Cannot build message from $this->{dpath} " .
  #                            "and $message->{headerspath}, %s", $!);
  #} elsif ($pid) { # Parent
  #  $pipe->reader();
  #  # We have to tell the caller what the child's pid is in order to
  #  # reap it. Although IO::Pipe does this for us when it is told to
  #  # fork and exec, it unfortunately doesn't have a neat hook for us
  #  # to tell it the pid when we do the fork. Bah.
  #  return ($pipe,$pid);
  #} else { # Child
  #  $pipe->writer();
  #  $this->WriteEntireMessage($message, $pipe);
  #  $pipe->close();
  #  exit;
  #}

  MailScanner::Log::DieLog("Cannot build message from $this->{dpath} " .
                          "and $message->{headerspath}, %s", $!)
         unless defined $pipe;

  my $pid = $this->WriteEntireMessage($message, $pipe, 'pipe');

  # We have to tell the caller what the child's pid is in order to
  # reap it. Although IO::Pipe does this for us when it is told to
  # fork and exec, it unfortunately doesn't have a neat hook for us
  # to tell it the pid when we do the fork. Bah.
  return ($pipe,$pid);

}

# This is now defined much further up
## Copy a dfile and hfile to a directory
#sub CopyToDir {
#  my $this = shift;
#  my($dir) = @_;
#
#  system($global::cp . " \"" . $this->{dpath} . "\" \"" .
#         $this->{hpath} . "\" \"$dir\"");
#}

1;
