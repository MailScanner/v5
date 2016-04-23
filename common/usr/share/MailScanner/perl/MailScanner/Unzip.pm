#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: Unzip.pm 4287 2008-01-31 11:56:37Z sysjkf $
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

package MailScanner::Unzip;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use DirHandle;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 4287 $, 10;

# Attributes are
#

# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  #$this->{dir} = shift;

  bless $this, $type;
  return $this;
}


sub UnpackZipMembers {
  my($message, $attachdir) = @_;

  my($file, $parent, $member, %memberlist, %membercount);
  my($memberlist, $zipmember);

  my $MaxMembersPerArchive = MailScanner::Config::Value('unzipmaxmembers',
                                                        $message);
  return unless $MaxMembersPerArchive > 0;
  my $MaxMemberSize = MailScanner::Config::Value('unzipmaxsize', $message);
  return unless $MaxMemberSize > 0;
  my $FilenameList = MailScanner::Config::Value('unzipmembers', $message);
  return unless $FilenameList;

  while (($file,$parent) = each %{$message->{file2parent}}) {
    #print STDERR "Looking at zip member $file, parent $parent\n";
    next if $parent =~ /(.winmail\d*\.dat\d*)/i; # Skip TNEF members
    next if $parent eq ""; # Skip attachments
    next if $message->{file2parent}{$parent}; # Skip nested files
    next unless -f "$attachdir/$file"; # Skip files that don't exist

    # Build a list of the number of members in each zip archive,
    # as we have a maximum number for each zip archive.
    #print STDERR "Zip member $file is an archive member\n";
    $memberlist{$parent} .= "\0$file";
    $membercount{$parent}++;
  }

  foreach $member (keys %membercount) {
    if ($membercount{$member} > $MaxMembersPerArchive) {
      #print STDERR "$member has too many children\n";
      delete $memberlist{$member};
      delete $membercount{$member};
    }
  }

  # Turn the $FilenameList of filename patterns (including * wildcards)
  # into a regexp of all the filename patterns we are looking for.
  my $FilesWeWant = '.*';
  my $ExtensionList = MailScanner::Config::Value('unzipmembers', $message);
  if ($ExtensionList) {
    my @regexps;
    foreach (split(" ", $ExtensionList)) {
      next unless $_;
      s/[^0-9a-z_-]/\\$&/ig; # Quote every non-alnum
      s/\\\*/.*/g; # Unquote any '*' characters as they map to .*
      push @regexps, $_;
    }
    $FilesWeWant = join('|',@regexps);
  }

  # Loop through each member of each zip file to add them to the message
  my($zipname, $memberlist, $unsafemember, $safemember);
  while (($zipname,$memberlist) = each %memberlist) {
    next unless $memberlist;
    #print STDERR "Memberlist = $memberlist\n";
    foreach $unsafemember (split(/\0+/, $memberlist)) {
      #print STDERR "Looking at \"$unsafemember\" to add to the message?\n";
      next if $unsafemember eq "";
      next unless $unsafemember =~ /$FilesWeWant/i;
      next unless -f "$attachdir/$unsafemember" &&
                  -s "$attachdir/$unsafemember" < $MaxMemberSize;
      #print STDERR "Adding $unsafemember($zipname) to the message\n";

      # Add $unsafemember to the message
      $safemember = $message->{file2safefile}{substr($unsafemember,1)};
      #print STDERR "Safe member name is $safemember\n";
      next unless $safemember;

      $message->{entity}->make_multipart;
      # The only file that ever existed in message structure is the safename.
      # Trim off the leading type indicator, as we're storing unsafe filename.
      $message->{file2parent}{substr($unsafemember,1)} = $zipname;
      $message->{entity}->attach(Type =>
                        MailScanner::Config::Value('unzipmimetype', $message),
                                 Encoding => "Base64",
                                 Disposition => "attachment",
                                 Filename => substr($unsafemember,1),
                                 Path => "$attachdir/$safemember");
      $message->{bodymodified} = 1;

      MailScanner::Log::InfoLog("Message %s added Archived file '%s/%s'" .
                                " to message as %s",
                                $message->{id},
                                $attachdir, substr($unsafemember, 1),
                                substr($safemember, 1));
    }
  }
}

1;

