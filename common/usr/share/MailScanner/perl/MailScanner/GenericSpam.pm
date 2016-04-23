#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: GenericSpam.pm 3116 2005-07-11 20:16:13Z jkf $
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

package MailScanner::GenericSpam;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s
#use English; # Needed for $PERL_VERSION to work in all versions of Perl

use IO::Pipe;
use POSIX qw(:signal_h); # For Solaris 9 SIG bug workaround
# Don't do this any more as SpamAssassin prefers to do it itself
# use AnyDBM_File; # Doing this here keeps SpamAssassin quiet

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 3116 $, 10;

# Attributes are
#
#

my @GSsuccessqueue;      # queue of failure history
my $GSsuccessqsum;       # current sum of history queue

sub initialise {

  # Initialise the class variables
  @GSsuccessqueue = ();
  $GSsuccessqsum  = 0;
}


# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  bless $this, $type;
  return $this;
}

# Do the Generic Spam checks on the passed in message
sub Checks {
  my($message) = @_;

  my(@WholeMessage, $scanner, $maxsize);

  #print STDERR "Doing Generic Spam Checks\n";
  # If they aren't using the generic spam scanner, bail out
  $scanner = MailScanner::Config::Value('gsscanner', $message);
  #return 0 unless $scanner;

  # Bail out and fake a miss if too many consecutive GS checks failed
  my $maxfailures = MailScanner::Config::Value('maxgstimeouts');

  # If we get maxfailures consecutive timeouts, then disable the
  # SpamAssassin RBL checks in an attempt to get it working again.
  # If it continues to time out for another maxfailures consecutive
  # attempts, then disable it completely.
  if ($maxfailures>0 && $GSsuccessqsum>=$maxfailures) {
      return (0,0,
        sprintf(MailScanner::Config::LanguageValue($message,'gsdisabled'),
        $maxfailures), 0);
  }

  $maxsize = MailScanner::Config::Value('maxgssize');

  push(@WholeMessage, $global::MS->{mta}->OriginalMsgHeaders($message, "\n"));
  #print STDERR "Headers are : " . join(', ', @WholeMessage) . "\n";
  push(@WholeMessage, "\n");
  $message->{store}->ReadBody(\@WholeMessage, $maxsize);

  my($GenericSpamResult, $GenericSpamReport);
  $GenericSpamResult = 0;
  $GenericSpamReport = "";
  ($GenericSpamResult, $GenericSpamReport) =
    GSForkAndTest($message, \@WholeMessage);
  return ($GenericSpamResult, $GenericSpamReport);
}

# Run the generic spam scanner, and capture the 2 lines of output
sub GSForkAndTest {
  my($Message, $Contents) = @_;

  my($pipe, $gsscore, $gsreport, $queuelength);
  my $PipeReturn = 0;

  $queuelength = MailScanner::Config::Value('gstimeoutlen', $Message);

  $pipe = new IO::Pipe
    or MailScanner::Log::DieLog('Failed to create pipe, %s, try reducing ' .
                  'the maximum number of unscanned messages per batch', $!);

  my $pid = fork();
  die "Can't fork: $!" unless defined($pid);

  if ($pid == 0) {
    # In the child
    $pipe->writer();
    $pipe->autoflush();
    my($gsscore, $gsreport);
    eval {
      #print STDERR "ClientIP = " . $Message->{clientip} . "\n";
      #print STDERR "From = " . $Message->{from} . "\n";
      #print STDERR "To = " . join(', ', @{$Message->{to}}) . "\n";
      #print STDERR "This is in the caller\n";

      ($gsscore, $gsreport) = MailScanner::CustomConfig::GenericSpamScanner(
       $Message->{clientip},
       $Message->{from},
       $Message->{to},
       $Contents);
    };
    
    $gsscore = $gsscore + 0.0;
    print $pipe "$gsscore\n";
    print $pipe $gsreport . "\n";
    $pipe->close();
    $pipe = undef;
    exit 0;
  }

  eval {
    $pipe->reader();
    local $SIG{ALRM} = sub { die "Command Timed Out" };
    alarm MailScanner::Config::Value('gstimeout');
    $gsscore = <$pipe>;
    $gsreport = <$pipe>;

    # Not sure if next 2 lines should be this way round...
    waitpid $pid, 0;
    $pipe->close();
    $PipeReturn = $?;
    alarm 0;
    $pid = 0;
    chomp $gsscore;
    chomp $gsreport;
    $gsscore = $gsscore + 0.0;
    # We got a result so store a success
    push @GSsuccessqueue, 0;
    # Roll the queue along one
    $GSsuccessqsum += (shift @GSsuccessqueue)?1:-1
          if @GSsuccessqueue>$queuelength;
    #print STDERR "Success: sum = $GSsuccessqsum\n";
    $GSsuccessqsum = 0 if $GSsuccessqsum<0;
  };
  alarm 0;
  # Workaround for bug in perl shipped with Solaris 9,
  # it doesn't unblock the SIGALRM after handling it.
  eval {
    my $unblockset = POSIX::SigSet->new(SIGALRM);
    sigprocmask(SIG_UNBLOCK, $unblockset)
      or die "Could not unblock alarm: $!\n";
  };

  # Note to self: I only close the KID in the parent, not in the child.

  # Catch failures other than the alarm
  MailScanner::Log::DieLog("Generic Spam Scanner failed with real error: $@")
    if $@ and $@ !~ /Command Timed Out/;

  # In which case any failures must be the alarm
  #if ($@ or $pid>0) {
  if ($pid>0) {
    my $maxfailures = MailScanner::Config::Value('maxgstimeouts');
    # Increment the "consecutive" counter
    #$safailures++;
    if ($maxfailures>0) {
      # We got a failure
      push @GSsuccessqueue, 1;
      $GSsuccessqsum++;
      # Roll the queue along one
      $GSsuccessqsum += (shift @GSsuccessqueue)?1:-1
        if @GSsuccessqueue>$queuelength;
      #print STDERR "Failure: sum = $GSsuccessqsum\n";
      $GSsuccessqsum = 0 if $GSsuccessqsum<0;

      if ($GSsuccessqsum>$maxfailures && @GSsuccessqueue>=$queuelength) {
        MailScanner::Log::WarnLog("Generic Spam Scanner timed out and was" .
          " killed, failure %d of %d", $GSsuccessqsum, $maxfailures);
      }
    } else {
      MailScanner::Log::WarnLog("Generic Spam Scanner timed out and was killed");
    }

    # Make the report say GS was killed
    $gsreport = MailScanner::Config::LanguageValue($Message, 'gstimedout');

    # Kill the running child process
    my($i);
    kill 15, $pid; # Was -15
    # Wait for up to 10 seconds for it to die
    for ($i=0; $i<5; $i++) {
      sleep 1;
      waitpid($pid, &POSIX::WNOHANG);
      ($pid=0),last unless kill(0, $pid);
      kill 15, $pid; # Was -15
    }
    # And if it didn't respond to 11 nice kills, we kill -9 it
    if ($pid) {
      kill 9, $pid; # Was -9
      waitpid $pid, 0; # 2.53
    }

  }
  #MailScanner::Log::WarnLog("8 PID is $pid");

  # Generic Spam Scanner may play with the umask
  umask 0077; # Safety net

  # The return from the pipe is a measure of how spammy it was
  MailScanner::Log::DebugLog("Generic Spam Scanner returned $PipeReturn");

  # The Generic Spam Scanner returned something interesting
  #print STDERR "Generic Spam Scanner points = $gsscore\n";
  #print STDERR "Generic Spam Scanner report = $gsreport\n";

  return ($gsscore, $gsreport);
}

1;

