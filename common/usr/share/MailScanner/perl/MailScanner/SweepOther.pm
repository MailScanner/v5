#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: SweepOther.pm 5098 2011-06-25 20:11:06Z sysjkf $
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

package MailScanner::SweepOther;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use MIME::Head;
use DirHandle;
use HTML::TokeParser;
use POSIX qw(:signal_h setsid); # For Solaris 9 SIG bug workaround

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5098 $, 10;

# Attributes are
#

# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  bless $this, $type;
  return $this;
}

# Do all the non-commercial virus checking and rules systems in here
sub ScanBatch {
  my $batch = shift;
  my $ScanType = shift;

  # Insert your own checking here.
  $0 = 'MailScanner: scanning for filenames and filetypes';

  # In $BaseDir, you will find a directory for each message, which has the
  # same name as the message id. Also there is a messageid.header file
  # containing all the headers for the message.
  # Add entries into %$infections, where they are referenced as
  # $infections->{"message id"}{"filename"} but please don't over-write ones
  # that are already there.
  # If the danger was detected in a header or applies to the whole message
  # then append the error report (and a newline) to
  # $infections->{"message id"}{""}.
  # Return the number of infections/problems you found.
  # Can play with the MIME headers of a message using $mime.

  my($NumInfections, $BaseDir);
  my($TypeIndicator, $ArchivesAre, @ArchivesAre);

  $NumInfections = 0;
  $BaseDir = $global::MS->{work}->{dir};

  chdir $BaseDir or die "Cannot chdir to $BaseDir for rules checking, $!";

  my($id, $attach, $safename, $notypesafename, $DirEntry, $message);
  my($basefh, $messagefh, $headerfh);
  my $counter = 0;

  $headerfh = new FileHandle;
  $basefh = new DirHandle;
  $basefh->open('.')
    or MailScanner::Log::DieLog("Could not opendir $BaseDir, %s", $!);
  #print STDERR "In SweepOther::ScanBatch, about to read directory $BaseDir\n";
  while ($DirEntry = $basefh->read()) {
    #print STDERR "In SweepOther::ScanBatch, studying $DirEntry\n";
    next if $DirEntry =~ /^\./;
    stat $DirEntry; # Do a stat now to save multiple calls later

    # Test for presence of dangerous headers
    if (-f _ && $DirEntry =~ /\.header$/) {
      open($headerfh, $DirEntry) or next;
      $id = $DirEntry;
      $id =~ s/\.header$//;
      $message = $batch->{messages}{$id};

      next unless defined $message; # Should be a message for all .header files
      next if $message->{deleted};  # Don't do deleted messages!

      # Check the message if *any* recipient wants dangerous content scanning
      next if $message->{scanvirusonly};
      next unless MailScanner::Config::Value('dangerscan', $message) =~ /1/;
      my @headers = <$headerfh>;

      #print STDERR "Checking for Happy virus in $DirEntry ($id)\n";

      # X-Spanska: header ==> "Happy" virus
      #if (grep /^X-Spanska:/i, @headers) {
      #  MailScanner::Log::NoticeLog("Other Checks: Found Happy virus in %s", $id);
      #  $message->{otherreports}{""} .= "\"Happy\" virus\n";
      #  $message->{othertypes}{""}   .= "v";
       # $counter++;
       # $message->{otherinfected}++;
      #}

      #print STDERR "Checking for long MIME boundary\n";
      #print STDERR "Entity = " . $message->{entity} . "\n";
      #print STDERR "Boundary = \"" . $message->{entity}->head->multipart_boundary . "\"\n";

      # MIME content boundary longer than RFC 2046 standard of 70 characters.
      # allowing a bit more to account for -- strings
      if ($message->{entity} &&
          length($message->{entity}->head->multipart_boundary)>=80) {
        MailScanner::Log::NoticeLog("Other Checks: Found multipart boundary " .
                                  "violation of RFC 2046 limit of 70 charaters in %s", $id);
        $message->{otherreports}{""} .= 
          MailScanner::Config::LanguageValue($message,'eudoralongmime') . "\n";
        $message->{othertypes}{""}   .= "v";
        $counter++;
        # And actually try to replace the MIME boundary with a short one
        $message->{entity}->head->mime_attr("Content-type.boundary" =>
                   "__RFC_2046_boundary_violation_replacement__");
        $message->{otherinfected}++;
      }

      # No other tests on headers
      $headerfh->close();
      next;
    }

    # Test for dangerous attachment filenames specified by filename.rules.conf
    # files.
    if (-d _) {
      $id = $DirEntry;
      $messagefh = new DirHandle;
      $messagefh->open($id) or next;
      $message = $batch->{messages}{$id};

      next unless defined $message; # Should be a message for all .header files
      next if $message->{deleted};  # Don't do deleted messages!

      # Check the message if *any* recipient wants dangerous content scanning
      next if $message->{scanvirusonly};
      next unless MailScanner::Config::Value('dangerscan', $message) =~ /1/;

      # Find the name of the TNEF winmail.dat if it exists
      my $tnefname = substr($message->{tnefname},1);
      #print STDERR "TNEF Filename is $tnefname\n";

      my $LogNames = MailScanner::Config::Value('logpermittedfilenames',
                                                $message);

      # Build a regexp matching all the type indicators we consider to be
      # attachments that can from archives.
      $ArchivesAre = $message->{archivesare};

      # Read the filename renaming pattern for this message.
      # This is used for "rename" rules in filename and filetype rules.conf.
      # And make it a filename suffix if they didn't read the instructions!
      my $RenamePattern = MailScanner::Config::Value('defaultrenamepattern', $message);
      $RenamePattern = '__FILENAME__' . $RenamePattern
        unless $RenamePattern =~ /__FILENAME__/i;

      # Set up patterns for simple filename real rules files
      my($allowpatterns, $denypatterns, $allowexists, $denyexists,
         @allowpatterns, @denypatterns, $megaallow,   $megadeny);
      # These are the ones for normal attachments
      my($Nallowpatterns, $Ndenypatterns, $Nallowexists, $Ndenyexists,
         @Nallowpatterns, @Ndenypatterns, $Nmegaallow,   $Nmegadeny);
      # And these are for archived attachments
      my($Aallowpatterns, $Adenypatterns, $Aallowexists, $Adenyexists,
         @Aallowpatterns, @Adenypatterns, $Amegaallow,   $Amegadeny);
      $Nallowpatterns = MailScanner::Config::Value('allowfilenames', $message);
      $Ndenypatterns  = MailScanner::Config::Value('denyfilenames', $message);
      $Nallowpatterns =~ s/^\s+//; # Trim leading space
      $Ndenypatterns  =~ s/^\s+//;
      $Nallowpatterns =~ s/\s+$//; # Trim trailing space
      $Ndenypatterns  =~ s/\s+$//;
      @Nallowpatterns = split(" ", $Nallowpatterns);
      @Ndenypatterns  = split(" ", $Ndenypatterns);
      # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
      @Nallowpatterns = map { s/^\*/.\*/; $_; } @Nallowpatterns;
      @Ndenypatterns  = map { s/^\*/.\*/; $_; } @Ndenypatterns;
      $Nallowexists   = @Nallowpatterns; # Don't use them if they are empty!
      $Ndenyexists    = @Ndenypatterns;
      $Nmegaallow     = '(' . join(')|(',@Nallowpatterns) . ')';
      $Nmegadeny      = '(' . join(')|(',@Ndenypatterns) . ')';

      # And now the same for the archived attachments
      $Aallowpatterns = MailScanner::Config::Value('aallowfilenames', $message);
      $Adenypatterns  = MailScanner::Config::Value('adenyfilenames', $message);
      $Aallowpatterns =~ s/^\s+//; # Trim leading space
      $Adenypatterns  =~ s/^\s+//;
      $Aallowpatterns =~ s/\s+$//; # Trim trailing space
      $Adenypatterns  =~ s/\s+$//;
      @Aallowpatterns = split(" ", $Aallowpatterns);
      @Adenypatterns  = split(" ", $Adenypatterns);
      # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
      @Aallowpatterns = map { s/^\*/.\*/; $_; } @Aallowpatterns;
      @Adenypatterns  = map { s/^\*/.\*/; $_; } @Adenypatterns;
      $Aallowexists   = @Aallowpatterns; # Don't use them if they are empty!
      $Adenyexists    = @Adenypatterns;
      $Amegaallow     = '(' . join(')|(',@Aallowpatterns) . ')';
      $Amegadeny      = '(' . join(')|(',@Adenypatterns) . ')';

      #print STDERR "allowpatterns = $allowpatterns\n";
      #print STDERR "deny          = $denypatterns\n";
      #print STDERR "megaallow     = $megaallow\n";
      #print STDERR "deny          = $megadeny\n";

      # Insert new filename rules checking code here
      #print STDERR "Searching for dodgy filenames in $id\n";
      #print STDERR "SafeFile2File = " . %{$message->{safefile2file}} . "\n";
      #while (($attach, $safename) = each %{$message->{file2safefile}}) {
      while (defined($safename = $messagefh->read())) {
        #print STDERR "Examinin $id/$safename\n";
        next unless -f "$id/$safename"; # Skip . and ..
        $notypesafename = substr($safename,1);
        # TNEF winmail.dat will always be a normal attachment.
        $attach = $message->{safefile2file}{$safename} || $tnefname;
        #print STDERR "Attachment name safefile2file($safename) = $attach\n";
        next if $attach eq "" && $safename eq "";
        $TypeIndicator = substr($safename,0,1);

        # New for V4. The ?= on the end makes the regexp match
        # even when the filename is in a foreign character set.
        # This replaces '$' at the end of the string with "(\?=)?$"
        # $attach does not contain the type indicator, it's the attachment fn.
        $attach =~ s/\$$/(\\\?=)\?\$/;

        #
        # Implement simple all-matches rulesets for allowing and denying files
        #

        my $MatchFound = 0;
        my($logtext, $usertext);

        if ($TypeIndicator =~ /$ArchivesAre/) {
          $allowexists = $Aallowexists;
          $megaallow = $Amegaallow;
        } else {
          $allowexists = $Nallowexists;
          $megaallow = $Nmegaallow;
        }
        # Ignore if there aren't any patterns
        if ($allowexists) {
          #print STDERR "Allow exists\n";
          if ($attach =~ /$megaallow/is || $notypesafename =~ /$megaallow/is) {
            $MatchFound = 1;
            #print STDERR "Allowing filename $id\t$notypesafename\n";
            MailScanner::Log::InfoLog("Filename Checks: Allowing %s %s",
                                      $id, $notypesafename)
              if $LogNames;
          }
        }

        if ($TypeIndicator =~ /$ArchivesAre/) {
          $denyexists = $Adenyexists;
          $megadeny = $Amegadeny;
        } else {
          $denyexists = $Ndenyexists;
          $megadeny = $Nmegadeny;
        }
        # Ignore if there aren't any patterns
        if ($denyexists) {
          #print STDERR "Deny exists\n";
          if (!$MatchFound && ($attach =~ /$megadeny/is ||
                               $notypesafename =~ /$megadeny/is)) {
            $MatchFound = 1;
            # It's a rejection rule, so log the error.
            $logtext = MailScanner::Config::LanguageValue($message,
                                                        'foundblockedfilename');
            $usertext = $logtext;
            #print STDERR "Denying filetype $id\t$notypesafename\n";
            MailScanner::Log::InfoLog("Filename Checks: %s (%s %s)",
                                      $logtext, $id, $attach);
            $message->{namereports}{$safename} .= "$usertext ($notypesafename)\n";
            $message->{nametypes}{$safename}   .= "f";
            $counter++;
            $message->{nameinfected}++;
            $message->DeleteFile($safename);
          }
        }



        # Work through the attachment filename rules,
        # using the first rule that matches.
        my($i, $FilenameRules);
        if ($TypeIndicator =~ /$ArchivesAre/) {
          $FilenameRules = MailScanner::Config::AFilenameRulesValue($message);
        } else {
          $FilenameRules = MailScanner::Config::NFilenameRulesValue($message);
        }
        next unless $FilenameRules;

        #foreach $i (@$FilenameRules) {
          #print STDERR "FilenameRule: $i\n";
        #}

        my($allowdeny, $regexp, $iregexp);
        for ($i=0; !$MatchFound && $i<scalar(@$FilenameRules); $i++) {
          ($allowdeny, $regexp, $iregexp, $logtext, $usertext)
            = split(/\0/, $FilenameRules->[$i]);

          #print STDERR "Filename match $i: \"$allowdeny\" \"$regexp\" \"$attach\" \"$safename\" $logtext $usertext\n";
          # Skip this rule if the regexp doesn't match
          # Check both filenames, the safe and the nasty. This is for
          # TNEF messages when the nasty filename is always winmail.dat
          # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
          $regexp =~ s/^\*/.\*/;
          next unless $attach =~ /$regexp/is || $notypesafename =~ /$regexp/is;
          $MatchFound = 1;

          #print STDERR "\"$attach\" matched \"$regexp\" or \"$safename\" did\n";
          if ($allowdeny =~ /^rename/i) {
            # It's a rename rule, not really a rejection or acceptance.
            MailScanner::Log::InfoLog("Filename Checks: %s (%s %s)",
                                      $logtext, $id, $attach);
            my $entity = $message->{file2entity}{$attach};
            if ($entity && $entity->head) {
              my $newname = '';
              if ($allowdeny =~ s/^rename //i) {
                # They have supplied the replacement text, now in $allowdeny
                $newname = $attach;
                # This lets them put things like $1 and $2 in the RHS.
                $regexp =~ /^(.*)$/;
                $regexp = $1;
                $allowdeny =~ /^(.*)$/;
                $allowdeny = $1;
                eval '$newname =~ s/'.$regexp.'/'.$allowdeny.'/i'; # TAINT
                #$newname =~ s/$regexp/$allowdeny/is;
              } else {
                # No replacement text, so use the default rename pattern
                # if it was set in MailScanner.conf.
                if ($RenamePattern) {
                  $newname = $RenamePattern;
                  $newname =~ s/__FILENAME__/$attach/i;
                }
              }
              if ($newname ne '') {
                MailScanner::Log::InfoLog("Filename Checks: %s renamed %s to %s",
                                          $id, $attach, $newname);
                #print STDERR "Renaming $attach to $newname\n";
                # These are the only 2 places the user's filename has to change
                $entity->head->mime_attr("content-disposition.filename",
                                         $newname);
                $entity->head->mime_attr("content-type.name",
                                         $newname);
                # Do no more than this, we aren't generating loads of reports
                $message->{bodymodified} = 1;
              }
            }
          } elsif ($allowdeny =~ /^deny[^@]*$/i) {
            # It's a deny or deny+delete, not an email address.
            # It's a rejection rule, so log the error.
            MailScanner::Log::InfoLog("Filename Checks: %s (%s %s)",
                                      $logtext, $id, $attach);
            $message->{namereports}{$safename} .= "$usertext ($notypesafename)\n";
            $message->{nametypes}{$safename}   .= "f";
            $counter++;
            $message->{nameinfected}++;
            # Do we want to delete the attachment or store it?
            if ($allowdeny =~ /delete/) {
              $message->{deleteattach}{$safename} = 1;
              $message->DeleteFile($safename);
            }
          } elsif ($allowdeny =~ /@/) {
          # It's email addresses so replace the recipients list.
          $message->DeleteAllRecipients();
          my @newto = split(" ", lc($allowdeny));
          $global::MS->{mta}->AddRecipients($message, @newto);
          my $newto = join(',', @newto);
          MailScanner::Log::InfoLog("Filetype Checks: Forwarding %s %s to %s",
                                    $id, $notypesafename, $newto);
          } else {
            MailScanner::Log::InfoLog("Filename Checks: Allowing %s %s",
                                      $id, $notypesafename)
              if $LogNames;
          }
        }
        MailScanner::Log::InfoLog("Filename Checks: Allowing %s %s " .
                                  "(no rule matched)", $id, $notypesafename)
          if $LogNames && !$MatchFound;
      }
    }
  }
  $basefh->close();

  # Don't do these checks if they haven't specified a filetype rules file
  # or they haven't specified a "file" command
  return $counter if !MailScanner::Config::Value('filecommand');
  return $counter if MailScanner::Config::IsSimpleValue('afiletyperules') &&
                     !MailScanner::Config::Value('afiletyperules') &&
                     MailScanner::Config::IsSimpleValue('aallowfiletypes') &&
                     !MailScanner::Config::Value('aallowfiletypes') &&
                     MailScanner::Config::IsSimpleValue('adenyfiletypes') &&
                     !MailScanner::Config::Value('adenyfiletypes') &&
                     MailScanner::Config::IsSimpleValue('filetyperules') &&
                     !MailScanner::Config::Value('filetyperules') &&
                     MailScanner::Config::IsSimpleValue('allowfiletypes') &&
                     !MailScanner::Config::Value('allowfiletypes') &&
                     MailScanner::Config::IsSimpleValue('denyfiletypes') &&
                     !MailScanner::Config::Value('denyfiletypes');

  $counter += CheckFileContentTypes($batch);

  return $counter;
}


sub CheckFileContentTypes {
  my($batch) = shift;

  my $BaseDir = $global::MS->{work}->{dir};
  chdir $BaseDir or die "Cannot chdir to $BaseDir for rules checking, $!";

  # Fork and execute the file command against a timeout, capturing output
  # from it.
  # Need "filetimeout" config option

  my($Kid, $pid, $TimedOut, $Counter, $PipeReturn, %FileTypes, $filecommand);
  my(@filelist);
  $Kid  = new FileHandle;
  $TimedOut = 0;
  $filecommand = MailScanner::Config::Value('filecommand');

  eval {
    die "Can't fork: $!" unless defined($pid = open($Kid, '-|'));
    if ($pid) {
      # In the parent
      local $SIG{ALRM} = sub { $TimedOut = 1; die "Command Timed Out" };
      alarm MailScanner::Config::Value('filetimeout');
      # Only process the output if we are scanning, not disinfecting
      while(<$Kid>) {
        chomp;
        #$FileTypes{$1}{$2} = $3 if /^([^\/]+)\/([^:]+):\s*(.*)$/;
        $FileTypes{$1}{$2} = $3 if /^([^\/]+)\/([^:]+):\s*([^,]*)/;
        #print STDERR "Processing line \"$_\"\n";
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
      @filelist = <*/*>;
      exit 0 unless @filelist;
      #exec "$filecommand */*"; # Shouldn't do this like this!
      exec(map { m/(.*)/ } split(/ +/, $filecommand), @filelist);
      MailScanner::Log::WarnLog("Can't run file command " .
                                "(\"$filecommand\"): $!");
      exit 1;
    }
  };
  alarm 0; # 2.53

  # Note to self: I only close the KID in the parent, not in the child.
  MailScanner::Log::DebugLog("Completed checking by $filecommand");

  # Catch failures other than the alarm
  MailScanner::Log::DieLog("File checker failed with real error: $@")
    if $@ and $@ !~ /Command Timed Out/;

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

  # Return failure if the command timed out, otherwise return success
  MailScanner::Log::WarnLog("File checker $filecommand timed out!")
    if $TimedOut;

  # If we are not using "file -i" at all, then just short-circuit all
  # of this, and check file command output only.
  unless ($MailScanner::Config::UsingFileICommand ||
           MailScanner::Config::Value('denyfilemimetypes') ||
           MailScanner::Config::Value('adenyfilemimetypes')) {
    $Counter = CheckFileTypesRules($batch, \%FileTypes, undef);
    return $Counter;
  }

  my(%FileiTypes);
  $Kid  = new FileHandle;
  $TimedOut = 0;

  eval {
    die "Can't fork: $!" unless defined($pid = open($Kid, '-|'));
    if ($pid) {
      # In the parent
      local $SIG{ALRM} = sub { $TimedOut = 1; die "Command Timed Out" };
      alarm MailScanner::Config::Value('filetimeout');
      # Only process the output if we are scanning, not disinfecting
      while(<$Kid>) {
        chomp;
        $FileiTypes{$1}{$2} = $3 if /^([^\/]+)\/([^:]+):\s*([^;]*)(;.*)?$/;
        #print STDERR "Processing line \"$_\"\n";
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
      @filelist = <*/*>;
      exit 0 unless @filelist;
      #exec "$filecommand */*"; # Shouldn't do this like this!
      exec(map { m/(.*)/ } split(/ +/, $filecommand), '-i', @filelist);
      MailScanner::Log::WarnLog("Can't run 'file -i' command " .
                                "(\"$filecommand -i\"): $!");
      exit 1;
    }
  };
  alarm 0; # 2.53

  # Note to self: I only close the KID in the parent, not in the child.
  MailScanner::Log::DebugLog("Completed checking by $filecommand -i");

  # Catch failures other than the alarm
  MailScanner::Log::DieLog("File mime-type check failed with real error: $@")
    if $@ and $@ !~ /Command Timed Out/;

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

  # Return failure if the command timed out, otherwise return success
  MailScanner::Log::WarnLog("File checker $filecommand -i timed out!")
    if $TimedOut;

  # Now check all the %FileTypes we have read in
  $Counter = CheckFileTypesRules($batch, \%FileTypes, \%FileiTypes);
  return $Counter;
}


sub CheckFileTypesRules {
  my($batch, $FileOutput, $FileiOutput) = @_;

  my($id, $attachtypes, $message, $tnefname, $safename, $type, $attach);
  my($notypesafename);
  my($ArchivesAre, @ArchivesAre, $TypeIndicator);
  my($i, $FiletypeRules, $AFiletypeRules, $NFiletypeRules);
  my($allowpatterns, $denypatterns, $allowexists, $denyexists,
     @allowpatterns, @denypatterns, $megaallow,   $megadeny);
  my($Aallowpatterns, $Adenypatterns, $Aallowexists, $Adenyexists,
     @Aallowpatterns, @Adenypatterns, $Amegaallow,   $Amegadeny);
  my($Nallowpatterns, $Ndenypatterns, $Nallowexists, $Ndenyexists,
     @Nallowpatterns, @Ndenypatterns, $Nmegaallow,   $Nmegadeny);
  my($LogTypes, $RenamePattern);
  my $counter = 0;

  # winmail.dat will always be a normal attachment
  $tnefname = substr($message->{tnefname},1);

  my $lastid = '';
  while(($id, $attachtypes) = each %$FileOutput) {
    next unless $id;
    $message = $batch->{messages}{$id};

    # Check the message if *any* recipient wants dangerous content scanning
    next if $message->{scanvirusonly};
    next unless MailScanner::Config::Value('dangerscan', $message) =~ /1/;

    # Optimisation: Don't do this if we're still on the same message.
    if ($id ne $lastid) {
      $lastid = $id;
      # Build a regexp matching all the type indicators we consider to be
      # attachments that can from archives.
      $ArchivesAre = $message->{archivesare};

      $LogTypes = MailScanner::Config::Value('logpermittedfiletypes',
                                                $message);

      # Read the filename renaming pattern for this message.
      # This is used for "rename" rules in filename and filetype rules.conf.
      # And make it a filename suffix if they didn't read the instructions!
      $RenamePattern = MailScanner::Config::Value('defaultrenamepattern', $message);
      $RenamePattern = '__FILENAME__' . $RenamePattern
        unless $RenamePattern =~ /__FILENAME__/i;

      # Set up patterns for simple filename real rules files
      $Aallowpatterns = MailScanner::Config::Value('aallowfiletypes', $message);
      $Adenypatterns  = MailScanner::Config::Value('adenyfiletypes', $message);
      $Aallowpatterns =~ s/^\s+//; # Trim leading space
      $Adenypatterns  =~ s/^\s+//;
      $Aallowpatterns =~ s/\s+$//; # Trim trailing space
      $Adenypatterns  =~ s/\s+$//;
      @Aallowpatterns = split(" ", $Aallowpatterns);
      @Adenypatterns  = split(" ", $Adenypatterns);
      # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
      @Aallowpatterns = map { s/^\*/.\*/; $_; } @Aallowpatterns;
      @Adenypatterns  = map { s/^\*/.\*/; $_; } @Adenypatterns;
      $Aallowexists   = @Aallowpatterns; # Don't use them if they are empty!
      $Adenyexists    = @Adenypatterns;
      $Amegaallow     = '(' . join(')|(',@Aallowpatterns) . ')';
      $Amegadeny      = '(' . join(')|(',@Adenypatterns) . ')';
      $Nallowpatterns = MailScanner::Config::Value('allowfiletypes', $message);
      $Ndenypatterns  = MailScanner::Config::Value('denyfiletypes', $message);
      $Nallowpatterns =~ s/^\s+//; # Trim leading space
      $Ndenypatterns  =~ s/^\s+//;
      $Nallowpatterns =~ s/\s+$//; # Trim trailing space
      $Ndenypatterns  =~ s/\s+$//;
      @Nallowpatterns = split(" ", $Nallowpatterns);
      @Ndenypatterns  = split(" ", $Ndenypatterns);
      # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
      @Nallowpatterns = map { s/^\*/.\*/; $_; } @Nallowpatterns;
      @Ndenypatterns  = map { s/^\*/.\*/; $_; } @Ndenypatterns;
      $Nallowexists   = @Nallowpatterns; # Don't use them if they are empty!
      $Ndenyexists    = @Ndenypatterns;
      $Nmegaallow     = '(' . join(')|(',@Nallowpatterns) . ')';
      $Nmegadeny      = '(' . join(')|(',@Ndenypatterns) . ')';

      $AFiletypeRules = MailScanner::Config::AFiletypeRulesValue($message);
      $NFiletypeRules = MailScanner::Config::NFiletypeRulesValue($message);
    }

    while(($safename, $type) = each %$attachtypes) {
      $attach = $message->{safefile2file}{$safename} || $tnefname;
      next if $attach eq "" && $safename eq "";
      $notypesafename = substr($safename,1);

      # Find the attachment type from the 1st letter of the filename
      $TypeIndicator = substr($safename,0,1);

      #
      # Implement simple all-matches rulesets for allowing and denying files
      #

      my $MatchFound = 0;
      my($logtext, $usertext);

      if ($TypeIndicator =~ /$ArchivesAre/) {
        $allowexists   = $Aallowexists;
        $megaallow     = $Amegaallow;
        $denyexists    = $Adenyexists;
        $megadeny      = $Amegadeny;
        $FiletypeRules = $AFiletypeRules;
      } else {
        $allowexists   = $Nallowexists;
        $megaallow     = $Nmegaallow;
        $denyexists    = $Ndenyexists;
        $megadeny      = $Nmegadeny;
        $FiletypeRules = $NFiletypeRules;
      }

      # Ignore if there aren't any patterns
      if ($allowexists) {
        if ($type =~ /$megaallow/is) {
          $MatchFound = 1;
          MailScanner::Log::InfoLog("Filetype Checks: Allowing %s %s",
                                    $id, $notypesafename)
            if $LogTypes;
        }
      }
      # Ignore if there aren't any patterns
      if ($denyexists) {
        if (!$MatchFound && $type =~ /$megadeny/is) {
          $MatchFound = 1;
          # It's a rejection rule, so log the error.
          $logtext = MailScanner::Config::LanguageValue($message,
                                                        'foundblockedfiletype');
          $usertext = $logtext;
          MailScanner::Log::InfoLog("Filetype Checks: %s (%s %s)",
                                    $logtext, $id, $attach);
          $message->{namereports}{$safename} .= "$usertext ($notypesafename)\n";
          $message->{nametypes}{$safename}   .= "f";
          $counter++;
          $message->{nameinfected}++;
          $message->DeleteFile($safename);
        }
      }

      # Work through the attachment filetype rules,
      # using the first rule that matches.
      next unless $FiletypeRules;
      my($allowdeny, $regexp, $iregexp);
      for ($i=0; !$MatchFound && $i<@$FiletypeRules; $i++) {
        ($allowdeny, $regexp, $iregexp, $logtext, $usertext)
          = split(/\0/, $FiletypeRules->[$i]);

        next if $regexp eq '' || $regexp eq '-'; # Skip this rule if there's no regexp at all
        #print STDERR "Type = $type, regexp = $regexp\n";
        # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
        $regexp =~ s/^\*/.\*/;
        next unless $type =~ /$regexp/is;
        #print STDERR "Filetype match: $allowdeny $regexp $logtext $usertext\n";

        $MatchFound = 1;

        if ($allowdeny =~ /^rename/i) {
          # It's a rename rule, not really a rejection or acceptance.
          MailScanner::Log::InfoLog("Filename Checks: %s (%s %s)",
                                    $logtext, $id, $attach);
          my $entity = $message->{file2entity}{$attach};
          #print STDERR "entity = $entity\n";
          if ($entity && $entity->head && $RenamePattern) {
            my $newname = $RenamePattern;
            $newname =~ s/__FILENAME__/$attach/i;

            MailScanner::Log::InfoLog("Filetype Checks: %s renamed %s to %s",
                                      $id, $attach, $newname);
            #print STDERR "Renaming $attach to $newname\n";
            # These are the only 2 places the user's filename has to change
            $entity->head->mime_attr("content-disposition.filename",
                                     $newname);
            $entity->head->mime_attr("content-type.name",
                                     $newname);
            # Do no more than this, we aren't generating loads of reports
            $message->{bodymodified} = 1;
          }
        } elsif ($allowdeny =~ /^deny[^@]*$/i) {
          # It's a deny or deny+delete, not an email address
          # It's a rejection rule, so log the error.
          MailScanner::Log::InfoLog("Filetype Checks: %s (%s %s)",
                                    $logtext, $id, $attach);
          $message->{namereports}{$safename} .= "$usertext ($notypesafename)\n";
          $message->{nametypes}{$safename}   .= "f";
          $counter++;
          $message->{nameinfected}++;
          # Do we want to delete the attachment or store it?
          if ($allowdeny =~ /delete/) {
            $message->{deleteattach}{$safename} = 1;
            $message->DeleteFile($safename);
          }
        } elsif ($allowdeny =~ /@/) {
          # It's email addresses so replace the recipients list.
          $message->DeleteAllRecipients();
          my @newto = split(" ", lc($allowdeny));
          $global::MS->{mta}->AddRecipients($message, @newto);
          my $newto = join(',', @newto);
          MailScanner::Log::InfoLog("Filetype Checks: Forwarding %s %s to %s",
                                    $id, $notypesafename, $newto);
        } else {
          MailScanner::Log::InfoLog("Filetype Checks: Allowing %s %s",
                                    $id, $notypesafename)
            if $LogTypes;
        }
      }
      # Log it as allowed if it didn't match any rule
      MailScanner::Log::InfoLog("Filetype Checks: Allowing %s %s " .
                                "(no match found)", $id, $notypesafename)
            if $LogTypes && !$MatchFound;
    }
  }

  # Short-circuit all the "file -i" testing if it hasn't been used
  return $counter unless defined $FileiOutput;

  # This is a duplicate of the code above, but with all the testing done
  # against the "file -i" output and configuration settings.
  #print STDERR "Doing 'file -i' output processing\n";
  $lastid = '';
  while(($id, $attachtypes) = each %$FileiOutput) {
    next unless $id;
    $message = $batch->{messages}{$id};

    # Optimisation, don't do any of this if we're on the same message.
    my($allowpatterns, $denypatterns, $allowexists, $denyexists,
       @allowpatterns, @denypatterns, $megaallow,   $megadeny);
    my($Aallowpatterns, $Adenypatterns, $Aallowexists, $Adenyexists,
       @Aallowpatterns, @Adenypatterns, $Amegaallow,   $Amegadeny);
    my($Nallowpatterns, $Ndenypatterns, $Nallowexists, $Ndenyexists,
       @Nallowpatterns, @Ndenypatterns, $Nmegaallow,   $Nmegadeny);
    my($LogTypes);
    my($i, $FiletypeRules);

    if ($lastid ne $id) {
      $lastid = $id;
      # Check the message if *any* recipient wants dangerous content scanning
      next if $message->{scanvirusonly};
      next unless MailScanner::Config::Value('dangerscan', $message) =~ /1/;

      $LogTypes = MailScanner::Config::Value('logpermittedfilemimetypes',
                                                $message);

      # Set up patterns for simple filename real rules files
      $Aallowpatterns = MailScanner::Config::Value('aallowfilemimetypes', $message);
      $Adenypatterns  = MailScanner::Config::Value('adenyfilemimetypes', $message);
      $Aallowpatterns =~ s/^\s+//; # Trim leading space
      $Adenypatterns  =~ s/^\s+//;
      $Aallowpatterns =~ s/\s+$//; # Trim trailing space
      $Adenypatterns  =~ s/\s+$//;
      @Aallowpatterns = split(" ", $Aallowpatterns);
      @Adenypatterns  = split(" ", $Adenypatterns);
      # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
      @Aallowpatterns = map { s/^\*/.\*/; $_; } @Aallowpatterns;
      @Adenypatterns  = map { s/^\*/.\*/; $_; } @Adenypatterns;
      $Aallowexists   = @Aallowpatterns; # Don't use them if they are empty!
      $Adenyexists    = @Adenypatterns;
      $Amegaallow     = '(' . join(')|(',@Aallowpatterns) . ')';
      $Amegadeny      = '(' . join(')|(',@Adenypatterns) . ')';
      $Nallowpatterns = MailScanner::Config::Value('allowfilemimetypes', $message);
      $Ndenypatterns  = MailScanner::Config::Value('denyfilemimetypes', $message);
      $Nallowpatterns =~ s/^\s+//; # Trim leading space
      $Ndenypatterns  =~ s/^\s+//;
      $Nallowpatterns =~ s/\s+$//; # Trim trailing space
      $Ndenypatterns  =~ s/\s+$//;
      @Nallowpatterns = split(" ", $Nallowpatterns);
      @Ndenypatterns  = split(" ", $Ndenypatterns);
      # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
      @Nallowpatterns = map { s/^\*/.\*/; $_; } @Nallowpatterns;
      @Ndenypatterns  = map { s/^\*/.\*/; $_; } @Ndenypatterns;
      $Nallowexists   = @Nallowpatterns; # Don't use them if they are empty!
      $Ndenyexists    = @Ndenypatterns;
      $Nmegaallow     = '(' . join(')|(',@Nallowpatterns) . ')';
      $Nmegadeny      = '(' . join(')|(',@Ndenypatterns) . ')';

      $AFiletypeRules = MailScanner::Config::AFiletypeRulesValue($message);
      $NFiletypeRules = MailScanner::Config::NFiletypeRulesValue($message);
    }

    while(($safename, $type) = each %$attachtypes) {
      $attach = $message->{safefile2file}{$safename} || $tnefname;
      next if $attach eq "" && $safename eq "";

      $notypesafename = substr($safename,1);
      $TypeIndicator = substr($safename,0,1);
      if ($TypeIndicator =~ /$ArchivesAre/) {
        $allowexists   = $Aallowexists;
        $megaallow     = $Amegaallow;
        $denyexists    = $Adenyexists;
        $megadeny      = $Amegadeny;
        $FiletypeRules = $AFiletypeRules;
      } else {
        $allowexists   = $Nallowexists;
        $megaallow     = $Nmegaallow;
        $denyexists    = $Ndenyexists;
        $megadeny      = $Nmegadeny;
        $FiletypeRules = $NFiletypeRules;
      }

      #
      # Implement simple all-matches rulesets for allowing and denying files
      #

      my $MatchFound = 0;
      my($logtext, $usertext);

      # Ignore if there aren't any patterns
      if ($allowexists) {
        if ($type =~ /$megaallow/is) {
          $MatchFound = 1;
          MailScanner::Log::InfoLog("Filetype Checks: Allowing %s %s",
                                    $id, $notypesafename)
            if $LogTypes;
        }
      }
      # Ignore if there aren't any patterns
      if ($denyexists) {
        if (!$MatchFound && $type =~ /$megadeny/is) {
          $MatchFound = 1;
          # It's a rejection rule, so log the error.
          $logtext = MailScanner::Config::LanguageValue($message,
                                                        'foundblockedfiletype');
          $usertext = $logtext;
          MailScanner::Log::InfoLog("Filetype Checks: %s (%s %s)",
                                    $logtext, $id, $attach);
          $message->{namereports}{$safename} .= "$usertext ($notypesafename)\n";
          $message->{nametypes}{$safename}   .= "f";
          $counter++;
          $message->{nameinfected}++;
          $message->DeleteFile($safename);
        }
      }

      # Work through the attachment filetype rules,
      # using the first rule that matches.
      next unless $FiletypeRules;
      my($allowdeny, $regexp, $iregexp);
      for ($i=0; !$MatchFound && $i<@$FiletypeRules; $i++) {
        ($allowdeny, $regexp, $iregexp, $logtext, $usertext)
          = split(/\0/, $FiletypeRules->[$i]);

        next if $iregexp eq '' || $iregexp eq '-'; # Skip this rule if there's no regexp at all
        #print STDERR "iType = $type, iregexp = $iregexp\n";
        # JKF Addenbrookes - Catch leading "*" on regexps and replace with ".*"
        $iregexp =~ s/^\*/.\*/;
        next unless $type =~ /$iregexp/is;
        #print STDERR "iFiletype match: $allowdeny $regexp $iregexp $logtext $usertext ($type)\n";

        $MatchFound = 1;
        if ($allowdeny =~ /^deny[^@]*$/i) {
          # It's a rejection rule, so log the error.
          MailScanner::Log::InfoLog("Filetype Mime Checks: %s (%s %s)",
                                    $logtext, $id, $attach);
          $message->{namereports}{$safename} .= "$usertext ($notypesafename)\n";
          $message->{nametypes}{$safename}   .= "f";
          $counter++;
          $message->{nameinfected}++;
          # Do we want to delete the attachment or store it?
          if ($allowdeny =~ /delete/) {
            $message->{deleteattach}{$safename} = 1;
            $message->DeleteFile($safename);
          }
        } elsif ($allowdeny =~ /@/) {
          # It's email addresses so replace the recipients list.
          $message->DeleteAllRecipients();
          my @newto = split(" ", lc($allowdeny));
          $global::MS->{mta}->AddRecipients($message, @newto);
          my $newto = join(',', @newto);
          MailScanner::Log::InfoLog("Filetype Mime Checks: Forwarding %s %s to %s",
                                    $id, $notypesafename, $newto);
        } else {
          MailScanner::Log::InfoLog("Filetype Mime Checks: Allowing %s %s",
                                    $id, $notypesafename)
            if $LogTypes;
        }
      }
      # Log it as allowed if it didn't match any rule
      MailScanner::Log::InfoLog("Filetype Mime Checks: Allowing %s %s " .
                                "(no match found)", $id, $notypesafename)
            if $LogTypes && !$MatchFound;
    }
  }

  return $counter;
}

1;
