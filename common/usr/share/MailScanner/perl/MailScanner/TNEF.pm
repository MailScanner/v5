#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: TNEF.pm 5119 2013-06-17 13:29:15Z sysjkf $
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

package MailScanner::TNEF;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use DirHandle;
use File::Temp qw/ tempfile tempdir /;
use POSIX qw(:signal_h setsid); # For Solaris 9 SIG bug workaround

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5119 $, 10;

my($UseTNEFModule) = 0;

# Attributes are
#

# Install an extra MIME decoder for badly-header uue messages.
install MIME::Decoder::UU 'uuencode';

sub initialise {
  if (MailScanner::Config::Value('tnefexpander') eq 'internal') {
   require Convert::TNEF;
   require File::Copy;
   require File::Temp;
   $UseTNEFModule = 1;
  }
}

# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  #$this->{dir} = shift;

  bless $this, $type;
  return $this;
}


# Look through an entity to find a TNEF file. Recursive.
# Returns a list of the entity and the real filename with type indicator
sub FindTNEFFile {
  my($entity) = @_;

  my(@parts, $body, $part, $path, $headfile, $tnef, $filename);

  # Find the body for this entity
  return undef unless $entity;
  $body = $entity->bodyhandle;
  if (defined($body) && defined($body->path)) {   # data is on disk:
    $path = $body->path;
    $filename = $path;
    $filename =~ s#^.*/([^/]+)$#$1#;
    return ($entity,$filename) if $filename =~ /winmail\d*\.dat\d*$/i;
    #$path =~ s#^.*/([^/]*)$#$1#;
  }
  # And the head, which is where the recommended filename is stored
  # This is so we can report infections in the filenames which are
  # recommended, even if they are evil and we hence haven't used them.
  $headfile = $entity->head->recommended_filename;
  $filename = $headfile;
  $filename =~ s#^.*/([^/]+)$#$1#;
  return ($entity,$filename)
    if (defined($filename) && $filename =~ /winmail\d*\.dat\d*$/i);

  # And for all its children
  @parts = $entity->parts;
  foreach $part (@parts) {
    ($tnef,$filename) = FindTNEFFile($part);
    return ($tnef,$filename) if defined($tnef);
  }

  # Must return something.
  return (undef,undef);
}


#
# Higher level function which calls the internal or external decoder
# as requested in the .conf file.
#
sub Decoder {
  my($dir, $tnefname, $message) = @_;

  my $perms = $global::MS->{work}->{fileumask} ^ 0777;
  my $owner = $global::MS->{work}->{uid};
  my $group = $global::MS->{work}->{gid};
  my $change= $global::MS->{work}->{changeowner};

  return InternalDecoder($dir, $tnefname, $message,
                         $perms, $owner, $group, $change) if $UseTNEFModule;
  return ExternalDecoder($dir, $tnefname, $message,
                         $perms, $owner, $group, $change);
}


# Expand the tnef file stored at $1/$2.
# Use the internal TNEF module.
# Return 1 on success, 0 on failure.
sub InternalDecoder {
  my($dir, $tnefname, $message, $perms, $owner, $group, $change) = @_;
  my($fh, %parms);

  # Make the temporary tnef files be created under /tmp for easy removal.
  my $tempdir = tempdir();
  chmod 0755, $tempdir;
  %parms = ( ignore_checksum => "true",
             output_dir      => $tempdir,
             output_to_core  => "NONE" );
  my $tnef = Convert::TNEF->read_in("$dir/$tnefname", \%parms);

  if ($tnef) {
    #print STDERR "Parsing returned something\n";
    #print STDERR "Attachment list is \"" . $tnef->attachments . "\"\n";
    #print STDERR "List is \"" . join('","', @{$tnef->attachments}) . "\"\n";
    my $addcontents = 0;
    $addcontents = 1
      if MailScanner::Config::Value('replacetnef',$message) =~ /[12]/;
    $message->{entity}->make_multipart if $addcontents;

    my($safename, $handle, @replacements, $attachname);
    foreach $attachname (@{$tnef->attachments}) {
      #print STDERR "Doing attachment $attachname\n";
      #print STDERR "Have a datahandle $handle\n";
      # There is a method to get the filename from the attachment,
      # but it of course is teinted (and you might end up overwriting
      # attachments with the same name within the same file)
      # so you might just want to generate
      # your own temp file name or use File::Temp
      # Make sure the temp file we create starts with a 't' as this is a
      # file extracted from a tnef archive.
      #($fh, $filename) = File::Temp::tempfile("tTNEFattachmentXXXXX",
      #                                        DIR => $dir,
      #                                        UNLINK => 0);
      # file2parent must not contain the leading 't'.
      $safename = $message->MakeNameSafe('t'.($attachname->longname), $dir);
      #print STDERR "Tempfile = $safename\n";
      $message->{file2parent}{substr($safename,1)} = $tnefname;
      $message->{file2parent}{$safename} = $tnefname; # For good measure!
      $handle = $attachname->datahandle;
      my $tmpnam1 = "$dir/$safename";
      $tmpnam1 =~ /^(.*)$/;
      $tmpnam1 = $1;
      if ($handle && defined(my $file = $handle->path)) {
        rename($file, $tmpnam1);
        # JKF 20090421 CHMOD, then CHOWN and CHGRP it if necessary.
        chmod $perms, $tmpnam1;
        chown $owner, $group, $tmpnam1 if $change;
        #print STDERR "Moved $file to $safename\n";
      }
      #close($fh);

      if ($addcontents) {
        # Add the member file to the list of attachments in the message
        # The safe filename will have a 't' for TNEF at the front.
        #$safename = $message->MakeNameSafe($attachname->longname, $dir);
        push @replacements, substr($safename,1); # Without the type
        $message->{entity}->attach(Type => "application/octet-stream",
                                   Encoding => "base64",
                                   Disposition => "attachment",
                                   Filename => $attachname->longname,
                                   Path => $tmpnam1); # Has type
        $message->{bodymodified} = 1;
      }
    }
    $tnef->purge unless $addcontents;
    undef $tnef;
    $message->{foundtnefattachments} = 1;
    #$message->{entity}->dump_skeleton();
    system("rm -rf $tempdir"); # /tmp/tnef.$$");
    MailScanner::Log::InfoLog("Message %s added TNEF contents %s",
                              $message->{id},
                              join(',', @replacements))
      if @replacements;
    return 1;
  } else {
    # It failed
    undef $tnef;
    system("rm -rf $tempdir");
    return 1 if MailScanner::Config::Value('deliverunparsabletnef',$message);
    return 0;
  }
}


# Expand the tnef file stored at $1/$2.
# Use the external TNEF program.
# Return 1 on success, 0 on failure.
# This can't setup file2parent as it doesn't know the name of the children.
# New - Unpack it into a subdirectory so we don't have name clashes anywhere.
sub ExternalDecoder {
  my($dir, $tnefname, $message, $perms, $owner, $group, $change) = @_;

  # Create the subdir to unpack it into
  #my $unpackdir = "tnef.$$";
  my $unpackdir = tempdir("tnefXXXXXX", DIR => $dir);
  # This line shouldn't be here any more! $dir =~ s,^.*/,,;
  # And leave $unpackdir as the full path.
  #$unpackdir = $message->MakeNameSafe($unpackdir, $dir);
  unless (-d $unpackdir) {
    MailScanner::Log::WarnLog("Trying to unpack %s in message %s, could not create subdirectory %s, failed to unpack TNEF message", $tnefname, $message->{id},
                              "$unpackdir");
    return 0;
  }
  # Convert Incoming Work Permissions to an octal value and add search.
  my $perms = oct(sprintf("%s", MailScanner::Config::Value('workperms')))
    | 0111;
  chmod $perms, $unpackdir;
  # Try to set Incoming Work User and Group.
  my $uname = MailScanner::Config::Value('workuser');
  my $gname = MailScanner::Config::Value('workgroup');
  my $uid = $uname?getpwnam($uname):-1;
  my $gid = $gname?getgrnam($gname):-1;
  chown $uid, $gid, $unpackdir;

  my $cmd = MailScanner::Config::Value('tnefexpander') .
            " -f $dir/$tnefname -C $unpackdir --overwrite";

  my($kid);
  my($TimedOut, $PipeReturn, $pid);
  $kid = new FileHandle;

  $TimedOut = 0;

  eval {
    die "Can't fork: $!" unless defined($pid = open($kid, "-|"));
    if ($pid) {
      # In the parent
      local $SIG{ALRM} = sub { $TimedOut = 1; die "Command Timed Out" }; # 2.53
      alarm MailScanner::Config::Value('tneftimeout');
      close $kid; # This will wait for completion
      $PipeReturn = $?;
      $pid = 0;
      alarm 0;
      # Workaround for bug in perl shipped with Solaris 9,
      # it doesn't unblock the SIGALRM after handling it.
      eval {
        my $unblockset = POSIX::SigSet->new(SIGALRM);
        sigprocmask(SIG_UNBLOCK, $unblockset)
          or die "Could not unblock alarm: $!\n";
      };
    } else {
      POSIX::setsid(); # 2.53
      exec $cmd or die "Can't run tnef decoder: $!";
    }
  };
  alarm 0; # 2.53

  # Note to self: I only close the $kid in the parent, not in the child.

  # Catch failures other than the alarm
  MailScanner::Log::DieLog("TNEF decoder failed with real error: $@")
    if $@ and $@ !~ /Command Timed Out/;

  # In which case any failures must be the alarm
  if ($@ or $pid>0) {
    # Kill the running child process
    my($i);
    kill 'TERM', $pid;
    # Wait for up to 5 seconds for it to die
    for ($i=0; $i<5; $i++) {
      sleep 1;
      waitpid($pid, &POSIX::WNOHANG);
      ($pid=0),last unless kill(0, $pid);
      kill -15, $pid;
    }
    # And if it didn't respond to 11 nice kills, we kill -9 it
    if ($pid) {
      kill -9, $pid;
      waitpid $pid, 0; # 2.53
    }
  }

  # Now the child is dead, look at all the return values

  # Do we want to deliver unparsable TNEF files anyway (like we used to)
  if (MailScanner::Config::Value('deliverunparsabletnef',$message)) {
    return 0 if $TimedOut; # Ignore tnef command exit status
    return 1; # Command terminated
  } else {
    return 0 if $TimedOut || $PipeReturn; # Command failed to exit w'success

    # It all worked, so now add everything back into the message.
    #print STDERR "Dir is \"$dir\" and tnefname is \"$tnefname\"\n";

    unless (MailScanner::Config::Value('replacetnef',$message) =~ /[12]/) {
      # Just need to move all the unpacked files into the main attachments dir
      my $dirh = new DirHandle "$unpackdir";
      return 0 unless defined $dirh;
      while (defined(my $unpacked = $dirh->read)) {
        next unless -f "$unpackdir/$unpacked";
        # Add a 't' to the safename to mark it as a tnef member.
        my $safe = $message->MakeNameSafe('t'.$unpacked, $dir);
        # This will cause big problems as $safe has a type, and shouldn't!
        $message->{file2parent}{$safe} = $tnefname;
        my $name1 = "$unpackdir/$unpacked";
        $name1 =~ /(.*)/;
        $name1 = $1;
        my $name2 = "$dir/$safe";
        $name2 =~ /(.*)/;
        $name2 = $1;
        rename $name1, $name2;
        # JKF 20090421 CHMOD, then CHOWN and CHGRP it if necessary.
        chmod $perms, $name2;
        chown $owner, $group, $name2 if $change;
        # So let's remove the type indicator from $safe and store that too :)
        $safe =~ s#^(.*/)([^/])([^/]+)$#$1$3#; # I assert $2 will equal 't'.
        $message->{file2parent}{$safe} = $tnefname;
      }
      # The following may result in a warning from a virus scanner that
      # tries to lstat the directory, but it was empty so it can be ignored.
      rmdir "$unpackdir"; # Directory should be empty now
      return 1;
    }
    #print STDERR "In TNEF External Decoder\n";

    my $dirh = new DirHandle "$unpackdir";
    return 0 unless defined $dirh;
    my($type, $encoding);
    $message->{entity}->make_multipart;
    my($safename, @replacements, $unpacked);
    while (defined($unpacked = $dirh->read)) {
      #print STDERR "Directory entry is \"$unpacked\" in \"$unpackdir\"\n";
      next unless -f "$unpackdir/$unpacked";
      # Add a 't' to the safename to mark it as a tnef member.
      $safename = $message->MakeNameSafe('t'.$unpacked, $dir);
      if (/^msg[\d-]+\.txt$/) {
        ($type, $encoding) = ("text/plain", "8bit");
      } else {
        ($type, $encoding) = ("application/octet-stream", "base64");
      }
      #print STDERR "Renaming '$unpackdir/$unpacked' to '$dir/$safename'\n";
      my $oldname = "$unpackdir/$unpacked";
      my $newname = "$dir/$safename";
      $oldname =~ /^(.*)$/;
      $oldname = $1;
      $newname =~ /^(.*)$/;
      $newname = $1;
      rename $oldname, $newname;
      #rename "$unpackdir/$unpacked", "$dir/$safename";
      # JKF 20090421 CHMOD, then CHOWN and CHGRP it if necessary.
      chmod $perms, $newname;
      #chmod $perms, "$dir/$safename";
      chown $owner, $group, $newname if $change;
      #chown $owner, $group, "$dir/$safename" if $change;
      # The only file that ever existed in the message structure is the safename
      $message->{file2parent}{substr($safename,1)} = $tnefname;
      $message->{file2parent}{$safename} = $tnefname;
      push @replacements, $safename;
      $message->{entity}->attach(Type => $type,
                                 Encoding => $encoding,
                                 Disposition => "attachment",
                                 # Use original name: $safename,
                                 Filename => $unpacked,
                                 Path => "$dir/$safename");
    }
    $message->{bodymodified} = 1;
    $message->{foundtnefattachments} = 1;
    undef $dirh;
    # The following may result in a warning from a virus scanner that
    # tries to lstat the directory, but it was empty so it can be ignored.
    rmdir "$unpackdir"; # Directory should be empty now
    #$message->{entity}->dump_skeleton();

    MailScanner::Log::InfoLog("Message %s added TNEF contents %s",
                              $message->{id}, join(',', @replacements))
      if @replacements;

    return 1; # Command succeded and terminated
  }
}

1;

