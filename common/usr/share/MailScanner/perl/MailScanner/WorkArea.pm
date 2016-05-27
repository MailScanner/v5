#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: WorkArea.pm 5002 2010-02-11 14:58:04Z sysjkf $
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

package MailScanner::WorkArea;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use DirHandle;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use Cwd 'abs_path';

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5002 $, 10;

#
# Attributes:
# $dir			Work area directory for this child process
# $uid                  set by new The UID to change files to
# $gid                  set by new The GID to change files to
# $changeowner          set by new Should I try to chown the files at all?
# $fileumask            set by new Umask to use before creating files
# $dirumask             set by new Umask to use before mkdir 0777;
#

sub new {
  my $type = shift;
  my %params = @_;
  my $this = {};

  # Work out the uid and gid they want to use for the quarantine dir
  my($currentuid, $currentgid) = ($<, $();
  my($destuid, $destuname, $destgid, $destgname);
  $destuname = MailScanner::Config::Value('workuser') ||
               MailScanner::Config::Value('runasuser');
  $destgname = MailScanner::Config::Value('workgroup') ||
               MailScanner::Config::Value('runasgroup');
  $this->{changeowner} = 0;
  if ($destuname ne "" || $destgname ne "") {
    $destuid = $destuname?getpwnam($destuname):0;
    $destgid = $destgname?getgrnam($destgname):0;
    $this->{gid} = $destgid if $destgid != $currentgid;
    $this->{uid} = $destuid if $destuid != $currentuid;
  } else {
    $destuid = 0;
    $destgid = 0;
    $this->{gid} = 0;
    $this->{uid} = 0;
  }

  # Create a test file to try with chown
  my($testfn, $testfh, $worked);
  #MailScanner::Config::Value('lockfiledir') || '/var/spool/MailScanner/incoming/Locks';
  ($testfh, $testfn) = tempfile('MS.ownertest.XXXXXX', DIR => '/tmp')
    or MailScanner::Log::WarnLog('Could not test file ownership abilities on %s, please delete the file', $testfn);
  print $testfh "Testing file owner and group permissions for MailScanner\n";
  $testfh->close;

  # Now test the changes to see if we can do them
  my($changeuid, $changegid);
  if ($destgid != $currentgid) {
    $worked = chown $currentuid, $destgid, $testfn;
    if ($worked) {
      #print STDERR "Can change the GID of the quarantine\n";
      $changegid = 1;
    }
  } else {
    $changegid = 0;
  }
  if ($destuid != $currentuid) {
    $worked = chown $destuid, $destgid, $testfn;
    if ($worked) {
      #print STDERR "Can change the UID of the quarantine\n";
      $changeuid = 1;
    }
  } else {
    $changeuid = 0;
  }
  unlink $testfn;

  # Finally store the results
  $this->{uid} = $currentuid unless $changeuid;
  $this->{gid} = $currentgid unless $changegid;
  $this->{changeowner} = 1 if $changeuid || $changegid;

  # Now to work out the new umask
  # Default is 0600 for files, which gives 0700 for directories
  my($perms, $dirumask, $fileumask);
  $perms = MailScanner::Config::Value('workperms') || '0660';
  $perms = sprintf "0%lo", $perms unless $perms =~ /^0/; # Make it octal
  $dirumask = $perms;
  $dirumask =~ s/[1-7]/$&|1/ge; # If they want r or w give them x too
  $this->{dirumask}  = oct($dirumask) ^ 0777;
  $fileumask = $perms;
  $this->{fileumask} = oct($fileumask) ^ 0777;
  #print STDERR sprintf("File Umask = 0%lo\n", $this->{fileumask});
  #print STDERR sprintf("Dir  Umask = 0%lo\n", $this->{dirumask});


  my $parentdir = MailScanner::Config::Value('incomingworkdir');
  MailScanner::Log::DieLog("No Incoming Work Dir defined") unless $parentdir;
  MailScanner::Log::DieLog("Incoming Work Dir does not exist")
    unless -d $parentdir;
  my $realparentdir = abs_path($parentdir);
  if ($realparentdir ne $parentdir) {
    MailScanner::Log::WarnLog("Your \"Incoming Work Directory\" should be specified as an absolute path, not including any links. But I will work okay anyway.");
    $parentdir = $realparentdir;
  }

  #untaint
  $parentdir =~ m|(.*)|;
  $parentdir = $1;

  my $childdir  = "$parentdir/$$";

  #print STDERR "Child work dir is $childdir\n";

  # Make it if necessary
  umask $this->{dirumask};
  mkdir($parentdir, 0777) unless -d $parentdir;
  chown $this->{uid}, $this->{gid}, $parentdir if $this->{changeowner};
  unless (-d $childdir) {
    mkdir($childdir,  0777)
      or MailScanner::Log::DieLog("Cannot create temporary Work Dir %s. " .
                                  "Are the permissions and ownership of %s " .
                                  "correct?", $childdir, $parentdir);
    chown $this->{uid}, $this->{gid}, $childdir if $this->{changeowner};
  }
  umask 0077; # Protect ourselves again

  $this->{dir} = $childdir;

  return bless $this, $type;
}


# Build the tree of incoming messages, including the headers file for each one.
# The dirs go into the var/incoming dir, with the header files in there too.

sub BuildInDirs {
  my $this = shift;
  my $batch = shift;

  my($id, @idlist, $dircounter);
  my $dir = $this->{dir};
  @idlist = keys %{$batch->{messages}};
  $dircounter = 0;

  #chdir $IncomingDir or MailScanner::Log::DieLog("Cannot chdir to $IncomingDir, %s", $!);
  umask $this->{dirumask};
  foreach $id (@idlist) {
    next if $batch->{messages}{$id}->{deleted};
    mkdir "$dir/$id", 0777
      or MailScanner::Log::DieLog("Cannot mkdir %s/%s, %s", $dir, $id, $!);
    chown $this->{uid}, $this->{gid}, "$dir/$id" if $this->{changeowner};
    $dircounter++;
  }
  umask 0077;
  MailScanner::Log::DebugLog('Created attachment dirs for %d messages',
                             $dircounter);
}


# Destructor. Clears out the entire work area, including the process-
# specific directory. Used when a worker process is dying of old age
sub Destroy {
  my $this = shift;

  #print STDERR "About to destroy working area at " . $this->{dir} . "\n";
  unless(chdir $this->{dir} . "/..") {
    warn "Could not get to parent of incoming work directory";
    return;
  }

  # Delete all of it. Should get "rm" from autoconf.
  #system($global::rm . " -rf \"" . $this->{dir} . "\"");
  rmtree($this->{dir}, 0, 1);

  #print STDERR "Working area destroyed.\n";
}

# Clean up the whole work area, or just the passed in list of ids.
# To ensure we don't delete our current directory, get up to / first.
sub Clear {
  my $this = shift;
  my($Idlist) = @_;

  chdir '/';

  if ($Idlist) {
    $this->ClearIds($Idlist);
  } else {
    $this->ClearAll();
  }
}


# Clean up the whole of my work area
sub ClearAll {
  my $this = shift;
  my($f, $dirhandle, $dir, @ToDelete);

  #MailScanner::Log::InfoLog("Clearing temporary work area.");

  $dir = $this->{dir};
  #print STDERR "ClearAll: dir = $dir\n";
  chdir $dir or MailScanner::Log::DieLog("Cannot chdir to %s, %s", $dir, $!);
  $dirhandle = new DirHandle;
  $dirhandle->open('.')
    or MailScanner::Log::DieLog("Cannot read workarea dir $dir");

  # Clean up the whole thing
  while($f = $dirhandle->read()) {
    #print STDERR "Studying \"$f\"\n";
    next if $f =~ /^\./;
    # Needs untaint:
    $f =~ /([-.\w]+\.(?:message|header))$/ and unlink "$1";
    # And delete core files
    $f =~ /^core$/ and unlink "core";
    # Also needs untaint... sledgehammer. nut.
    $f =~ /(.*)/;
    push @ToDelete, $1 if -d "$1";
  }
  $dirhandle->close();

  ## Now delete the directories in @ToDelete in batches of 20
  #my(@ThisBatch);
  #while(@ToDelete) {
  #  @ThisBatch = splice @ToDelete, $[, 20;
  #  system($global::rm, "-rf", @ThisBatch);
  #}
  rmtree(\@ToDelete, 0, 1) if @ToDelete;

  #print STDERR "Finished ClearAll\n";
}


# Clean up the supplied list of messages from the work area.
# Takes a ref to a list of ID's, not a straight list.
sub ClearIds {
  my $this = shift;
  my($IdList) = @_;

  my($f, $dir);

  #MailScanner::Log::InfoLog("Partially clearing temporary work area.");

  $dir = $this->{dir};
  #print STDERR "ClearAll: dir = $dir\n";
  chdir $dir or MailScanner::Log::DieLog("Cannot chdir to %s, %s", $dir, $!);

  # Also delete any core files in the work dir
  push @$IdList, 'core';

  ## Now delete the directories in @IdList in batches of 20
  #my(@ThisBatch);
  #while(@$IdList) {
  #  @ThisBatch = splice @$IdList, $[, 20;
  #  system($global::rm . " -rf " . join(' ', @ThisBatch));
  #}
  rmtree($IdList, 0, 1);
}

sub DeleteFile {
  my $this = shift;
  my($message, $attach) = @_;
  my $tmp1 = $this->{dir} . '/' . $message->{id} . '/' . $attach;
  $tmp1 =~ /(.*)/;
  $tmp1 = $1;
  unlink $tmp1;
}


# Change current directory to the one containing the attachments
# for the message we are passed.
sub ChangeToMessage {
  my $this = shift;
  my $message = shift;

  my $dest = $this->{dir} . '/' . $message->{id};
  chdir $dest
    or MailScanner::Log::WarnLog("Cannot chdir to %s, %s", $dest, $!);
}


# Return true if the attachment file for this message and attachment name
# exists.
sub FileExists {
  my $this = shift;
  my($message, $attachment) = @_;

  return 1 if -f $this->{dir} . '/' . $message->{id} . '/' . $attachment;
  return 0;
}


1;
