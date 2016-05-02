#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: SweepViruses.pm 5086 2011-03-16 19:37:02Z sysjkf $
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

package MailScanner::SweepViruses;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use POSIX;
use DirHandle;
use IO::Socket::INET;
use IO::Socket::UNIX;

use vars qw($VERSION $ScannerPID);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5086 $, 10;

# Locking definitions for flock() which is used to lock the Lock file
my($LOCK_SH) = 1;
my($LOCK_EX) = 2;
my($LOCK_NB) = 4;
my($LOCK_UN) = 8;

# Sophos SAVI Library object and ide directory modification time
my($SAVI, $SAVIidedirmtime, $SAVIlibdirmtime, $SAVIinuse, %SAVIwatchfiles);
$SAVIidedirmtime = 0;
$SAVIlibdirmtime = 0;
$SAVIinuse       = 0;
%SAVIwatchfiles  = ();
# ClamAV Module object and library directory modification time
my($Clam, $Claminuse, %Clamwatchfiles);
$Claminuse       = 0;
%Clamwatchfiles  = ();
# So we can kill virus scanners when we are HUPped
$ScannerPID = 0;
my $scannerlist = "";

#
# Virus scanner definitions table
#
my (
    $S_NONE,         # Not present
    $S_UNSUPPORTED,  # Present but you're on your own
    $S_ALPHA,        # Present but not tested -- we hope it works!
    $S_BETA,         # Present and tested to some degree -- we think it works!
    $S_SUPPORTED,    # People use this; it'd better work!
   ) = (0,1,2,3,4);

my %Scanners = (
  generic => {
    Name		=> 'Generic',
    Lock		=> 'genericBusy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '-disinfect',
    ScanOptions		=> '',
    InitParser		=> \&InitGenericParser,
    ProcessOutput	=> \&ProcessGenericOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_NONE,
  },
  sophossavi => {
    Name		=> 'SophosSAVI',
    Lock		=> 'sophosBusy.lock',
    # In next line, '-ss' makes it work nice and quietly
    CommonOptions	=> '',
    DisinfectOptions	=> '',
    ScanOptions		=> '',
    InitParser		=> \&InitSophosSAVIParser,
    ProcessOutput	=> \&ProcessSophosSAVIOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_NONE,
  },
  sophos => {
    Name		=> 'Sophos',
    Lock		=> 'sophosBusy.lock',
    # In next line, '-ss' makes it work nice and quietly
    CommonOptions	=> '-sc -f -all -rec -ss -archive -cab -loopback ' .
                           '--no-follow-symlinks --no-reset-atime -TNEF',
    DisinfectOptions	=> '-di',
    ScanOptions		=> '',
    InitParser		=> \&InitSophosParser,
    ProcessOutput	=> \&ProcessSophosOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "f-secure"	=> {
    Name		=> 'F-Secure',
    Lock		=> 'f-secureBusy.lock',
    CommonOptions	=> '--dumb --archive',
    DisinfectOptions	=> '--auto --disinf',
    ScanOptions		=> '',
    InitParser		=> \&InitFSecureParser,
    ProcessOutput	=> \&ProcessFSecureOutput,
    SupportScanning	=> $S_SUPPORTED,
    SupportDisinfect	=> $S_SUPPORTED,
  },
  "clamavmodule" => {
    Name                => 'ClamAVModule',
    Lock                => 'clamavBusy.lock',
    CommonOptions       => '',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitClamAVModParser,
    ProcessOutput       => \&ProcessClamAVModOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "clamd"  => {
    Name                => 'Clamd',
    Lock                => 'clamavBusy.lock',
    CommonOptions       => '',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitClamAVModParser,
    ProcessOutput       => \&ProcessClamAVModOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "clamav"  => {
    Name		=> 'ClamAV',
    Lock                => 'clamavBusy.lock',
    CommonOptions       => '-r --infected --stdout',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitClamAVParser,
    ProcessOutput       => \&ProcessClamAVOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "bitdefender"   => {
    Name		=> 'Bitdefender',
    Lock                => 'bitdefenderBusy.lock',
    CommonOptions       => '--arc --mail --all',
    DisinfectOptions    => '--disinfect',
    ScanOptions         => '',
    InitParser          => \&InitBitdefenderParser,
    ProcessOutput       => \&ProcessBitdefenderOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_SUPPORTED,
  },
  "avg"   => {
    Name                => 'Avg',
    Lock                => 'avgBusy.lock',
    CommonOptions       => '--arc', # Remove by Chris Richardson:  -ext=*',
    DisinfectOptions    => '',
    ScanOptions         => '',
    InitParser          => \&InitAvgParser,
    ProcessOutput       => \&ProcessAvgOutput,
    SupportScanning     => $S_SUPPORTED,
    SupportDisinfect    => $S_NONE,
  },
  "none"		=> {
    Name		=> 'None',
    Lock		=> 'NoneBusy.lock',
    CommonOptions	=> '',
    DisinfectOptions	=> '',
    ScanOptions		=> '',
    InitParser		=> \&NeverHappens,
    ProcessOutput	=> \&NeverHappens,
    SupportScanning	=> $S_NONE,
    SupportDisinfect	=> $S_NONE,
  },
);

# Initialise the Sophos SAVI library if we are using it.
sub initialise {
  my(@scanners);
  $scannerlist = MailScanner::Config::Value('virusscanners');

  # If they have not configured the list of virus scanners, then try to
  # use all the scanners they have installed, by using the same system
  # that ms-update-vs uses to locate them all.
  #print STDERR "Scanner list read from MailScanner.conf is \"$scannerlist\"\n";
  if ($scannerlist =~ /^\s*auto\s*$/i) {
    # If we have multiple clam types, then tend towards clamd
    my %installed = map { $_ => 1 } InstalledScanners();
    delete $installed{'clamavmodule'} if $installed{'clamavmodule'} &&
                                         $installed{'clamd'};
    delete $installed{'clamav'}       if $installed{'clamav'} &&
                                         ($installed{'clamd'} ||
                                          $installed{'clamavmodule'});
    $scannerlist = join(' ', keys %installed);
    MailScanner::Log::InfoLog("Auto: Found virus scanners: %s ", $scannerlist);
    if ($scannerlist =~ /^\s*$/) {
      MailScanner::Log::WarnLog("Warning: no virus scanners found via auto select");
      #print STDERR "No virus scanners found to be installed at all!\n";
      $scannerlist = "none";
    }
  }


  $scannerlist =~ tr/,//d;
  @scanners = split(" ", $scannerlist);
  # Import the SAVI code and initialise the SAVI library
  if (grep /^sophossavi$/, @scanners) {
    $SAVIinuse = 1;
    #print STDERR "SAVI in use\n";
    InitialiseSAVI();
  }
  # Import the ClamAV code and initialise the ClamAV library
  if (grep /^clamavmodule$/, @scanners) {
    $Claminuse = 1;
    #print STDERR "ClamAV Module in use\n";
    InitialiseClam();
  }

}

sub InitialiseClam {
  # Initialise ClamAV Module
  MailScanner::Log::DieLog("ClamAV Perl module not found")
    unless eval 'require Mail::ClamAV';

  my $ver = $Mail::ClamAV::VERSION + 0.0;
  MailScanner::Log::DieLog("ClamAV Perl module must be at least version 0.12" .
                           " and you only have version %.2f, and ClamAV must" .
                           " be at least version 0.80", $ver)
    unless $ver >= 0.12;

  $Clam = new Mail::ClamAV(Mail::ClamAV::retdbdir())
    or MailScanner::Log::DieLog("ClamAV Module ERROR:: Could not load " .
       "databases from %s", Mail::ClamAV::retdbdir());
  $Clam->buildtrie;
  # Impose limits
  $Clam->maxreclevel(MailScanner::Config::Value('clamavmaxreclevel'));
  $Clam->maxfiles   (MailScanner::Config::Value('clamavmaxfiles'));
  $Clam->maxfilesize(MailScanner::Config::Value('clamavmaxfilesize'));
  #0.93 $Clam->maxratio   (MailScanner::Config::Value('clamavmaxratio'));


  # Build the hash of the size of all the watch files
  my(@watchglobs, $glob, @filelist, $file, $filecount);
  @watchglobs = split(" ", MailScanner::Config::Value('clamwatchfiles'));
  $filecount = 0;
  foreach $glob (@watchglobs) {
    @filelist = map { m/(.*)/ } glob($glob);
    foreach $file (@filelist) {
      $Clamwatchfiles{$file} = -s $file;
      $filecount++;
    }
  }
  MailScanner::Log::DieLog("None of the files matched by the \"Monitors " .
    "For ClamAV Updates\" patterns exist!") unless $filecount>0;

  #MailScanner::Log::WarnLog("\"Allow Password-Protected Archives\" should be set to just yes or no when using clamavmodule virus scanner")
  #  unless MailScanner::Config::IsSimpleValue('allowpasszips');
}


sub InitialiseSAVI {
  # Initialise Sophos SAVI library
  MailScanner::Log::DieLog("SAVI Perl module not found, did you install it?")
    unless eval 'require SAVI';

  my $SAVIidedir = MailScanner::Config::Value('sophoside');
  $SAVIidedir = '/usr/local/Sophos/ide' unless $SAVIidedir;
  my $SAVIlibdir = MailScanner::Config::Value('sophoslib');
  $SAVIlibdir = '/usr/local/Sophos/lib' unless $SAVIlibdir;

  $ENV{'SAV_IDE'} = $SAVIidedir;
  print "INFO:: Meaningless output that goes nowhere, to keep SAVI happy\n";
  $SAVI = new SAVI();
  MailScanner::Log::DieLog("SophosSAVI ERROR:: initializing savi: %s (%s)",
                           SAVI->error_string($SAVI), $SAVI)
    unless ref $SAVI;
  my $version = $SAVI->version();
  MailScanner::Log::DieLog("SophosSAVI ERROR:: getting version: %s (%s)",
                           $SAVI->error_string($version), $version)
    unless ref $version;
  MailScanner::Log::InfoLog("SophosSAVI %s (engine %d.%d) recognizing " .
                            "%d viruses", $version->string, $version->major,
                            $version->minor, $version->count);
  my($ide,$idecount);
  $idecount = 0;
  foreach $ide ($version->ide_list) {
    #MailScanner::Log::InfoLog("SophosSAVI IDE %s released %s",
    #                          $ide->name, $ide->date);
    $idecount++;
  }
  MailScanner::Log::InfoLog("SophosSAVI using %d IDE files", $idecount);

  # I have removed "Mac" and "SafeMacDfHandling" from here as setting
  # them gives an error.
  my @options = qw(
      FullSweep DynamicDecompression FullMacroSweep OLE2Handling
      IgnoreTemplateBit VBA3Handling VBA5Handling OF95DecryptHandling
      HelpHandling DecompressVBA5 Emulation PEHandling ExcelFormulaHandling
      PowerPointMacroHandling PowerPointEmbeddedHandling ProjectHandling
      ZipDecompression ArjDecompression RarDecompression UueDecompression
      GZipDecompression TarDecompression CmzDecompression HqxDecompression
      MbinDecompression !LoopBackEnabled
      Lha SfxArchives MSCabinet TnefAttachmentHandling MSCompress
      !DeleteAllMacros Vbe !ExecFileDisinfection VisioFileHandling
      Mime ActiveMimeHandling !DelVBA5Project
      ScrapObjectHandling SrpStreamHandling Office2001Handling
      Upx PalmPilotHandling HqxDecompression
      Pdf Rtf Html Elf WordB OutlookExpress
    );
  my $error = $SAVI->set('MaxRecursionDepth', 30, 1);
  MailScanner::Log::DieLog("SophosSAVI ERROR:: setting MaxRecursionDepth:" .
                           " %s", $error) if defined $error;
  foreach (@options) {
    my $value = ($_ =~ s/^!//) ? 0 : 1;
    $error = $SAVI->set($_, $value);
    MailScanner::Log::WarnLog("SophosSAVI ERROR:: Setting %s: %s", $_, $error)
      if defined $error;
  }

  ## Store the last modified time of the SAVI lib directory, so we can check
  ## for major upgrades
  my(@statresults);
  #@statresults = stat($SAVIidedir);
  #$SAVIidedirmtime = $statresults[9] or
  # MailScanner::Log::WarnLog("Failed to read mtime of IDE dir %s",$SAVIidedir);
  @statresults = stat($SAVIlibdir);
  $SAVIlibdirmtime = $statresults[9] or
    MailScanner::Log::WarnLog("Failed to read mtime of lib dir %s",$SAVIlibdir);
  #MailScanner::Log::InfoLog("Watching modification date of %s and %s",
  #                          $SAVIidedir, $SAVIlibdir);

  # Build the hash of the size of all the watch files
  my(@watchglobs, $glob, @filelist, $file, $filecount);
  @watchglobs = split(" ", MailScanner::Config::Value('saviwatchfiles'));
  $filecount = 0;
  foreach $glob (@watchglobs) {
    @filelist = map { m/(.*)/ } glob($glob);
    foreach $file (@filelist) {
      $SAVIwatchfiles{$file} = -s $file;
      $filecount++;
    }
  }
  MailScanner::Log::DieLog("None of the files matched by the \"Monitors " .
    "For Sophos Updates\" patterns exist!") unless $filecount>0;
}

# Are there new Sophos IDE files?
# If so, abandon this child process altogether and start again.
# This is called from the main WorkForHours() loop
#
# If the lib directory has been updated, then a major Sophos update has
# happened. If the watch files have changed their size at all, or any
# of them have disappeared, then an IDE updated has happened.
# Normally just watch /u/l/S/ide/*.zip.
#
sub SAVIUpgraded {
  my(@result, $idemtime, $libmtime, $watch, $size);

  # If we aren't even using SAVI, then obviously we don't want to restart
  return 0 unless $SAVIinuse;

  #@result = stat(MailScanner::Config::Value('sophoside') ||
  #               '/usr/local/Sophos/ide');
  #$idemtime = $result[9];
  @result = stat(MailScanner::Config::Value('sophoslib') ||
  				  '/opt/sophos-av/lib/sav');
  #               '/usr/local/Sophos/lib');
  $libmtime = $result[9];

  #if ($idemtime != $SAVIidedirmtime || $libmtime != $SAVIlibdirmtime) {
  if ($libmtime != $SAVIlibdirmtime) {
    MailScanner::Log::InfoLog("Sophos library update detected, " .
                              "resetting SAVI");
    return 1;
  }

  while (($watch, $size) = each %SAVIwatchfiles) {
    if ($size != -s $watch) {
      MailScanner::Log::InfoLog("Sophos update of $watch detected, " .
                                "resetting SAVI");
      keys %SAVIwatchfiles; # Necessary line to reset each()
      return 1;
    }
  }

  # No update detected
  return 0;
}

# Have the ClamAV database files been modified? (changed size)
# If so, abandon this child process altogether and start again.
# This is called from the main WorkForHours() loop
#
sub ClamUpgraded {
  my($watch, $size);

  return 0 unless $Claminuse;

  while (($watch, $size) = each %Clamwatchfiles) {
    if ($size != -s $watch) {
      MailScanner::Log::InfoLog("ClamAV update of $watch detected, " .
                                "resetting ClamAV Module");
      keys %Clamwatchfiles; # Necessary line to reset each()
      return 1;
    }
  }

  # No update detected
  return 0;
}



# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  #$this->{dir} = shift;

  bless $this, $type;
  return $this;
}

# Do all the commercial virus checking in here.
# If 2nd parameter is "disinfect", then we are disinfecting not scanning.
sub ScanBatch {
  my $batch = shift;
  my $ScanType = shift;

  my($NumInfections, $success, $id, $BaseDir);
  my(%Types, %Reports);

  $NumInfections = 0;
  $BaseDir = $global::MS->{work}->{dir};

  chdir $BaseDir or die "Cannot chdir $BaseDir for virus scanning, $!";

  #print STDERR (($ScanType =~ /dis/i)?"Disinfecting":"Scanning") . " using ".
  #             "commercial virus scanners\n";
  $success = TryCommercial($batch, '.', $BaseDir, \%Reports, \%Types,
                           \$NumInfections, $ScanType);
  #print STDERR "Found $NumInfections infections\n";
  if ($success eq 'ScAnNeRfAiLeD') {
    # Delete all the messages from this batch as if we weren't scanning
    # them, and reject the batch.
    MailScanner::Log::WarnLog("Virus Scanning: No virus scanners worked, so message batch was abandoned and retried!");
    $batch->DropBatch();
    return 1;
  } 
  unless ($success) {
    # Virus checking the whole batch of messages timed out, so now check them
    # one at a time to find the one with the DoS attack in it.
    my $BaseDirH = new DirHandle;
    MailScanner::Log::WarnLog("Virus Scanning: Denial Of Service attack " .
                              "detected!");
    $BaseDirH->open('.') 
      or MailScanner::Log::DieLog("Can't open directory for scanning 1 message, $!");
    while(defined($id = $BaseDirH->read())) {
      next unless -d "$id";   # Only check directories
      next if $id =~ /^\.+$/; # Don't check myself or my parent
      $id =~ /^(.*)$/;
      $id = $1;
      next unless MailScanner::Config::Value('virusscan',$batch->{messages}{id}) =~ /1/;
      # The "./" is important as it gets the path right for parser code
      $success = TryCommercial($batch, "./$id", $BaseDir, \%Reports,
                               \%Types, \$NumInfections, $ScanType);
      # If none of the scanners worked, then we need to abandon this batch
      if ($success eq 'ScAnNeRfAiLeD') {
        # Delete all the messages from this batch as if we weren't scanning
        # them, and reject the batch.
        MailScanner::Log::WarnLog("Virus Scanning: No virus scanners worked, so message batch was abandoned and retried!");
        $batch->DropBatch();
        last;
      } 

      unless ($success) {
        # We have found the DoS attack message
        $Reports{"$id"}{""} .=
          MailScanner::Config::LanguageValue($batch->{messages}{$id},
                                             'dosattack') . "\n";
        $Types{"$id"}{""}   .= "d";
        MailScanner::Log::WarnLog("Virus Scanning: Denial Of Service " .
                                  "attack is in message %s", $id);
        # No way here of incrementing the "otherproblems" counter. Ho hum.
      }
    }
    $BaseDirH->close();
  }

  # Add all the %Reports and %Types to the message batch fields
  MergeReports(\%Reports, \%Types, $batch);

  # Return value is the number of infections we found
  #print STDERR "Found $NumInfections infections!\n";
  return $NumInfections;
}


# Merge all the virus reports and types into the properties of the
# messages in the batch. Doing this separately saves me changing
# the code of all the parsers to support the new OO structure.
# If we have at least 1 report for a message, and the "silent viruses" list
# includes the special keyword "All-Viruses" then mark the message as silent
# right now.
sub MergeReports {
  my($Reports, $Types, $batch) = @_;

  my($id, $reports, $attachment, $text);
  my($cachedid, $cachedsilentflag);
  my(%seenbefore);

  # Let's do all the reports first...
  $cachedid = 'uninitialised';
  while (($id, $reports) = each %$Reports) {
    #print STDERR "Report merging for \"$id\" and \"$reports\"\n";
    next unless $id && $reports;
    my $message = $batch->{messages}{"$id"};
    # Skip this message if we didn't actually want it to be scanned.
    next unless MailScanner::Config::Value('virusscan', $message) =~ /1/;
    #print STDERR "Message is $message\n";
    $message->{virusinfected} = 1;

    # If the cached message id matches the current one, we are working on
    # the same message as last time, so don't re-fetch the silent viruses
    # list for this message.
    if ($cachedid ne $id) {
      my $silentlist = ' ' . MailScanner::Config::Value('silentviruses',
                       $message) . ' ';
      $cachedsilentflag = ($silentlist =~ / all-viruses /i)?1:0;
      $cachedid = $id;
    }
    # We can't be here unless there was a virus report for this message
    $message->{silent} = 1 if $cachedsilentflag;

    while (($attachment, $text) = each %$reports) {
      #print STDERR "\tattachment \"$attachment\" has text \"$text\"\n";
      #print STDERR "\tEntity of \"$attachment\" is \"" . $message->{file2entity} . "\"\n";
      next unless $text;

      # Sanitise the reports a bit
      $text =~ s/\s{20,}/ /g;
      $message->{virusreports}{"$attachment"} .= $text;
    }
    unless ($seenbefore{$id}) {
      MailScanner::Log::NoticeLog("Infected message %s came from %s",
                                $id, $message->{clientip});
      $seenbefore{$id} = 1;
    }
  }

  # And then all the report types...
  while (($id, $reports) = each %$Types) {
    next unless $id && $reports;
    my $message = $batch->{messages}{"$id"};
    while (($attachment, $text) = each %$reports) {
      next unless $text;
      $message->{virustypes}{"$attachment"} .= $text;
    }
  }
}


# Try all the installed commercial virus scanners
# We are passed the directory to start scanning from,
#               the message batch we are scanning,
#               a ref to the infections counter.
# $ScanType can be one of "scan", "rescan", "disinfect".
sub TryCommercial {
  my($batch, $dir, $BaseDir, $Reports, $Types, $rCounter, $ScanType) = @_;

  my($scanner, @scanners, $disinfect, $result, $counter);
  my($logtitle, $OneScannerWorked);

  # If we aren't virus scanning *anything* then don't call the scanner
  return 1 if MailScanner::Config::IsSimpleValue('virusscan') &&
              !MailScanner::Config::Value('virusscan');

  # $scannerlist is now a global for this file. If it was set to "auto"
  # then I will have searched for all the scanners that appear to be
  # installed. So by the time we get here, it should never be "auto" either.
  # Unless of course they really have no scanners installed at all!
  #$scannerlist = MailScanner::Config::Value('virusscanners');
  $scannerlist =~ tr/,//d;
  $scannerlist = "none" unless $scannerlist; # Catch empty setting
  @scanners = split(" ", $scannerlist);
  $counter = 0;

  # Change actions and outputs depending on what we are trying to do
  $disinfect = 0;
  $disinfect = 1 if $ScanType !~ /scan/i;
  $logtitle = "Virus Scanning";
  $logtitle = "Virus Rescanning"  if $ScanType =~ /re/i;  # Rescanning
  $logtitle = "Disinfection" if $ScanType =~ /dis/i; # Disinfection

  # Work out the regexp for matching the spam-infected messages
  # This is given by the user as a space-separated list of simple wildcard
  # strings. Must split it up, escape everything, spot the * characters
  # and join them together into one big regexp. Use lots of tricks from the
  # Phishing regexp generator I wrote a month or two back.
  my $spaminfsetting = MailScanner::Config::Value('spaminfected');
  #$spaminfsetting = '*UNOFFICIAL HTML/* Sanesecurity.*'; # Test data
  $spaminfsetting =~ s/\s+/ /g; # Squash multiple spaces
  $spaminfsetting =~ s/^\s+//; # Trim leading and
  $spaminfsetting =~ s/\s+$//; # trailing space.
  $spaminfsetting =~ s/\s/ /g; # All tabs to spaces
  $spaminfsetting =~ s/[^0-9a-z_ -]/\\$&/ig; # Quote every non-alnum except space.
  $spaminfsetting =~ s/\\\*/.*/g; # Unquote any '*' characters as they map to .*
  my @spaminfwords = split " ", $spaminfsetting;
  # Combine all the words into an "or" list in a fast regexp,
  # and anchor them all to the start and end of the string.
  my $spaminfre   = '(?:^\s*' . join('\s*$|^\s*', @spaminfwords) . '\s*$)';

  $OneScannerWorked = 0;
  foreach $scanner (@scanners) {
    my $r1Counter = 0;
    #print STDERR "Trying One Commercial: $scanner\n";
    $result = TryOneCommercial($scanner,
                               MailScanner::Config::ScannerCmds($scanner),
                               $batch, $dir, $BaseDir, $Reports, $Types,
                               \$r1Counter, $disinfect, $spaminfre);
    # If all the scanners failed, we flag it and abandon the batch.
    # If even just one of them worked, we carry on.
    if ($result ne 'ScAnNeRfAiLeD') {
      $OneScannerWorked = 1;
    }
    unless ($result) {
      MailScanner::Log::WarnLog("%s: Failed to complete, timed out", $scanner);
      return 0;
    }
    $counter += $result;
    MailScanner::Log::NoticeLog("%s: %s found %d infections", $logtitle,
                                $Scanners{$scanner}{Name}, $r1Counter)
      if $r1Counter;
    # Update the grand total of viruses found
    $$rCounter += $r1Counter;
  }

  # If none of the scanners worked, then reject this batch.
  if (!$OneScannerWorked) {
    return 'ScAnNeRfAiLeD';
  }

  return $counter;
}

# Try one of the commercial virus scanners
sub TryOneCommercial {
  my($scanner, $sweepcommandAndPath, $batch, $subdir, $BaseDir,
     $Reports, $Types, $rCounter, $disinfect, $spaminfre) = @_;

  my($sweepcommand, $instdir, $ReportScanner);
  my($rScanner, $VirusLock, $voptions, $Name);
  my($Counter, $TimedOut, $PipeReturn, $pid);
  my($ScannerFailed);

  MailScanner::Log::DieLog("Virus scanner \"%s\" not found " .
                           "in virus.scanners.conf file. Please check your " .
                           "spelling in \"Virus Scanners =\" line of " .
                           "MailScanner.conf", $scanner)
    if $sweepcommandAndPath eq "";

  # Split the sweepcommandAndPath into its 2 elements
  $sweepcommandAndPath =~ /^([^,\s]+)[,\s]+([^,\s]+)$/
    or MailScanner::Log::DieLog("Your virus.scanners.conf file does not " .
                                " have 3 words on each line. See if you " .
                                " have an old one left over by mistake.");
  ($sweepcommand, $instdir) = ($1, $2);

  MailScanner::Log::DieLog("Never heard of scanner '$scanner'!")
    unless $sweepcommand;

  $rScanner = $Scanners{$scanner};

  # November 2008: Always log the scanner name, strip it from the reports
  #                if the user doesn't want it.
  # If they want the scanner name, then set it to non-blank
  $Name = $rScanner->{"Name"}; # if MailScanner::Config::Value('showscanner');
  $ReportScanner = MailScanner::Config::Value('showscanner');

  if ($rScanner->{"SupportScanning"} == $S_NONE){
    MailScanner::Log::DebugLog("Scanning using scanner \"$scanner\" " .
                               "not supported; not scanning");
    return 1;
  }

  if ($disinfect && $rScanner->{"SupportDisinfect"} == $S_NONE){
    MailScanner::Log::DebugLog("Disinfection using scanner \"$scanner\" " .
                               "not supported; not disinfecting");
    return 1;
  }

  CheckCodeStatus($rScanner->{$disinfect?"SupportDisinfect":"SupportScanning"})
    or MailScanner::Log::DieLog("Bad return code from CheckCodeStatus - " .
                                "should it have quit?");

  $VirusLock = MailScanner::Config::Value('lockfiledir') . "/" .
               $rScanner->{"Lock"}; # lock file
  $voptions  = $rScanner->{"CommonOptions"}; # Set common command line options

  # Add the configured value for scanner time outs  to the command line
  # if the scanner is  Panda
  $voptions .= " -t:".MailScanner::Config::Value('virusscannertimeout')
  				if $rScanner->{"Name"} eq 'Panda';

  # Add command line options to "scan only", or to disinfect
  $voptions .= " " . $rScanner->{$disinfect?"DisinfectOptions":"ScanOptions"};
  &{$$rScanner{"InitParser"}}($BaseDir, $batch); # Initialise scanner-specific parser

  my $Lock = new FileHandle;
  my $Kid  = new FileHandle;
  my $pipe;

  # Check that the virus checker files aren't currently being updated,
  # and wait if they are.
  if (open($Lock, ">$VirusLock")) {
    print $Lock  "Virus check locked for " .
          ($disinfect?"disinfect":"scann") . "ing with $scanner $$\n";
  } else {
    #The lock file already exists, so just open for reading
    open($Lock, "<$VirusLock")
      or MailScanner::Log::WarnLog("Cannot lock $VirusLock, $!");
  }
  flock($Lock, $LOCK_SH);

  MailScanner::Log::DebugLog("Commencing " .
        ($disinfect?"disinfect":"scann") . "ing with $scanner...");

  $disinfect = 0 unless $disinfect; # Make sure it's not undef

  $TimedOut = 0;
  eval {
    $pipe = $disinfect?'|-':'-|';
    die "Can't fork: $!" unless defined($pid = open($Kid, $pipe));
    if ($pid) {
      # In the parent
      local $SIG{ALRM} = sub { $TimedOut = 1; die "Command Timed Out" };
      alarm MailScanner::Config::Value('virusscannertimeout');
      $ScannerPID = $pid;
      # Only process the output if we are scanning, not disinfecting
      if ($disinfect) {
        # Tell sweep to disinfect all files
        print $Kid "A\n" if $scanner eq 'sophos';
        #print STDERR "Disinfecting...\n";
      } else {
        my($ScannerOutput, $line);
        while(defined ($line = <$Kid>)) {
          # Note: this is a change in the spec for all the parsers
          if ($line =~ /^ScAnNeRfAiLeD/) {
            # The virus scanner failed for some reason, remove this batch
            $ScannerFailed = 1;
            last;
          }

          $ScannerOutput = &{$$rScanner{"ProcessOutput"}}($line, $Reports,
                                                     $Types, $BaseDir, $Name,
                                                     $spaminfre);
          #print STDERR "Processing line \"$_\" produced $Counter\n";
          if ($ScannerOutput eq 'ScAnNeRfAiLeD') {
            $ScannerFailed = 1;
            last;
          }
          $Counter += $ScannerOutput if $ScannerOutput > 0;
          #print STDERR "Counter = \"$Counter\"\n";

          # 20090730 Add support for spam-viruses, ie. spam reported as virus
          #print STDERR "ScannerOutput = \"$ScannerOutput\"\n";
          if ($ScannerOutput =~ s/^0\s+//) {
            # It's a spam-virus and the infection name for the spam report
            # is in $ScannerOutput
            $ScannerOutput =~ /^(\S+)\s+(\S+)\s*$/;
            my ($messageid, $report) = ($1, $2);
            #print STDERR "Found spam-virus: $messageid, $report\n";
            MailScanner::Log::WarnLog("Found spam based virus %s in %s",
                                      $report, $messageid);
            $batch->{messages}{"$messageid"}->{spamvirusreport} .= ', '
              if $batch->{"$messageid"}->{spamvirusreport};
            $batch->{messages}{"$messageid"}->{spamvirusreport} .= $report;
            #print STDERR "id=" . $batch->{messages}{"$messageid"}->{id} . "\n";
          }
        }

        # If they don't want the scanner name reported, strip the scanner name
        $line =~ s/^$Name: // unless $ReportScanner;
      }
      close $Kid;
      $PipeReturn = $?;
      $pid = 0; # 2.54
      alarm 0;
      # Workaround for bug in perl shipped with Solaris 9,
      # it doesn't unblock the SIGALRM after handling it.
      eval {
        my $unblockset = POSIX::SigSet->new(SIGALRM);
        sigprocmask(SIG_UNBLOCK, $unblockset)
          or die "Could not unblock alarm: $!\n";
      };
    } else {
      # In the child
      POSIX::setsid();
      if ($scanner eq 'sophossavi') {
        SophosSAVI($subdir, $disinfect);
        exit;
      } elsif ($scanner eq 'clamavmodule') {
        ClamAVModule($subdir, $disinfect, $batch);
        exit;
      } elsif ($scanner eq 'clamd') {
        ClamdScan($subdir, $disinfect, $batch);
        exit;
      } else {
        exec "$sweepcommand $instdir $voptions $subdir";
        MailScanner::Log::WarnLog("Cannot run commercial AV $scanner " .
                                  "(\"$sweepcommand\"): $!");
        exit 1;
      }
    }
  };
  alarm 0; # 2.53

  # Note to self: I only close the KID in the parent, not in the child.
  MailScanner::Log::DebugLog("Completed AV scan with $scanner");
  $ScannerPID = 0; # Not running a scanner any more

  # Catch failures other than the alarm
  MailScanner::Log::DieLog("Virus scanner failed with error: $@")
    if $@ and $@ !~ /Command Timed Out|[sS]yslog/;

  #print STDERR "pid = $pid and \@ = $@\n";

  # In which case any failures must be the alarm
  if ($@ or $pid>0) {
    # Kill the running child process
    my($i);
    kill -15, $pid;
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

  flock($Lock, $LOCK_UN);
  close $Lock;
  # Use the maximum value of all the numbers of viruses found by each of
  # the virus scanners. This should hopefully reflect the real number of
  # viruses in the messages, in the case where all of them spot something,
  # but only a subset spot more/all of the viruses.
  # Viruses = viruses or phishing attacks in the case of ClamAV.
  $$rCounter = $Counter if $Counter>$$rCounter; # Set up output value

  # If the virus scanner failed, bail out and tell the boss
  return 'ScAnNeRfAiLeD' if $ScannerFailed;

  # Return failure if the command timed out, otherwise return success
  MailScanner::Log::WarnLog("AV engine $scanner timed out") if $TimedOut;
  return 0 if $TimedOut;
  return 1;
}

# Use the ClamAV module (already initialised) to scan the contents of
# a directory. Outputs in a very simple format that ProcessClamAVModOutput()
# expects. 3 output fields separated by ":: ".
sub ClamAVModule {
  my($dirname, $disinfect, $messagebatch) = @_;

  my($dir, $child, $childname, $filename, $results, $virus);

  # Do we have an unrar on the path?
  my $unrar = MailScanner::Config::Value('unrarcommand');
  MailScanner::Log::WarnLog("Unrar command %s does not exist or is not " .
    "executable, please either install it or remove the setting from " .
    "MailScanner.conf", $unrar)
    unless $unrar eq "" || -x $unrar;
  my $haverar = 1 if $unrar && -x $unrar;

  $| = 1;
  $dir   = new DirHandle;
  $child = new DirHandle;

  $dir->open($dirname)
      or MailScanner::Log::DieLog("Cannot open directory %s for scanning, %s",
                                  $dirname, $!);

  # Find all the subdirectories
  while($childname = $dir->read()) {
    # Scan all the *.header and *.message files
    if (-f "$dirname/$childname") {
      my $tmpname = "$dirname/$childname";
      $tmpname =~ /^(.*)$/;
      $tmpname = $1;
      $results = $Clam->scan($tmpname,
                             Mail::ClamAV::CL_SCAN_STDOPT() |
                             Mail::ClamAV::CL_SCAN_ARCHIVE() |
                             Mail::ClamAV::CL_SCAN_PE() |
                             Mail::ClamAV::CL_SCAN_BLOCKBROKEN() |
                             Mail::ClamAV::CL_SCAN_OLE2());
                             #0.93 Mail::ClamAV::CL_SCAN_PHISHING_DOMAINLIST());
      $childname =~ s/\.(?:header|message)$//;
      unless ($results) {
        print "ERROR:: $results" . ":: $dirname/$childname/\n";
        next;
      }
      if ($results->virus) {
        print "INFECTED::";
        print " $results" . ":: $dirname/$childname/\n";
      } else {
        print "CLEAN:: :: $dirname/$childname/\n";
      }
      next;
    }
    #next unless -d "$dirname/$childname"; # Only search subdirs
    next if $childname eq '.' || $childname eq '..';

    # Now work through each subdirectory of attachments
    $child->open("$dirname/$childname")
      or MailScanner::Log::DieLog("Cannot open directory %s for scanning, %s",
                                  "$dirname/$childname", $!);

    # Scan all the files in the subdirectory
    # check to see if rar is available. If it is we don't want to
    # have clamav check for password protected since that has already
    # been done and will be reported correctly
    # if we are not allowing password protected archives and do not have rar
    # then have clamav check for password protected archives but it will
    # be reported as a virus (at least it will block passworded rar files)

    while($filename = $child->read()) {
      next unless -f "$dirname/$childname/$filename"; # Only check files
      #if (MailScanner::Config::Value('allowpasszips',
      #          $messagebatch->{messages}{$childname})) { # || $haverar) {
      my $tmpname = "$dirname/$childname/$filename";
      $tmpname =~ /^(.*)$/;
      $tmpname = $1;
        $results = $Clam->scan($tmpname,
                               Mail::ClamAV::CL_SCAN_STDOPT() |
                               Mail::ClamAV::CL_SCAN_ARCHIVE() |
                               Mail::ClamAV::CL_SCAN_PE() |
                               Mail::ClamAV::CL_SCAN_BLOCKBROKEN() |
                               Mail::ClamAV::CL_SCAN_OLE2());
                               #0.93 Mail::ClamAV::CL_SCAN_PHISHING_DOMAINLIST());
      #} else {
      #  $results = $Clam->scan("$dirname/$childname/$filename",
      #                         Mail::ClamAV::CL_SCAN_STDOPT() |
      #                         Mail::ClamAV::CL_SCAN_ARCHIVE() |
      #                         Mail::ClamAV::CL_SCAN_PE() |
      #                         Mail::ClamAV::CL_SCAN_BLOCKBROKEN() |
      #  # Let MS find these:  #Mail::ClamAV::CL_SCAN_BLOCKENCRYPTED() |
      #                         Mail::ClamAV::CL_SCAN_OLE2());
      #}

      unless ($results) {
        print "ERROR:: $results" . ":: $dirname/$childname/$filename\n";
        next;
      }
      if ($results->virus) {
        print "INFECTED::";
        print " $results" . ":: $dirname/$childname/$filename\n";
      } else {
        print "CLEAN:: :: $dirname/$childname/$filename\n";
      }
    }
    $child->close;
  }
  $dir->close;
}





# Use the Sophos SAVI library (already initialised) to scan the contents of
# a directory. Outputs in a very simple format that ProcessSophosSAVIOutput()
# expects. 3 output fields separated by ":: ".
sub SophosSAVI {
  my($dirname, $disinfect) = @_;

  my($dir, $child, $childname, $filename, $results, $virus);

  # Cannot disinfect yet
  #if ($disinfect) {
  #  # Enable the disinfection options
  #  ;
  #} else {
  #  # Disable the disinfection options
  #  ;
  #}

  $| = 1;
  $dir   = new DirHandle;
  $child = new DirHandle;

  $dir->open($dirname)
      or MailScanner::Log::DieLog("Cannot open directory %s for scanning, %s",
                                  $dirname, $!);

  # Find all the subdirectories
  while($childname = $dir->read()) {
    next unless -d "$dirname/$childname"; # Only search subdirs
    next if $childname eq '.' || $childname eq '..';

    my $tmpchild = "$dirname/$childname";
    $tmpchild =~ /^(.*)$/;
    $tmpchild = $1;
    $child->open($tmpchild)
      or MailScanner::Log::DieLog("Cannot open directory %s for scanning, %s",
                                  "$dirname/$childname", $!);

    # Scan all the files in the subdirectory
    while($filename = $child->read()) {
      next unless -f "$dirname/$childname/$filename"; # Only check files
      my $tmpfile = "$dirname/$childname/$filename";
      $tmpfile =~ /^(.*)$/;
      $tmpfile = $1;
      $results = $SAVI->scan($tmpfile);
      unless (ref $results) {
        print "ERROR:: " . $SAVI->error_string($results) . " ($results):: " .
              "$dirname/$childname/$filename\n";
        next;
      }
      if ($results->infected) {
        print "INFECTED::";
        foreach $virus ($results->viruses) {
          print " $virus";
        }
        print ":: $dirname/$childname/$filename\n";
      } else {
        print "CLEAN:: :: $dirname/$childname/$filename\n";
      }
    }
    $child->close;
  }
  $dir->close;
}

# Initialise any state variables the Generic output parser uses
sub InitGenericParser {
  ;
}

# Initialise any state variables the Sophos SAVI output parser uses
sub InitSophosSAVIParser {
  ;
}

# Initialise any state variables the Sophos output parser uses
sub InitSophosParser {
  ;
}

# Initialise any state variables the F-Secure output parser uses
my ($fsecure_InHeader, $fsecure_Version, %fsecure_Seen);
sub InitFSecureParser {
  $fsecure_InHeader=(-1);
  $fsecure_Version = 0;
  %fsecure_Seen = ();
}

# Initialise any state variables the ClamAV output parser uses
my ($clamav_archive, $qmclamav_archive);
my (%ClamAVAlreadyLogged);
sub InitClamAVParser {
  my($BaseDir, $batch) = @_;

  $clamav_archive = "";
  $qmclamav_archive = "";

  InitClamAVModParser($BaseDir, $batch);
}

# Initialise any state variables the ClamAV Module output parser uses
sub InitClamAVModParser {
  my($BaseDir, $batch) = @_;

  %ClamAVAlreadyLogged = ();
  if (MailScanner::Config::Value('clamavspam')) {
    # Write the whole message into $id.message in the headers directory
    my($id, $message);
    while(($id, $message) = each %{$batch->{messages}}) {
      next if $message->{deleted};
      my $filename = "$BaseDir/$id.message";
      my $target = new IO::File $filename, "w";
      MailScanner::Log::DieLog("writing to $filename: $!")
        if not defined $target;
      $message->{store}->WriteEntireMessage($message, $target);
      $target->close;
      # Set the ownership and permissions on the .message like .header
      chown $global::MS->{work}->{uid}, $global::MS->{work}->{gid}, $filename
        if $global::MS->{work}->{changeowner};
      chmod 0664, $filename;
    }
  }
}

# Initialise any state variables the Bitdefender output parser uses
sub InitBitdefenderParser {
  ;
}

# Initialise any state variables the AVG output parser uses
sub InitAvgParser {
  ;
}

# These functions must be called with, in order:
# * The line of output from the scanner
# * The MessageBatch object the reports are written to
# * The base directory in which we are working.
#
# The base directory must contain subdirectories named
# per message ID, and must have no trailing slash.
#
#
# These functions must return with:
# * return code 0 if no problem, 1 if problem.
# * type of problem (currently only "v" for virus)
#   appended to $types{messageid}{messagepartname}
# * problem report from scanner appended to
#   $infections{messageid}{messagepartname}
#   -- NOTE: Don't forget the terminating newline.
#
# If the scanner may refer to the same file multiple times,
# you should consider appending to the $infections rather
# than just setting it, I guess.
#


sub ProcessClamAVModOutput {
  my($line, $infections, $types, $BaseDir, $Name, $spaminfre) = @_;
  my($logout, $keyword, $virusname, $filename);
  my($dot, $id, $part, @rest, $report);

  chomp $line;
  $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  #$logout =~ s/%/%%/g;

  #print STDERR "Output is \"$logout\"\n";
  ($keyword, $virusname, $filename) = split(/:: /, $line, 3);
  # Remove any rogue spaces in virus names!
  # Thanks to Alvaro Marin <alvaro@hostalia.com> for this.
  $virusname =~ s/\s+//g;

  if ($keyword =~ /^error/i && $logout !~ /rar module failure/i) {
    MailScanner::Log::InfoLog("%s::%s", $Name, $logout);
    return 1;
  } elsif ($keyword =~ /^info/i || $logout =~ /rar module failure/i) {
    return 0;
  } elsif ($keyword =~ /^clean/i) {
    return 0;
  } else {
    # Must be an infection report
    ($dot, $id, $part, @rest) = split(/\//, $filename);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog("%s::%s", $Name, $logout)
      unless $ClamAVAlreadyLogged{"$id"} && $part eq '';
    $ClamAVAlreadyLogged{"$id"} = 1;

    #print STDERR "virus = \"$virusname\" re = \"$spaminfre\"\n";
    if ($virusname =~ /$spaminfre/) {
      # It's spam found as an infection
      # This is for clamavmodule and clamd
      # Use "u" to signify virus reports that are really spam
      # 20090730
      return "0 $id $virusname";
    }

    # Only log the whole message if no attachment has been logged
    #print STDERR "Part = \"$part\"\n";
    #print STDERR "Logged(\"$id\") = \"" . $ClamAVAlreadyLogged{"$id"} . "\"\n";

    $report = $Name . ': ' if $Name;
    if ($part eq '') {
      # No part ==> entire message is infected.
      $infections->{"$id"}{""}
        .= "$report message was infected: $virusname\n";
    } else {
      $infections->{"$id"}{"$part"}
        .= "$report$notype was infected: $virusname\n";
    }
    $types->{"$id"}{"$part"} .= 'v'; # it's a real virus
    return 1;
  }
}

sub ProcessGenericOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($logout, $keyword, $virusname, $filename);
  my($id, $part, @rest, $report);

  chomp $line;
  $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  ($keyword, $virusname, $filename) = split(/::/, $line, 3);

  if ($keyword =~ /^error/i) {
    MailScanner::Log::InfoLog("GenericScanner::%s", $logout);
    return 1;
  }

  # Must be an infection report
  ($id, $part, @rest) = split(/\//, $filename);
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("GenericScanner::%s", $logout);
  return 0 if $keyword =~ /^clean|^info/i;

  $report = $Name . ': ' if $Name;
  $infections->{"$id"}{"$part"} .= "$report$notype was infected by $virusname\n";
  $types->{"$id"}{"$part"} .= "v"; # it's a real virus
  return 1;
}

sub ProcessSophosSAVIOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($logout, $keyword, $virusname, $filename);
  my($dot, $id, $part, @rest, $report);

  chomp $line;
  $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  #$logout =~ s/%/%%/g;

  ($keyword, $virusname, $filename) = split(/:: /, $line, 3);

  if ($keyword =~ /^error/i) {
    ($dot, $id, $part, @rest) = split(/\//, $filename);
    $report = $Name . ': ' if $Name;

    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    # Allow any error messages that are mentioned in the
    # Allowed Sophos Error Messages option.
    my($errorlist, @errorlist, @errorregexps, $choice);
    $errorlist = MailScanner::Config::Value('sophosallowederrors');
    $errorlist =~ s/^\"(.+)\"$/$1/; # Remove leading and trailing quotes
    @errorlist = split(/\"\s*,\s*\"/, $errorlist); # Split up the list
    foreach $choice (@errorlist) {
      push @errorregexps, quotemeta($choice) if $choice =~ /[^\s]/;
    }
    $errorlist = join('|',@errorregexps); # Turn into 1 big regexp

    if ($errorlist ne "" && $virusname =~ /$errorlist/) {
      MailScanner::Log::WarnLog("Ignored SophosSAVI '%s' error in %s",
                                $virusname, $id);
      return 0;
    } else {
      MailScanner::Log::InfoLog("SophosSAVI::%s", $logout);
      $infections->{"$id"}{"$part"}
        .= "$report$notype caused an error: $virusname\n";
      $types->{"$id"}{"$part"} .= "v"; # it's a real virus
      return 1;
    }
  } elsif ($keyword =~ /^info/i) {
    return 0;
  } elsif ($keyword =~ /^clean/i) {
    return 0;
  } else {
    # Must be an infection reports
    ($dot, $id, $part, @rest) = split(/\//, $filename);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog("SophosSAVI::%s", $logout);

    $report = $Name . ': ' if $Name;
    $infections->{"$id"}{"$part"}
      .= "$report$notype was infected by $virusname\n";
    $types->{"$id"}{"$part"} .= "v"; # it's a real virus
    return 1;
  }
}

sub ProcessSophosOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  my($report, $infected, $dot, $id, $part, @rest, $error);
  my($logout);

  #print "$line";
  chomp $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;
  MailScanner::Log::InfoLog($logout) if $line =~ /error/i;
  # JKF Improved to handle multi-part split archives,
  # JKF which Sophos whinges about
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.com
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.doc
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.rar/eicar.com
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.rar3a/eicar.doc
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.rar3a/eicar.com
  #>>> Virus 'EICAR-AV-Test' found in file /root/q/qeicar/eicar.zip/eicar.com

  return 0 unless $line =~ /(virus.*found)|(could not check)|(password[\s-]*protected)/i;
  $report = $line;
  $infected = $line;
  $infected =~ s/^.*found\s*in\s*file\s*//i;
  # Catch the extra stuff on the end of the line as well as the start
  $infected =~ s/^Could not check\s*(.+) \(([^)]+)\)$/$1/i;
  #print STDERR "Infected = \"$infected\"\n";
  $error = $2;
  #print STDERR "Error = \"$error\"\n";
  if ($error eq "") {
    $error = "Sophos detected password protected file"
      if $infected =~ s/^Password[ -]*protected\s+file\s+(.+)$/$1/i;
    #print STDERR "Error 2 = \"$error\"\n";
  }

  # If the error is one of the allowed errors, then don't report any
  # infections on this file.
  if ($error ne "") {
    # Treat their string as a command-separated list of strings, each of
    # which is in quotes. Any of the strings given may match.
    # If there are no quotes, then there is only 1 string (for backward
    # compatibility).
    my($errorlist, @errorlist, @errorregexps, $choice);
    $errorlist = MailScanner::Config::Value('sophosallowederrors');
    $errorlist =~ s/^\"(.+)\"$/$1/; # Remove leading and trailing quotes
    @errorlist = split(/\"\s*,\s*\"/, $errorlist); # Split up the list
    foreach $choice (@errorlist) {
      push @errorregexps, quotemeta($choice) if $choice =~ /[^\s]/;
    }
    $errorlist = join('|',@errorregexps); # Turn into 1 big regexp

    if ($errorlist ne "" && $error =~ /$errorlist/i) {
      MailScanner::Log::InfoLog($logout);
      MailScanner::Log::WarnLog("Ignored Sophos '%s' error", $error);
      return 0;
    }
  }
  
  #$infected =~ s/^Could not check\s*//i;
  # JKF 10/08/2000 Used to split into max 3 parts, but this doesn't handle
  # viruses in zip files in attachments. Now pull out first 3 parts instead.
  ($dot, $id, $part, @rest) = split(/\//, $infected);
  #system("echo $dot, $id, $part, @rest >> /tmp/jkf");
  #system("echo $infections >> /tmp/jkf");
  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;
  $report =~ s/\Q$part\E/$notype/;
  MailScanner::Log::InfoLog($logout);
  $report = $Name . ': ' . $report if $Name;
  $infections->{"$id"}{"$part"} .= $report . "\n";
  $types->{"$id"}{"$part"} .= "v"; # it's a real virus
  return 1;
}

sub ProcessFSecureOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;

  my($report, $infected, $dot, $id, $part, @rest);
  my($logout, $virus, $BeenSeen);

  chomp $line;
  #print STDERR "$line\n";
  #print STDERR "InHeader $fsecure_InHeader\n";
  #system("echo -n '$line' | od -c");

  # Lose header
  if ($fsecure_InHeader < 0 && $line =~ /version ([\d.]+)/i &&
      !$fsecure_Version) {
    $fsecure_Version = $1 + 0.0;
    $fsecure_InHeader -= 2 if $fsecure_Version >= 4.51 &&
                              $fsecure_Version < 4.60;
    $fsecure_InHeader -= 2 if $fsecure_Version <= 3.0; # For F-Secure 5.5
    #MailScanner::Log::InfoLog("Found F-Secure version $1=$fsecure_Version\n");
    #print STDERR "Version = $fsecure_Version\n";
    return 0;
  }
  if ($line eq "") {
    $fsecure_InHeader++;
    return 0;
  }
  # This test is more vague than it used to be, but is more tolerant to
  # output changes such as extra headers. Scanning non-scanning data is
  # not a great idea but causes no harm.
  # Before version 7.01 this was 0, but header changed again!
  $fsecure_InHeader >= -1 or return 0;

  $report = $line;
  $logout = $line;
  $logout =~ s/%/%%/g;
  $logout =~ s/\s{20,}/ /g;

  # If we are running the new version then there's a totally new parser here
  # F-Secure 5.5 reports version 1.10
  if ($fsecure_Version <= 3.0 || $fsecure_Version >= 4.50) {

    #./g4UFLJR23090/Keld Jrn Simonsen: Infected: EICAR_Test_File [F-Prot]
    #./g4UFLJR23090/Keld Jrn Simonsen: Infected: EICAR-Test-File [AVP]
    #./g4UFLJR23090/cokegift.exe: Infected:   is a joke program [F-Prot]
    # Version 4.61:
    #./eicar.com: Infected: EICAR_Test_File [Libra]
    #./eicar.com: Infected: EICAR Test File [Orion]
    #./eicar.com: Infected: EICAR-Test-File [AVP]
    #./eicar.doc: Infected: EICAR_Test_File [Libra]
    #./eicar.doc: Infected: EICAR Test File [Orion]
    #./eicar.doc: Infected: EICAR-Test-File [AVP]
    #[./eicar.zip] eicar.com: Infected: EICAR_Test_File [Libra]
    #[./eicar.zip] eicar.com: Infected: EICAR Test File [Orion]
    #[./eicar.zip] eicar.com: Infected: EICAR-Test-File [AVP]


    return 0 unless $line =~ /: Infected: /;
    # The last 3 words are "Infected:" + name of virus + name of scanner
    $line =~ s/: Infected: +(.+) \[.*?\]$//;
    #print STDERR "Line is \"$line\"\n";
    MailScanner::Log::NoticeLog("Virus Scanning: F-Secure found virus %s", $1);
    # We are now left with the filename, or
    # then archive name followed by the filename within the archive.
    $line =~ s/^\[(.*?)\] .*$/$1/; # Strip signs of an archive

    # We now just have the filename
    ($dot,$id,$part,@rest) = split(/\//, $line);
    my $notype = substr($part,1);
    $logout =~ s/\Q$part\E/$notype/;
    $report =~ s/\Q$part\E/$notype/;

    MailScanner::Log::InfoLog($logout);
    $report = $Name . ': ' . $report if $Name;
    $infections->{"$id"}{"$part"} .= $report . "\n";
    $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
    # Only report results once for each file
    return 0 if $fsecure_Seen{$line};
    $fsecure_Seen{$line} = 1;
    return 1;
  } else {
    # We are running the old version, so use the old parser
    # Prefer s/// to m// as less likely to do unpredictable things.
    # We hope.
    if ($line =~ /\tinfection:\s/) {
      # Get to relevant filename in a reasonably but not
      # totally robust manner (*impossible* to be totally robust
      # if we have square brackets and spaces in filenames)
      # Strip archive bits if present
      $line =~ s/^\[(.*?)\] .+(\tinfection:.*)/$1$2/;
  
      # Get to the meat or die trying...
      $line =~ s/\tinfection:([^:]*).*$//
        or MailScanner::Log::DieLog("Dodgy things going on in F-Secure output:\n$report\n");
      $virus = $1;
      $virus =~ s/^\s*(\S+).*$/$1/; # 1st word after Infection: is the virus
      MailScanner::Log::NoticeLog("Virus Scanning: F-Secure found virus %s",$virus);
  
      ($dot,$id,$part,@rest) = split(/\//, $line);
      my $notype = substr($part,1);
      $logout =~ s/\Q$part\E/$notype/;
      $report =~ s/\Q$part\E/$notype/;

      MailScanner::Log::InfoLog($logout);
      $report = $Name . ': ' . $report if $Name;
      $infections->{"$id"}{"$part"} .= $report . "\n";
      $types->{"$id"}{"$part"} .= "v"; # so we know what to tell sender
      return 1;
    }
    MailScanner::Log::DieLog("Either you've found a bug in MailScanner's F-Secure output parser, or F-Secure's output format has changed! Please mail the author of MailScanner!\n");
  }
}

sub ProcessClamAVOutput {
  my($line, $infections, $types, $BaseDir, $Name, $spaminfre) = @_;

  my($logline);

  if ($line =~ /^ERROR:/ or $line =~ /^execv\(p\):/ or
      $line =~ /^Autodetected \d+ CPUs/)
  {
    chomp $line;
    $logline = $line;
    $logline =~ s/%/%%/g;
    $logline =~ s/\s{20,}/ /g;
    MailScanner::Log::WarnLog($logline);
    return 0;
  }

  # clamscan currently stops as soon as one virus is found
  # therefore there is little point saying which part
  # it's still a start mind!

  # Only tested with --unzip since only windows boxes get viruses ;-)

  $_ = $line;
  if (/^Archive:  (.*)$/)
  {
    $clamav_archive = $1;
    $qmclamav_archive = quotemeta($clamav_archive);
    return 0;
  }
  return 0 if /Empty file\.?$/;
  # Normally means you just havn't asked for it
  if (/: (\S+ module failure\.)/)
  {
    MailScanner::Log::InfoLog("ProcessClamAVOutput: %s", $1);
    return 0;
  }
  return 0 if /^  |^Extracting|module failure$/;  # "  inflating", "  deflating.." from --unzip
  if ($clamav_archive ne "" && /^$qmclamav_archive:/)
  {
    $clamav_archive = "";
    $qmclamav_archive = "";
    return 0;
  }

  return 0 if /OK$/; 
  
  $logline = $line;
  $logline =~ s/\s{20,}/ /g;

  #(Real infected archive: /var/spool/MailScanner/incoming/19746/./i75EFmSZ014248/eicar.rar)
  if (/^\(Real infected archive: (.*)\)$/)
  {
     my ($file, $ReportStart);
     $file = $1;
     $file =~ s/^(.\/)?$BaseDir\/?//;
     $file =~ s/^\.\///;
     my ($id,$part) = split /\//, $file, 2;
     my $notype = substr($part,1);
     $logline =~ s/\Q$part\E/$notype/;

     # Only log the whole message if no attachment has been logged
     MailScanner::Log::InfoLog("%s", $logline)
       unless $ClamAVAlreadyLogged{"$id"} && $part eq '';
     $ClamAVAlreadyLogged{"$id"} = 1;

     $ReportStart = $notype;
     $ReportStart = $Name . ': ' . $ReportStart if $Name;
     $infections->{"$id"}{"$part"} .= "$ReportStart contains a virus\n";
     $types->{"$id"}{"$part"} .= "v";
     return 1;
  }

  if (/^(\(raw\) )?(.*?): (.*) FOUND$/)
  {
    my ($file, $subfile, $virus, $report, $ReportStart);
    $virus = $3;

    if ($clamav_archive ne "")
    {
      $file = $clamav_archive;
      ($subfile = $2) =~ s/^.*\///;  # get basename of file
      $report = "in $subfile (possibly others)";
    }
    else
    {
      $file = $2;
    }     
     
    $file =~ s/^(.\/)?$BaseDir\/?//;
    $file =~ s/^\.\///;
    my ($id,$part) = split /\//, $file, 2;
    # JKF 20090125 Full message check.
    my $notype = substr($part,1);
    $logline =~ s/\Q$part\E/$notype/;

    $part = "" if $id =~ s/\.(message|header)$//;

    # Only log the whole message if no attachment has been logged
    MailScanner::Log::InfoLog("%s", $logline)
      unless $ClamAVAlreadyLogged{"$id"} && $part eq '';
    $ClamAVAlreadyLogged{"$id"} = 1;

    if ($virus =~ /$spaminfre/) {
      # It's spam found as an infection
      # 20090730
      return "0 $id $virus";
    }

    ## If it doesn't start with $BaseDir/./ then it isn't a real report
    # Don't release this just yet
    #return 0 unless $file =~ /^\/$BaseDir\/\.\//;

    $ReportStart = $notype;
    $ReportStart = $Name . ': ' . $ReportStart if $Name;
    $infections->{"$id"}{"$part"} .= "$ReportStart contains $virus $report\n";
    $types->{"$id"}{"$part"} .= "v";
    return 1;
  }

  return 0 if /^(.*?): File size limit exceeded\.$/;

  chomp $line;
  return 0 if $line =~ /^$/; # Catch blank lines
  $logline = $line;
  $logline =~ s/%/%%/g;
  return 0;
}

sub ProcessBitdefenderOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;

  #print STDERR "$line\n";
  return 0 unless $line =~ /\t(infected|suspected): ([^\t]+)$/;

  my $virus = $2;
  my $logout = $line;
  $logout =~ s/\s{20,}/ /g;
  #print STDERR "virus = \"$virus\"\n";
  # strip the base from the message dir and remove the ^I junk
  $logout =~ s/^.+\/\.\///; # New
  $logout =~ s/\cI/:/g; # New

  # Sample output:
  #
  # /var/spool/MailScanner/incoming/1234/./msgid/filename	infected: virus
  # /var/spool/MailScanner/incoming/1234/./msgid/filename=>subpart	infected: virus

  # Remove path elements before /./ leaving just id/part/rest
  # 20090311 Remove leading BaseDir if it's there too.
  $line =~ s/^$BaseDir\///;
  $line =~ s/^.*\/\.\///;
  my($id, $part, @rest) = split(/\//, $line);

  $part =~ s/\t.*$//;
  $part =~ s/=\>.*$//;

  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  MailScanner::Log::InfoLog("%s", $logout);
  #print STDERR "id = $id\npart = $part\n";
  $infections->{$id}{$part} .= $Name . ': ' if $Name;
  $infections->{$id}{$part} .= "Found virus $virus in file $notype\n";
  $types->{$id}{$part}      .= "v"; # so we know what to tell sender
  return 1;
}

sub ProcessAvgOutput {
  my($line, $infections, $types, $BaseDir, $Name) = @_;
  chomp $line;
  # Sample output:
  #./1B978O-0000g2-Iq/eicar.com  Virus identified  EICAR_Test (+2)
  #./1B978O-0000g2-Iq/eicar.zip:\eicar.com  Virus identified  EICAR_Test (+2)

  # Remove all the duff carriage-returns from the line
  $line =~ s/[\r\n]//g;
  # Removed the (+2) type stuff at the end of the virus name
  $line =~ s/^(.+)(?:\s+\(.+\))$/$1/;
  # JKF AVG8 Remove the control chars from start of the line
  $line =~ s/\e\[2K//g;

  #print STDERR "Line: $line\n";
  # Patch supplied by Chris Richardson to fix AVG7 problem
  # return 0 unless $line =~ /Virus (identified|found) +(.+)$/;
  #
  # Rick - This, used with my $virus = $4, doesn't work (always). End up with
  # missing virus name in postmaster/user reports. Lets just check here and use
  # the next two lines, without check all the extra junk that may or may not
  # be there, to pull the virus name which will always be in $1
  return 0 unless $line =~ /(virus.*(identified|found))|(trojan.*horse)\s+(.+)$/i; # Patch supplied by Chris Richardson /Virus (identified|found) +(.+)$/;

  my $virus = $line;
  $virus =~ s/^.+\s+(.+?)$/$1/;

  #print STDERR "Line: $line\n";
  #print STDERR "virus = \"$virus\"\n";
  my $logout = $line;
  $logout =~ s/\s{2,}/ /gs;
  $logout =~ s/:./->/;

  # Change all the spaces into / for the split coming up
  # Also the second variant prepends the archive name to the
  # infected filename with a:\ so we need to change that to
  # something else. I chose another / so it would end up in the
  # @rest wich is also why I changed the \s+ to /
  # then Remove path elements before /./ leaving just id/part/rest

  $line =~ s/\s+/\//g;
  $line =~ s/:\\/\//g;
  $line =~ s/:\//\//g; # JKF AVG8 :/ separates archives now too.
  $line =~ s/\.\///;
  my($id, $part, @rest) = split(/\//, $line);
  $part =~ s/\t.*$//;
  $part =~ s/=\>.*$//;
  #print STDERR "id:$id:part = $part\n";
  #print STDERR "$Name : Found virus $virus in file $part ID:$id\n";

  # If avg finds both the archive and file to be infected and the file
  # exists in more than one (because of SafeName) archive the archive is
  # reported twice so check and make sure the archive is only reported once

  my $notype = substr($part,1);
  $logout =~ s/\Q$part\E/$notype/;

  $logout =~ /^.+\/(.+?)\s+(.+)\s*$/;
  MailScanner::Log::InfoLog("Avg: %s in %s", $2,$1);

  my $Report = $Name . ': ' if $Name;
  $Report .= "Found virus $virus in file $notype";
  my $ReportPattern = quotemeta($Report);

  $infections->{$id}{$part} .= "$Report\n" unless $infections->{$id}{$part} =~ /$ReportPattern/s;
  $types->{$id}{$part} .= "v" unless $types->{$id}{$part}; # so we know what to tell sender

  return 1;
}


# Generate a list of all the virus scanners that are installed. It may
# include extras that are not installed in the case where there are
# scanners whose name includes a version number and we could not tell
# the difference.
sub InstalledScanners {

  my(@installed, $scannername, $nameandpath, $name, $path, $command, $result);

  # Get list of all the names of the scanners to look up. There are a few
  # rogue ones!
  my @scannernames = keys %Scanners;

  foreach $scannername (@scannernames) {
    next unless $scannername;
    next if $scannername =~ /generic|none/i;
    $nameandpath = MailScanner::Config::ScannerCmds($scannername);
    ($name, $path) = split(',', $nameandpath);
    $command = "$name $path -IsItInstalled";
    #print STDERR "$command gave: ";
    $result = system($command) >> 8;
    #print STDERR "\"$result\"\n";
    push @installed, $scannername unless $result;
  }

  # Now look for clamavmodule and sophossavi library-based scanners.
  # Assume they are installed if I can read the code at all.
  # They over-ride the command-line based versions of the same product.
  if (eval 'require Mail::ClamAV') {
    foreach (@installed) {
      s/^clamav$/clamavmodule/i;
    }
  }
  if (eval 'require SAVI') {
    foreach (@installed) {
      s/^sophos$/sophossavi/i;
    }
  }
  if (ClamdScan('ISITINSTALLED') eq 'CLAMDOK') {
    # If clamav is in the list, replace it with clamd, else add clamd
    my $foundit = 0;
    foreach (@installed) {
      if ($_ eq 'clamav') {
        s/^clamav$/clamd/;
        $foundit = 1;
        last;
      }
    }
    push @installed, 'clamd' unless $foundit;
  }

  #print STDERR "Found list of installed scanners \"" . join(', ', @installed) . "\"\n";
  return @installed;
}


# Should be called when we're about to try to run some code to
# scan or disinfect (after checking that code is present).
# Nick: I'm not convinced this is really worth the bother, it causes me
#       quite a lot of work explaining it to people, and I don't think
#       that the people who should be worrying about this understand
#       enough about it all to know that they *should* worry about it.
sub CheckCodeStatus {
  my($codestatus) = @_;

  my($allowedlevel);

  my $statusname = MailScanner::Config::Value('minimumcodestatus');

  $allowedlevel = $S_SUPPORTED;
  $allowedlevel = $S_BETA        if $statusname =~ /^beta/i;
  $allowedlevel = $S_ALPHA       if $statusname =~ /^alpha/i;
  $allowedlevel = $S_UNSUPPORTED if $statusname =~ /^unsup/i;
  $allowedlevel = $S_NONE        if $statusname =~ /^none/i;

  return 1 if $codestatus>=$allowedlevel;

  MailScanner::Log::WarnLog("FATAL: Encountered code that does not meet " .
                            "configured acceptable stability"); 
  MailScanner::Log::DieLog("FATAL: *Please go and READ* " .
      "http://www.sng.ecs.soton.ac.uk/mailscanner/install/codestatus.shtml" .
      " as it will tell you what to do."); 
}

sub ClamdScan {
  my($dirname, $disinfect, $messagebatch) = @_;
  my($dir, $child, $childname, $filename, $results, $virus);

  my $lintonly = 0;
  $lintonly = 1 if $dirname eq 'ISITINSTALLED';

  # Clamd MUST have the full path to the file/dir it's scanning
  # so let's build the scan dir here and remove that pesky \. at the end
  my $ScanDir = "$global::MS->{work}->{dir}/$dirname";
  $ScanDir =~ s/\/\.$//;

  # If we don't have the required perl libs exit in a fashion the
  # parser will understand
  unless (eval ' require IO::Socket::INET ' ){
    print "ERROR:: You Need IO-Socket-INET to use the clamd " .
          "Scanner :: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }
    unless (eval ' require IO::Socket::UNIX ' ){
    print "ERROR:: You Need IO-Socket-INET to use the clamd " .
          "Scanner :: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # The default scan type is set here and if threading has been enabled
  # switch to threaded scanning
  my $ScanType = "CONTSCAN";
  my $LockFile = MailScanner::Config::Value('clamdlockfile');
  my $LockFile = '' if $lintonly; # Not dependent on this for --lint
  my $TCP = 1;
  my $TimeOut = MailScanner::Config::Value('virusscannertimeout');
  my $UseThreads = MailScanner::Config::Value('clamdusethreads');
  $ScanType = "MULTISCAN" if $UseThreads;

  my $PingTimeOut = 90; # should respond much faster than this to PING
  my $Port = MailScanner::Config::Value('clamdport');
  my $Socket = MailScanner::Config::Value('clamdsocket');
  my $line = '';
  my $sock;

  # If we did not receive a socket file name then we run in TCP mode

  $TCP = 0 if $Socket =~ /^\//;

  # Print our current parameters if we are in debug mode
  MailScanner::Log::DebugLog("Debug Mode Is On");
  MailScanner::Log::DebugLog("Use Threads : YES") if $UseThreads;
  MailScanner::Log::DebugLog("Use Threads : NO") unless $UseThreads;
  MailScanner::Log::DebugLog("Socket    : %s", $Socket)  unless $TCP;
  MailScanner::Log::DebugLog("IP        : %s", $Socket) if $TCP;
  MailScanner::Log::DebugLog("IP        : Using Sockets") unless $TCP;
  MailScanner::Log::DebugLog("Port      : %s", $Port) if $TCP;
  MailScanner::Log::DebugLog("Lock File : %s", $LockFile) if $LockFile ne '';
  MailScanner::Log::DebugLog("Lock File : NOT USED", $LockFile) unless $LockFile ne '';
  MailScanner::Log::DebugLog("Time Out  : %s", $TimeOut);
  MailScanner::Log::DebugLog("Scan Dir  : %s", $ScanDir);

  # Exit if we cannot find the socket file, or we find the file but it's not
  # a socket file (and of course we are not using TCP sockets)

  if (!$TCP && ! -e $Socket) {
    MailScanner::Log::WarnLog("Cannot find Socket (%s) Exiting!",
                              $Socket) if !$TCP && ! -e $Socket && !$lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  if (!$TCP && ! -S $Socket) {
    MailScanner::Log::WarnLog("Found %s but it is not a valid UNIX Socket. " .
                              "Exiting", $Socket) if !$TCP && ! -S $Socket && !$lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # If there should be a lock file, and it's missing the we assume
  # the daemon is not running and warn, pass error to parser and leave
  if ( $LockFile ne '' && ! -e $LockFile ){
    MailScanner::Log::WarnLog("Lock File %s Not Found, Assuming Clamd " .
                              "Is Not Running", $LockFile) && !$lintonly;
    print "ERROR:: Lock File $LockFile was not found, assuming Clamd  " .
          "is not currently running :: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # Connect to the clamd daemon, If we don't connect send the log and
  # parser an error message and exit.
  $sock = ConnectToClamd($TCP,$Socket,$Port, $TimeOut);
  unless ($sock || $lintonly) {
    print "ERROR:: COULD NOT CONNECT TO CLAMD, RECOMMEND RESTARTING DAEMON " .
          ":: $dirname\n";
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }
  unless ($sock) {
    MailScanner::Log::WarnLog("ERROR:: COULD NOT CONNECT TO CLAMD, ".
                              "RECOMMEND RESTARTING DAEMON ") unless $sock || $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  # If we got here we know we have a socket file but it could be dead
  # or clamd may not be listening on the TCP socket we are using, either way
  # we exit with error if we could not open the connection

  if (!$sock) { # socket file from a dead clamd or clamd is not listening
    MailScanner::Log::WarnLog("Could not connect to clamd") unless $lintonly;
    print "ERROR:: COULD NOT CONNECT TO CLAMD DAEMON  " .
          ":: $dirname\n" unless $lintonly;
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  } else {
    # Make sure the daemon is responsive before passing it something to
    # scan
    if ($sock->connected) {
      MailScanner::Log::DebugLog("Clamd : Sending PING");
      $sock->send("PING\n");
      $PingTimeOut += time();
      $line = '';

      while ($line eq '') {
        $line = <$sock>;
        # if we timeout then print error (if debugging) and exit with erro
        MailScanner::Log::WarnLog("ClamD Timed Out During PING " .
                                  "Check!") if $PingTimeOut < time && !$lintonly;
        print "ERROR:: CLAM PING TIMED OUT! :: " .
              "$dirname\n" if time > $PingTimeOut && !$lintonly;
        if (time > $PingTimeOut) {
          print "ScAnNeRfAiLeD\n" unless $lintonly;
          return 1;
        }
        last if time > $PingTimeOut;
        chomp($line);
      }

      MailScanner::Log::DebugLog("Clamd : GOT '%s'",$line);
      MailScanner::Log::WarnLog("ClamD Responded '%s' Instead of PONG " .
                            "During PING Check, Recommend Restarting Daemon",
                                $line) if $line ne 'PONG' && !$lintonly;
      unless ($line eq "PONG" || $lintonly) {
        print "ERROR:: CLAMD DID NOT RESPOND PROPERLY TO PING! PLEASE " .
              "RESTART DAEMON :: $dirname\n";
        print "ScAnNeRfAiLeD\n" unless $lintonly;
      }
      close($sock);
      return 1 unless $line eq "PONG";
      MailScanner::Log::DebugLog("ClamD is running\n");
    } else {
      MailScanner::Log::WarnLog("clam daemon has an Unknown problem, recommend daemon restart") unless $lintonly;
      print "ERROR:: CLAMD HAS AN UNKNOWN PROBLEM, RECOMMEND " .
            "DAEMON RESTART :: $dirname\n" unless $lintonly;
      print "ScAnNeRfAiLeD\n" unless $lintonly;
      return 1;
    }
  }

  # If we are just checking to see if it's installed, bail out now
  return 'CLAMDOK' if $lintonly;

  # Attempt to reopen the connection to clamd
  $sock = ConnectToClamd($TCP,$Socket,$Port, $TimeOut);
  unless ($sock) {
    print "ERROR:: COULD NOT CONNECT TO CLAMD, RECOMMEND DAEMON RESTART " .
          ":: $dirname\n";
    MailScanner::Log::WarnLog("ERROR:: COULD NOT CONNECT TO CLAMD, ".
                              "RECOMMEND DAEMON RESTART ");
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    return 1;
  }

  if ( $sock->connected ) {
    # Going to Scan the entire batch at once, should really speed things
    # up especially on SMP hosts running mutli-threaded scaning
    $TimeOut += time();

    $sock->send("$ScanType $ScanDir\n");
    MailScanner::Log::DebugLog("SENT : $ScanType %s ", "$ScanDir");
    $results = '';
    my $ResultString = '';

    while($results = <$sock>) {
      # if we timeout then print error and exit with error
      if (time > $TimeOut) {
        MailScanner::Log::WarnLog("clamav daemon timed out");
        close($sock);
        print "ERROR:: clam daemon TIME OUT :: " .
              "$dirname\n";
        print "ScAnNeRfAiLeD\n" unless $lintonly;
        return 1;
      }
      # Append this file to any others already found
      $ResultString .= $results;
    }

    # Remove the trailing line feed and create an array of
    # lines for sending to the parser
    chomp($ResultString);
    my @report = split("\n",$ResultString) ;

    foreach $results (@report) {
      #print STDERR "Read \"$results\"\n";
      # Pull the basedir out and change it to a dot for the parser
      $results =~ s/$ScanDir/\./;
      $results =~ s/:\s/\//;

      # If we get an access denied error then print the properly
      # formatted error and leave
      print STDERR "ERROR::clam daemon permission failure. daemon was denied access to " .
            "$ScanDir::$ScanDir\n"
        if $results =~ /\.\/Access denied\. ERROR/;
      last if $results =~ /\.\/Access denied\. ERROR/;

      # If scanning full batch clamd returns OK on the directory
      # name at the end of the scan so we discard that result when
      # we get to it
      next if $results =~ /^\.\/OK/;
      # Workaround for MSRBL-Images (www.msrbl.com/site/msrblimagesabout)
      $results =~ s#MSRBL-Images/#MSRBL-Images\.#;
      my ($dot,$childname,$filename,$rest) = split('/', $results, 4);

      unless ($results) {
        print "ERROR:: $results :: $dirname/$childname/$filename\n";
        next;
      }

      # SaneSecurity ClamAV database can find things in the headers
      # of the message. The parser above results in $childname ending
      # in '.header' and $rest ends in ' FOUND'. In this case we need
      # to report a null childname so the infection is mapped to the
      # entire message.
      if ($childname =~ /\.(?:header|message)$/ && $filename =~ /\sFOUND$/) {
		$rest = $filename;
        $filename = '';
        $childname =~ s/\.(?:header|message)$//;
        print "INFECTED::";
        $rest =~ s/\sFOUND$//;
        print " $rest :: $dirname/$childname/$filename\n";
      }

      elsif ($rest =~ s/\sFOUND$//) {
        print "INFECTED::";
        print " $rest :: $dirname/$childname/$filename\n";
      } elsif ($rest =~ /\sERROR$/) {
        print "ERROR:: $rest :: $dirname/$childname/$filename\n";
        next;
      } else {
        print "ERROR:: UNKNOWN CLAMD RETURN $results :: $ScanDir\n";
      }
    }

    close($sock);
  } else {
    # We were able to open the socket but could not actually connect
    # to the daemon so something odd is amiss and we send error to
    # parser and log, then exit
    print "ERROR:: UNKNOWN ERROR HAS OCCURED WITH CLAMD, RECOMMEND " .
          "DAEMON RESTART :: $dirname\n";
    print "ScAnNeRfAiLeD\n" unless $lintonly;
    MailScanner::Log::DebugLog("UNKNOWN ERROR HAS OCCURED WITH THE CLAMD " .
                               "DAEMON. Recommend daemon restart");
    return 1;
  }

} # EO ClamdScan

# This function just opens the connection to the clamd daemon
# and returns either a valid resource or undef if the connection
# fails
sub ConnectToClamd {
  my($TCP,$Socket,$Port, $TimeOut) = @_;
  my $sock;
  # Attempt to open the appropriate socket depending on the type (TCP/UNIX)
  if ($TCP) {
    $sock = IO::Socket::INET->new(PeerAddr => $Socket,
                                  PeerPort => $Port,
                                  Timeout => $TimeOut,
                                  Proto     => 'tcp');
  } else {
    $sock = IO::Socket::UNIX->new(Timeout => $TimeOut,
                                  Peer => $Socket );
  }
  return undef unless $sock;
  return $sock;
} # EO ConnectToClamd

1;
