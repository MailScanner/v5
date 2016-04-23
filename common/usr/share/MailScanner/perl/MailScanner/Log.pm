#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: Log.pm 4709 2009-03-28 10:06:21Z sysjkf $
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

###########################################################
# Syslog library calls
###########################################################

package MailScanner::Log;

use strict;
use Sys::Syslog;
use Carp;
use vars qw($LogType $Banner $WarningsOnly);

# Used to say 'syslog' but for the MailScanner.conf syntax checking code I
# need the default log output to be stderr, as I don't know enough to start
# the logging properly.
$LogType |= 'syslog'; #'stderr';
$WarningsOnly = 0;

sub Configure {
  my($banner,$type) = @_;

  $Banner = $banner?$banner:undef;
  $LogType = $type?$type:'syslog';
}

sub WarningsOnly {
  $WarningsOnly = 1;
}

sub Start {
  my($name, $facility, $logsock) = @_;

  $logsock =~ s/\W//g; # Take out all the junk

  # These are needed later if we need to restart the logging connection
  # due to a SIGPIPE.
  $MailScanner::Log::name = $name;
  $MailScanner::Log::facility = $facility;
  $MailScanner::Log::logsock = $logsock;

  if ($LogType eq 'syslog') {
    # Do this in an eval so it can fail quietly if setlogsock
    # is not supported in the installed version of Sys::Syslog
    #eval { $SIG{'__DIE__'} = 'IGNORE';
    #       Sys::Syslog::setlogsock('unix');
    #     }; # Doesn't need syslogd -r
    #$SIG{'__DIE__'} = 'DEFAULT';
    # This was too simple and didn't work on some Solaris and IRIX systems
    #eval { Sys::Syslog::setlogsock('unix'); }; # This may fail!
    if ($logsock eq '') {
      if ($^O =~ /solaris|sunos|irix/i) {
        $logsock = 'udp';
      } else {
        $logsock = 'unix';
      }
    }
    $MailScanner::Log::logsock = $logsock;
    print STDERR "Trying to setlogsock($logsock)\n" unless $WarningsOnly;
    eval { Sys::Syslog::setlogsock($logsock); };
    eval { Sys::Syslog::openlog($name, 'pid, nowait', $facility); };
  }
  
  if (defined $Banner) {
    InfoLog($Banner);
  }
}

# Re-open the logging, used after SA::initialise has nobbled it due to
# nasty Razor code.
sub Reset {
  if ($LogType eq 'syslog') {
    eval { Sys::Syslog::setlogsock($MailScanner::Log::logsock); };
    eval { Sys::Syslog::openlog($MailScanner::Log::name, 'pid, nowait',
                                $MailScanner::Log::facility); };
  }
}

sub Stop {
    Sys::Syslog::closelog() if $LogType eq 'syslog';
}

sub DieLog {
  # closelog changes $! in @_
  my(@x) = @_;

  my $logmessage = sprintf shift @x, @x;

  LogText($logmessage, 'err');

  Sys::Syslog::closelog() if $LogType eq 'syslog';

  croak "$logmessage";
}

sub WarnLog {
  my(@x) = @_;
  my $logmessage = sprintf shift @x, @x;

  LogText($logmessage, 'warning');

  carp $logmessage if $LogType eq 'stderr';
}

sub NoticeLog {
  my(@x) = @_;
  my $logmessage = sprintf shift @x, @x;

  unless ($WarningsOnly) {
    LogText($logmessage, 'notice');

    print STDERR "$logmessage\n" if $LogType eq 'stderr';
  }
}

sub InfoLog {
  my(@x) = @_;
  my $logmessage = sprintf shift @x, @x;

  unless ($WarningsOnly) {
    LogText($logmessage, 'info');

    print STDERR "$logmessage\n" if $LogType eq 'stderr';
  }
}

sub DebugLog {
  my(@x) = @_;
  if (MailScanner::Config::Value('debug')) {
    my $logmessage = sprintf shift @x, @x;

    LogText($logmessage, 'debug');

    print STDERR "$logmessage\n" if $LogType eq 'stderr';
  }
}

sub LogText {
  my($logmessage, $level) = @_;

  return unless $LogType eq 'syslog';

  #my $old = $SIG{'PIPE'};
  #$SIG{'PIPE'} = sub { $MailScanner::Log::SIGPIPE_RECEIVED++; };

  # Force use of 8-bit characters, UTF16 breaks syslog badly.
  use bytes;

  foreach(split /\n/,$logmessage) {
    s/%/%%/g;
    eval { Sys::Syslog::syslog($level, $_) if $_ ne "" };

    ## If we got a SIGPIPE then something broke in the logging socket.
    ## So try to open a new one and use that from now on instead.
    #if ($MailScanner::Log::SIGPIPE_RECEIVED) {
    #  # SIGPIPE received while trying to log. This probably means they
    #  # are using syslog-ng and it was hupped by a log-rolling script.
    #  # Close and re-open our syslog connection and have another go.
    #  Sys::Syslog::closelog();
    #  eval { Sys::Syslog::setlogsock($MailScanner::Log::logsock); }; #may fail!
    #  Sys::Syslog::openlog($MailScanner::Log::name, 'pid, nowait',
    #                       $MailScanner::Log::facility);
    #  #Sys::Syslog::syslog($level, "SIGPIPE received - trying new log socket");
    #  Sys::Syslog::syslog($level, $_);
    #  # Whinge is logging is still broken
    #  warn "MailScanner logging failure, multiple SIGPIPEs received"
    #    if $MailScanner::Log::SIGPIPE_RECEIVED > 1;
    #  $MailScanner::Log::SIGPIPE_RECEIVED = 0;
    #}
  }

  no bytes;

  # Reset old SIGPIPE handler
  #$SIG{'PIPE'} = $old if defined($old);
}

1;
