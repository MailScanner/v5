#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#

package MailScanner::CustomConfig;

use DirHandle;
use File::Temp qw(tempfile tempdir);

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5102 $, 10;

#
# Usage instructions:
# In MailScanner.conf set
#
# Inline Text Signature = &InlineTextSignature
# Inline HTML Signature = &InlineHTMLSignature
# Random Signatures = <list of names of files and directories or a ruleset>
#
# Note: If you use a ruleset for "Random Signatures" then the filename must
#       end in ".rule" or ".rules".
#
# Installation Instructions:
# 1. Copy this file into /usr/share/MailScanner/MailScanner/CustomFunctions/
#
# 2. In /usr/share/MailScanner/MailScanner/ConfigDefs.pl you need to add
# RandomSignatures
# on a line on its own at the very end of the file.
#

my $LastMessage = undef;
my $SigTxt = "";
my $SigHTML = "";
my $TempDir = "";

sub InitInlineTextSignature {
  # No initialisation needs doing here at all.
  MailScanner::Log::InfoLog("Initialising InlineTextSignature");

  $LastMessage = undef;
  $SigTxt = "";
  $SigHTML = "";
  #$TempDir = "/tmp/SignRandom.$$";
  my($tmpfh, $tmpfile) = tempfile("SignRandom.XXXXXX", TMPDIR => 1, UNLINK => 0);
  $TempDir = $tmpfile;
}

sub InitInlineHTMLSignature {
  # No initialisation needs doing here at all.
  MailScanner::Log::InfoLog("Initialising InlineHTMLSignature");

  $LastMessage = undef;
  $SigTxt = "";
  $SigHTML = "";
  #$TempDir = "/tmp/SignRandom.$$";
  $TempDir = "/tmp/SignRandom.$$";
  my($tmpfh, $tmpfile) = tempfile("SignRandom.XXXXXX", TMPDIR => 1, UNLINK => 0);
  $TempDir = $tmpfile;
}

sub EndInlineTextSignature {
  # No shutdown code needed here at all.
  MailScanner::Log::InfoLog("Ending InlineTextSignature");
}

sub EndInlineHTMLSignature {
  # No shutdown code needed here at all.
  MailScanner::Log::InfoLog("Ending InlineHTMLSignature");
}


# Read the list of all the signatures for this message, pick one at
# random, and store the Txt and HTML filenames of it.
sub FindRandomSig {
  my($message) = @_;

  my(@dirs, $limit, $random, @filelist, $dir, $entry);
  my $dh = new DirHandle;
  @filelist = undef;

  #print STDERR "Finding random sig for $message\n";

  @dirs = split(/[\s,]+/, MailScanner::Config::Value('randomsignatures',
                                                     $message));
  #print STDERR "Directories are : " . join(',',@dirs) . "\n";
  foreach $dir (@dirs) {
    MailScanner::Log::WarnLog("Random signature file/dir %s does not exist",
      $dir), next unless -e $dir; # File/Directory must exist
    MailScanner::Log::WarnLog("Random signature file/dir %s cannot be read",
      $dir), next unless -r $dir;
    # If the directory is actually a file, just add it to the list
    push(@filelist, $dir), next if -f $dir;
    # $dir exists, is readable and is probably a directory
    MailScanner::Log::WarnLog("Random signature file/dir %s must be a " .
      "file or directory", $dir), next unless -d $dir;
    # $dir is a directory. So open it and read the contents.
    $dh->open($dir) or MailScanner::Log::WarnLog("Attempt to open %s failed",
                                                 $dir);
    #print STDERR "FindRandomSig: Processing $dir\n";
    while ($entry = $dh->read) {
      # Ignore dot files and HTML files
      push @filelist, "$dir/$entry"
        unless $entry =~ /^\./ || $entry =~ /html?/i;
      #print STDERR "Pushed $dir/$entry onto the list\n";
    }
    $dh->close;
  }

  # We now have a list of non-html files
  #print STDERR "We have a list of " . $#filelist . " filenames\n";
  $random = int(rand(scalar @filelist));
  #print STDERR "Random number is $random\n";

  $SigTxt = $filelist[$random];
  $SigHTML = $filelist[$random];
  $SigHTML =~ s/([^\/]+)te?xt([^\/]*)$/$1html$2/gi;
  $LastMessage = $message; # So we know we have already calculated this

  #print STDERR "Random Text Signature = $SigTxt\n";
  #print STDERR "Random HTML Signature = $SigHTML\n";
}

# Find a random TXT signature if we haven't already worked one out.
# Return it
sub InlineTextSignature {
  my($message) = @_;

  return "/dev/null" unless $message;

  #print STDERR "Finding InlineTxtSig for $message\n";

  # Find a new random signature pair if we haven't got a matching pair
  FindRandomSig($message) unless $message eq $LastMessage;
  
  return $SigTxt;
}

# Find a random HTML signature if we haven't already worked one out.
# Return it
sub InlineHTMLSignature {
  my($message) = @_;

  return "/dev/null" unless $message;

  #print STDERR "Finding InlineHTMLSig for $message\n";

  # Find a new random signature pair if we haven't got a matching pair
  FindRandomSig($message) unless $message eq $LastMessage;
  
  return $SigHTML;
}

1;

