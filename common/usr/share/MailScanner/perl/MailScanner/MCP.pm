#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: MCP.pm 3813 2007-01-22 21:08:44Z sysjkf $
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

package MailScanner::MCP;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s
#use English; # Needed for $PERL_VERSION to work in all versions of Perl

use POSIX qw(:signal_h); # For Solaris 9 SIG bug workaround
use IO::Pipe;
# Don't do this any more as SpamAssassin prefers to do it itself
# use AnyDBM_File; # Doing this here keeps SpamAssassin quiet

use vars qw($VERSION $SAspamtest $SABayesLock);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 3813 $, 10;

# Attributes are
#
#

my $SAversion;
my($safailures) = 0;

#my($SAspamtest, $SABayesLock);

sub initialise {

  my(%settings, $val, $val2, $prefs);

  # Can't just do this when sendmail.pl loads, as we are still running as
  # root then & spamassassin will get confused when we are later running
  # as something else.

  # Only do this if we want to use SpamAssassin and therefore have it installed.
  # Justin Mason advises only creating 1 Mail::SpamAssassin object, so I do it
  # here while we are starting up.

  # N.B. SpamAssassin will use home dir defined in ENV{HOME}
  #      'if $ENV{HOME} =~ /\//'
  # So, set ENV{HOME} to desired directory, or undef it to force it to get home
  # using getpwnam of $> (EUID)

  # If they don't want MCP Checks at all, or they don't want MCP SA Checks
  # then do nothing, else...
  unless ((MailScanner::Config::IsSimpleValue('mcpchecks') &&
           !MailScanner::Config::Value('mcpchecks')) ||
          (MailScanner::Config::IsSimpleValue('mcpusespamassassin') &&
           !MailScanner::Config::Value('mcpusespamassassin'))) {
    $settings{dont_copy_prefs} = 1; # Removes need for home directory
    $prefs = MailScanner::Config::Value('mcpspamassassinprefsfile');
    $settings{userprefs_filename} = $prefs if defined $prefs;
    $val = MailScanner::Config::Value('debugspamassassin');
    $settings{debug} = $val;
    # for unusual bayes and auto whitelist database locations
    $val = MailScanner::Config::Value('mcpspamassassinuserstatedir');
    $settings{userstate_dir} = $val if $val ne "";
    $val = MailScanner::Config::Value('mcpspamassassinlocalrulesdir');
    $settings{LOCAL_RULES_DIR} = $val if $val ne "";
    # Set the local state directory to a bogus value so it is not used
    $settings{LOCAL_STATE_DIR} = '/BogusSAStateDir';
    $val = MailScanner::Config::Value('mcpspamassassindefaultrulesdir');
    $settings{DEF_RULES_DIR} = $val if $val ne "";
    $val = MailScanner::Config::Value('mcpspamassassininstallprefix');

    # For version 3 onwards, shouldn't cause problems with earlier code
    $val2 = MailScanner::Config::Value('spamassassinautowhitelist');
    $settings{use_auto_whitelist} = $val2?1:0;
    $settings{save_pattern_hits} = 1;

    if ($val ne "") {
      # for finding rules in the absence of the above settings
      $settings{PREFIX} = $val;
      # for finding the SpamAssassin libraries
      # Use unshift rather than push so that their given location is
      # always searched *first* and not last in the include path.
      #my $perl_vers = $PERL_VERSION < 5.006 ? $PERL_VERSION
      #                                      : sprintf("%vd",$PERL_VERSION);
      my $perl_vers = $] < 5.006 ? $] : sprintf("%vd",$^V);
      unshift @INC, "$val/lib/perl5/site_perl/$perl_vers";
    }
    # Now we have the path built, try to find the SpamAssassin modules
    MailScanner::Log::DieLog("Message Content Protection SpamAssassin installation could not be found")
      unless eval "require Mail::SpamAssassin";
    $SAversion = $Mail::SpamAssassin::VERSION + 0.0;

    $MailScanner::MCP::SAspamtest = new Mail::SpamAssassin(\%settings);
    #print STDERR "MCP: Created SA object $MailScanner::MCP::SAspamtest\n";

    #if ($prefs ne "") {
    #  $MailScanner::MCP::SAspamtest = new Mail::SpamAssassin(
    #                                   {'userprefs_filename' => $prefs,
    #                                    'dont_copy_prefs' => 0 });
    #} else {
    #  $MailScanner::MCP::SAspamtest = new Mail::SpamAssassin();
    #}

    #if (MailScanner::Config::Value('mcpspamassassinautowhitelist')) {
    #  # JKF 14/6/2002 Enable the auto-whitelisting functionality
    #  MailScanner::Log::InfoLog("Enabling Message Content Procection SpamAssassin auto-whitelist functionality...");
    #  if ($SAversion<3) {
    #    require Mail::SpamAssassin::DBBasedAddrList;
    #    # create a factory for the persistent address list
    #    my $addrlistfactory = Mail::SpamAssassin::DBBasedAddrList->new();
    #    $MailScanner::MCP::SAspamtest->set_persistent_address_list_factory
    #                                                    ($addrlistfactory);
    #  }
    #}

    # If the Bayes database lock file is still present due to the process
    # being killed, we must delete it. The difficult bit is finding it.
    # Wrap this in an eval for those using old versions of SA which don't
    # have the Bayes engine at all.
    eval {
      my $t = $MailScanner::MCP::SAspamtest;
      $MailScanner::MCP::SABayesLock = $t->sed_path($t->{conf}->{bayes_path}) .
                                      '.lock';
    };

    #print STDERR "Bayes lock is at $MailScanner::MCP::SABayesLock\n";
    # JKF 7/1/2002 Commented out due to it causing false positives
    # JKF 7/6/2002 Now has a config switch
    # JKF 12/6/2002 Remember to read the prefs file
    #if (MailScanner::Config::Value('compilespamassassinonce')) {
    # Saves me recompiling all the modules every time

    # Need to delete lock file now or compile_now may never return
    unlink $MailScanner::MCP::SABayesLock;
    #$MailScanner::MCP::SAspamtest->compile_now(0);
    # Apparently this doesn't do anything after compile_now()
    $MailScanner::MCP::SAspamtest->read_scoreonly_config($prefs);
  }
}


# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  bless $this, $type;
  return $this;
}

# Do the SpamAssassin checks on the passed in message
sub Checks {
  my $message = shift;

  my($dfhandle);
  my($dfilename, $dfile, @WholeMessage, $SAResult, $SAHitList);
  my($HighScoring, $SAScore, $maxsize);

  # Bail out and fake a miss if too many consecutive SA checks failed
  my $maxfailures = MailScanner::Config::Value('mcpmaxspamassassintimeouts');

  # If we get maxfailures consecutive timeouts, then disable the
  # SpamAssassin RBL checks in an attempt to get it working again.
  # If it continues to time out for another maxfailures consecutive
  # attempts, then disable it completely.
  if ($maxfailures>0) {
    if ($safailures>=2*$maxfailures) {
      return (0,0,
        sprintf(MailScanner::Config::LanguageValue($message,'mcpsadisabled'),
        2*$maxfailures), 0);
    } elsif ($safailures>$maxfailures) {
      $MailScanner::MCP::SAspamtest->{conf}->{skip_rbl_checks} = 1;
    } elsif ($safailures==$maxfailures) {
      $MailScanner::MCP::SAspamtest->{conf}->{skip_rbl_checks} = 1;
      MailScanner::Log::WarnLog("Disabling Message Content Protection SpamAssassin RBL checks");
    }
  }

  #return (0,0,
  #  sprintf(MailScanner::Config::LanguageValue($message,'sadisabled'),
  #          $maxfailures), 0)
  #  if $maxfailures>0 &&
  #     $safailures>=$maxfailures;

  # Also only do this if the message is reasonably small.
  # LEOH 26/03/2003 We do not always have dpath file, so we ask to 
  #                 the store module the size
  # $dsize = (stat($message->{store}{dpath}))[7];
  #$dsize = $message->{store}->dsize();
  #return (0,0, MailScanner::Config::LanguageValue($message,'satoolarge'), 0)
  #  if $dsize > MailScanner::Config::Value('maxspamassassinsize');
  $maxsize = MailScanner::Config::Value('mcpmaxspamassassinsize');

  # Construct the array of lines of the header and body of the message
  # JKF 30/1/2002 Don't chop off the line endings. Thanks to Andreas Piper
  #               for this.
  #my $h;
  #foreach $h (@{$message->{headers}}) {
  #  push @WholeMessage, $h . "\n";
  #}
  my $fromheader = MailScanner::Config::Value('envfromheader', $message);
  $fromheader =~ s/:$//;
  push(@WholeMessage, $fromheader . ': ' . $message->{from} . "\n")
    if $fromheader;

  @WholeMessage = $global::MS->{mta}->OriginalMsgHeaders($message, "\n");
  #print STDERR "Headers are : " . join(', ', @WholeMessage) . "\n";
  return (0,0, MailScanner::Config::LanguageValue($message, 'mcpsanoheaders'), 0)
    unless @WholeMessage;

  push(@WholeMessage, "\n");
  $message->{store}->ReadBody(\@WholeMessage, $maxsize);

  #print STDERR "Whole message is this:\n";
  #print STDERR "----------------------\n";
  #print STDERR @WholeMessage;
  #print STDERR "---------------\n";
  #print STDERR "End of message.\n";

  # Now construct the SpamAssassin object for version < 3
  my $spammail;
  $spammail = Mail::SpamAssassin::NoMailAudit->new('data'=>\@WholeMessage)
    if $SAversion < 3;

  #print STDERR "NoMailAudit thinks the message is this:\n";
  #print STDERR "---------------------------------------\n";
  #print STDERR $spammail->as_string();
  #print STDERR "---------------\n";
  #print STDERR "End of message.\n";

  # Test it for spam-ness
  #print STDERR "About to try MCP\n";
  if ($SAversion<3) {
    ($SAResult, $HighScoring, $SAHitList, $SAScore) 
      = SAForkAndTest($MailScanner::MCP::SAspamtest, $spammail, $message);
  } else {
    ($SAResult, $HighScoring, $SAHitList, $SAScore) 
      = SAForkAndTest($MailScanner::MCP::SAspamtest, \@WholeMessage, $message);
  }

  #print STDERR "Done MCP call\n";
  #MailScanner::Log::WarnLog("Done SAForkAndTest");
  #print STDERR "SAResult = $SAResult\nHighScoring = $HighScoring\n" .
  #             "SAHitList = $SAHitList\n";
  return ($SAResult, $HighScoring, $SAHitList, $SAScore);
}

# Fork and test with SpamAssassin. This implements a timeout on the execution
# of the SpamAssassin checks, which occasionally take a *very* long time to
# terminate due to regular expression backtracking and other nasties.
sub SAForkAndTest {
  my($Test, $Mail, $Message) = @_;

  my($pipe);
  my($SAHitList, $SAHits, $SAReqHits, $IsItSpam, $IsItHighScore);
  my($HighScoreVal, $pid2delete, $IncludeScores);
  my $PipeReturn = 0;
  my $Error = 0;

  $IncludeScores = MailScanner::Config::Value('mcplistsascores', $Message);

  $pipe = new IO::Pipe
    or MailScanner::Log::DieLog('Failed to create pipe, %s, try reducing ' .
                  'the maximum number of unscanned messages per batch', $!);
  #$readerfh = new FileHandle;
  #$writerfh = new FileHandle;
  #($readerfh, $writerfh) = FileHandle::pipe;

  my $pid = fork();
  die "Can't fork: $!" unless defined($pid);

  if ($pid == 0) {
    # In the child
    my($spamness, $SAResult, $HitList, @HitNames, $Hit);
    $pipe->writer();
    #close($readerfh);
    #POSIX::setsid();
    #select($writerfh);
    #$| = 1; # Line buffering, not block buffering
    $pipe->autoflush();
    # Do the actual tests and work out the integer result
    if ($SAversion < 3) {
      $spamness = $Test->check($Mail);
    } else {
      my $mail = $Test->parse($Mail, 1);
      $spamness = $Test->check($mail);
    }
    print $pipe ($SAversion<3?$spamness->get_hits():$spamness->get_score())
                . "\n";
    $HitList  = $spamness->get_names_of_tests_hit();
    if ($IncludeScores) {
      @HitNames = split(/\s*,\s*/, $HitList);
      $HitList  = "";
      foreach $Hit (@HitNames) {
        $HitList .= ($HitList?', ':'') . $Hit . ' ' .
                    sprintf("%1.2f", $spamness->{conf}->{scores}->{$Hit});
      }
    }
    print $pipe $HitList . "\n";
    $spamness->finish();
    $pipe->close();
    $pipe = undef;
    exit 0; # $SAResult;
  }

  eval {
    $pipe->reader();
    local $SIG{ALRM} = sub { die "Command Timed Out" };
    alarm MailScanner::Config::Value('mcpspamassassintimeout');
    $SAHits = <$pipe>;
    #print STDERR "Read SAHits = $SAHits " . scalar(localtime) . "\n";
    $SAHitList = <$pipe>;
    #print STDERR "Read SAHitList = $SAHitList " . scalar(localtime) . "\n";
    # Not sure if next 2 lines should be this way round...
    waitpid $pid, 0;
    $pipe->close();
    $PipeReturn = $?;
    alarm 0;
    $pid = 0;
    chomp $SAHits;
    chomp $SAHitList;
    $SAHits = $SAHits + 0.0;
    $safailures = 0; # This was successful so zero counter
  };
  alarm 0;
  # Workaround for bug in perl shipped with Solaris 9,
  # it doesn't unblock the SIGALRM after handling it.
  eval {
    my $unblockset = POSIX::SigSet->new(SIGALRM);
    sigprocmask(SIG_UNBLOCK, $unblockset)
      or die "Could not unblock alarm: $!\n";
  };

  # Construct the hit-list including the score we got.
  $SAReqHits = MailScanner::Config::Value('mcpreqspamassassinscore',$Message)+0.0;
  $SAHitList = MailScanner::Config::LanguageValue($Message, 'score') . '=' .
               ($SAHits+0.0) . ', ' .
               MailScanner::Config::LanguageValue($Message, 'required') .' ' .
               $SAReqHits . ($SAHitList?", $SAHitList":'');

  # Note to self: I only close the KID in the parent, not in the child.

  # Catch failures other than the alarm
  if ($@ and $@ !~ /Command Timed Out/) {
    MailScanner::Log::DieLog("Message Content Protection SpamAssassin failed with real error: $@");
    $Error = 1;
  }

  # In which case any failures must be the alarm
  #if ($@ or $pid>0) {
  if ($pid>0) {
    $pid2delete = $pid;
    my $maxfailures = MailScanner::Config::Value('mcpmaxspamassassintimeouts');
    # Increment the "consecutive" counter
    $safailures++;
    if ($maxfailures>0) {
      if ($safailures>$maxfailures) {
        MailScanner::Log::WarnLog("Message Content Protection SpamAssassin timed out (with no RBL" .
                     " checks) and was killed, consecutive failure " .
                     $safailures . " of " . $maxfailures*2);
      } else {
        MailScanner::Log::WarnLog("Message Content Protection SpamAssassin timed out and was killed, " .
                     "consecutive failure " . $safailures .
                     " of " . $maxfailures);
      }
    } else {
      MailScanner::Log::WarnLog("Message Content Protection SpamAssassin timed out and was killed");
    }

    # Make the report say SA was killed
    $SAHitList = MailScanner::Config::LanguageValue($Message, 'mcpsatimedout');
    $SAHits = 0;
    $Error  = 1;

    # Kill the running child process
    my($i);
    kill -15, $pid;
    # Wait for up to 10 seconds for it to die
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

    # As the child process must now be dead, remove the Bayes database
    # lock file if it exists. Only delete the lock file if it mentions
    # $pid2delete in its contents.
    if ($pid2delete && $MailScanner::MCP::SABayesLock) {
      my $lockfh = new FileHandle;
      if ($lockfh->open($MailScanner::MCP::SABayesLock)) {
        my $line = $lockfh->getline();
        chomp $line;
        $line =~ /(\d+)$/;
        my $pidinlock = $1;
        if ($pidinlock =~ /$pid2delete/) {
          unlink $MailScanner::MCP::SABayesLock;
          MailScanner::Log::InfoLog("Delete bayes lockfile for %s",$pid2delete);
        }
        $lockfh->close();
      }
    }
    #unlink $MailScanner::MCP::SABayesLock if $MailScanner::MCP::SABayesLock;
  }
  #MailScanner::Log::WarnLog("8 PID is $pid");

  # The return from the pipe is a measure of how spammy it was
  MailScanner::Log::DebugLog("Message Content Protection SpamAssassin returned $PipeReturn");

  # SpamAssassin is known to play with the umask
  umask 0077; # Safety net

  # Handle the case when there was an error
  if ($Error) {
    MailScanner::Log::DebugLog("Message Content Protection SpamAssassin check failed");
    $SAHits = MailScanner::Config::Value('mcperrorscore',$Message);
  }

  #$PipeReturn = $PipeReturn>>8;
  $IsItSpam = ($SAHits && $SAHits>=$SAReqHits)?1:0;
  $HighScoreVal = MailScanner::Config::Value('mcphighspamassassinscore',$Message);
  $IsItHighScore = ($SAHits && $HighScoreVal>0 && $SAHits>=$HighScoreVal)?1:0;
  return ($IsItSpam, $IsItHighScore, $SAHitList, $SAHits);
}

1;
