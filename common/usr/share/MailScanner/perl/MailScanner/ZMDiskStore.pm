#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: ZMDiskStore.pm 4129 2007-08-14 18:58:39Z sysjkf $
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
$VERSION = substr q$Revision: 4129 $, 10;

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
#$VERSION = substr q$Revision: 4129 $, 10;

# Attributes are
#
# $dir                 set by new (incoming queue dir in case we use it)
# $hdname              set by new (filename component only)
# $tname               set by new (filename component only)
# $hdpath              set by new (full path)
# $size                        set by size
# $inhdhandle          set by lock
#
#

# Constructor.
# Takes message id and directory name.
#REVISO LEOH
sub new {
  my $type = shift;
  my($id, $dir) = @_;
  my $this = {};
  my $mta  = $global::MS->{mta};
  $this->{dir} = $dir;

  #print STDERR "Creating SMDiskStore($id)\n";
  $this->{hdname} = $mta->HDFileName($id);
  $this->{tname} = $mta->TFileName($id);

  $this->{hdpath} = $dir . '/' . $this->{hdname};

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
#REVISO LEOH
sub Lock {
  my $this = shift;

  #print STDERR "About to lock " . $this->{hdpath} 
  MailScanner::Lock::openlock($this->{inhdhandle}, '+<' . $this->{hdpath}, 'w', 'quiet')
    or return undef;
  #print STDERR "Got hdlock\n";

  return undef unless $this->{inhdhandle};
  return 1;
}


# Close and unlock the message
# REVISO LEOH
sub Unlock {
  my $this = shift;

  #ZZMailScanner::Lock::unlockclose($this->{indhandle});
  MailScanner::Lock::unlockclose($this->{inhdhandle});
}


# Delete a message (from incoming queue)
# REVISO LEOH
sub Delete {
  my $this = shift;

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  @DeletesPending = ($this->{hdpath});

  unlink($this->{hdpath});
  #  or MailScanner::Log::WarnLog("Unlinking %s failed",
  #                               $this->{hpath});

  # Clear list of pending deletes
  @DeletesPending = ();
}

# Delete and unlock a message (from the incoming queue)
# This will almost certainly be called more than once for each message
# REVISO LEOH
sub DeleteUnlock {
  my $this = shift;

  #print STDERR "DeleteUnlock\n";

  # Maintain a list of pending deletes so we can clear up properly
  # when killed
  @DeletesPending = ($this->{hdpath});

  unlink($this->{hdpath});
  #  or MailScanner::Log::WarnLog("Unlinking %s failed: %s",
  #                               $this->{hpath}, $!);
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
# Messages (I'm trying to modify only ZM* files)
# REVISO LEOH
sub LinkData {
  my $this = shift;
  my($OutQ) = @_;
       $this->{body}=[ "ORIGINAL", $OutQ ];
  return;
}


# Write the temporary header data file, before it is made "live" by
# renaming it.
# Passed the parent message object we are working on, and the outqueue dir.
# There is only one message, so this function have to write "both"
# REVISO LEOH
sub WriteHeader {
  my $this = shift;
  my($message, $Outq) = @_;

  my($tfile, $Tf);

  #print STDERR "Writing header for message " . $message->{id} . "\n";
  $tfile = $Outq . '/' . $this->{tname};

  umask 0077; # Add this to try to stop 0666 qf files
  $Tf = new FileHandle;
  MailScanner::Lock::openlock($Tf, ">$tfile", "w")
    or MailScanner::Log::DieLog("Cannot create + lock clean tempfile %s, %s",
                                $tfile, $!);

  $Tf->print(MailScanner::Sendmail::CreateQf($message))
    or MailScanner::Log::DieLog("Failed to write headers for unscanned " .
                                "message %s, %s", $message->{id}, $!);

  if( $this->{body}[0] eq "ORIGINAL" ) {
    #my $b= Body->new( $this->{hdpath} );
    my $b= Body->new( $this->{inhdhandle} );
    $b->Start();
    my $line;
    #print STDERR "originalBody\n";
    while( defined ($line= $b->Next()) ) {
      $Tf->print($line);
    #print STDERR "BODY:  $line";
    }
    $b->Done();
  }
  elsif ($this->{body}[0] eq "MIME" ) {
    my ($type, $id, $entity, $outq)= @{$this->{body}};
    $entity->print_body($Tf)
       or MailScanner::Log::WarnLog("WriteMIMEBody to %s possibly failed, %s",
                                       $tfile, $!);
  }
  MailScanner::Lock::unlockclose($Tf);

  my $newid = MailScanner::Sendmail::HDOutFileName($tfile);
  my $hdoutfile=$tfile;
  $message->{newid} = $newid;
  $hdoutfile =~ s/[^\/]+$/$newid/;
  #print STDERR "tfile = $tfile and hdoutfile = $hdoutfile\n";
  rename "$tfile", "$hdoutfile"
    or MailScanner::Log::DieLog("Cannot rename clean %s to %s, %s",
                                $tfile, $hdoutfile, $!);
  MailScanner::Log::InfoLog("ZM: message %s renamed into %s",$message->{id},$message->{newid});
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
#REVISO LEOH
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
#REVISO LEOH
# Read up to at least "$max" bytes, if the 2nd parameter is non-zero.
sub ReadBody {
  my $this = shift;
  my($body, $max) = @_;

  #my $b= Body->new( $this->{hdpath} );
  my $b= Body->new( $this->{inhdhandle} );
  $b->Start();

  my @configwords = split(" ", $max);
  $max = $configwords[0];
  $max =~ s/_//g;
  $max =~ s/k$/000/ig;
  $max =~ s/m$/000000/ig;
  $max =~ s/g$/000000000/ig;
  #print STDERR "Words are " . join(',',@configwords) . "\n";

  my $line;
  if ($max) {
    my $size = 0;
    while(defined($line = $b->Next()) && $size<$max) {
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
    while(defined($line= $b->Next())) {
      push @{$body}, $line;
    }
  }
  $b->Done();
}


# Write the message body to a file in the outgoing queue.
# Passed the message id, the root entity of the MIME structure
# and the outgoing queue directory.
# REVISO LEOH
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
sub CopyEntireMessage {
  my $this = shift;
  my($message, $targetdir, $targetfile, $uid, $gid, $changeowner) = @_;

  #my $hdfile = $this->{hdpath};
  ##system($global::cp . " \"$hdfile\" \"$targetdir/$$this{tname}\"");
  #rename("$hdfile", "$targetdir/$$this{hdname}");
  ##my $hdoutpath=MailScanner::Sendmail::HDOutFileName($targetdir/$$this{tname});

  # BBY we were moving instead of copying... now we copy(cat)
  # BBY Julian's higher level solution that is much clearer
  # BBY and storeentireasdfqf means "include envelope" which
  # BBY is quite reasonable

  #print STDERR "Copying to $targetdir $targetfile\n";
  if (MailScanner::Config::Value('storeentireasdfqf')) {
    #print STDERR "Copying to dir $targetdir\n";
    return $this->CopyToDir($targetdir, $targetfile, $uid, $gid, $changeowner);
  } else {
    #print STDERR "Copying to file $targetdir/$targetfile\n";
    my $target = new IO::File "$targetdir/$targetfile", "w";
    MailScanner::Log::WarnLog("writing to $targetdir/$targetfile: $!")
      if not defined $target;
    $this->WriteEntireMessage($message, $target);
    return "$targetdir/$targetfile";
  }
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

  my $flagMsg=0;
  my $hdfile = $this->{hdpath};
  if( open( FPIN, "<$hdfile" ) ) {
    while( <FPIN> ) {
      print $handle $_ if( $flagMsg );
      if( $flagMsg || /^env-end\015?$|^env-eof\015?$/i ) {
        $flagMsg=1;
      }
    }
  } else {
    MailScanner::Log::WarnLog("Cannot build message from $hdfile, %s", $!);
  }
}

# Copy a hdfile to a directory
#REVISO LEOH
sub CopyToDir {
  my($this,$dir,$file,$uid,$gid,$changeowner) = @_;
  my $hdpath = $this->{hdpath};
  my $hdfile = basename($hdpath);
  copy($hdpath, "$dir/$hdfile");
  chown $uid, $gid, "$dir/$hdfile" if $changeowner;
  return "$dir/$hdfile";
}

# Writes the whole message to a handle.
# Need to be passed the message to find the headers path
# as it's not part of the DiskStore.
# PERT-LEOH: We could optimize saving file position in ReadQf, 
# and accessing the queue file, directly
sub ReadMessageHandle {
  my $this = shift;
  my ($message, $handle) = @_;

  # Where did we start?
  my $oldpos = $this->{inhdhandle}->getpos();

  # Write the whole message in RFC822 format to the handle.
  # That means 1 CR-terminated line for every N record in the file.
  my $b= Body->new( $this->{inhdhandle} );
  $b->Start(1);
  my $line;
  #print STDERR "originalBody\n";
  while(defined($line = $b->Next())) {
    print $handle $line or MailScanner::Log::DieLog("Cannot print " . $this->{hdpath} . " into handle $!, $^E" );
    #print STDERR "BODY:  $line";
  }
  $b->Done();

  # rewind tmpfile to read it later
  $handle->seek(0,0) or MailScanner::Log::DieLog("Cannot rewind handle $!, $^E" );

  # rewind source files
  $this->{inhdhandle}->setpos($oldpos);

  #print STDERR "Done ReadMessageHandle\n";
  return 1;
}


package Body;

use FileHandle;

sub new {
  my $type = shift;
  #my ( $hdpathname )=@_;
  my ( $handle )=@_;
  my $self=();
  #my $handle= new FileHandle "<$hdpathname";
  if( defined $handle ) {
    #$self={ _hdpathname => $hdpathname, 
    $self={ 
            _handle     => $handle,
            _startpos   => "-UNDEF-" };

    bless $self, $type;
  } else {
    #MailScanner::Log::DieLog("Cannot open %s, %s",
    #                            $hdpathname, $!);
    MailScanner::Log::DieLog("Cannot open handle, %s", $!);
  }
  return $self;
}

sub Start {
  #my ( $this )=@_;
  my ($this,$entiremessage )=@_;
  if( $$this{_startpos} eq "-UNDEF-" ) {
    seek $$this{_handle}, 0, 0; # reset the handle
    my $InHeader = 0;
    #print STDERR "Start\n";
    while($_=$$this{_handle}->getline) {
      #print STDERR "Start LEIDO: $_";
      chomp; # Chomp everything now. We can easily add it back later.
      #s/\015/ /g; # Sanitise everything by removing all embedded <CR>s
      #if ( /^env-end$|^env-eof$/i ) { # The envelope ends here, starting hdr
      if ( /^env-end\015?$|^env-eof\015?$/i ) { # The envelope ends here, starting hdr
        last if $entiremessage;
        $InHeader=1;
        #print STDERR "InHeader\n";
        next;
      }
      last if( $InHeader && /^\s*$/ ); # One blank line ends whith the header part
    }
               
    $$this{_startpos}= $$this{_handle}->getpos();
    #print STDERR "_startpos=$$this{_startpos}\n";
  }
  $$this{_handle}->setpos($$this{_startpos});
}

sub Next {
  my ( $this )=@_;
       
  if( $$this{_startpos} eq "-UNDEF-" ) {
    $this->Start();
  }
  return( $$this{_handle}->getline );
}

sub Done {
  my ( $this )=@_;
  undef $$this{_handle};
  $$this{_startpos} = "-UNDEF-";
}

1;
