#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: ZMRouterDirHash.pm 2967 2005-03-23 12:03:01Z jkf $
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
#   TheCustomConfig functions contained in this file are
#   Copyright (C) 2004 Pert Consultores
#   Some parts are taken from Julian Field's copyrighted MailScanner code
#
#   The authors (Leonardo Helman & Mariano Absatz) can be contacted
#   by email at
#      MailScanner-devel@pert.com.ar
#
#

package MailScanner::CustomConfig;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

package MailScanner::CustomConfig::ZMRouterDirHash;
use vars qw($VERSION);

### The subpackage version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 2967 $, 10;

package MailScanner::CustomConfig;

################## READ HERE #####################
# ZMailer only: this routines allow you to set ROUTERDIRHASH=1
# in your zmailer.conf file. This will make smtpserver and router
# use a one level subdir hash within the router queue.
# When you insert MailScanner between smtpserver view of the
# router queue and router view of the router queue, you 
# have to preserve the use of the subdirectories in both.
#
# MailScanner allows you to put a 'glob' in MailScanner.conf
# for the 'Incoming Queue Dir' setting. However, you can't do
# that for 'Outgoing Queue Setting'.
#
# If you want MailScanner to distribute its output queue into
# several directories, you can use these functions.
#
# Typical use requires that you set (in MailScanner.conf)
# the following settings:
# Incoming Queue Dir = /var/spool/postoffice-incoming/router/?
# Outgoing Queue Dir = &ChooseZMOutQueueDir("/var/spool/postoffice/router/?")
# or something like:
# Outgoing Queue Dir = &ChooseZMOutQueueDir("dir1","dir2")
# or any valid perl syntax function parameter.
#
# This latter setting is a glob the routines will use to
# find all possible output directories (you can put more than 
# one directory name or glob separated by commas).
#
# &ChooseZMOutQueueDir will be called every time MailScanner
# needs to know the output queue directory and it will return
# a random directory from the ones specified.
#
# All the directories _MUST_ be in the same filesystem and
# in the same filesystem as the 'Input Queue Dir'.


my @ZMOutQueueDirs=();
sub InitChooseZMOutQueueDir {
  @ZMOutQueueDirs=@_;

  MailScanner::Log::InfoLog("Initializing ChooseZMOutQueueDir Version %s...",
                $MailScanner::CustomConfig::ZMRouterDirHash::VERSION);

  my @inqdirs = @{MailScanner::Config::Value('inqueuedir')};
  my $inqdir = shift @inqdirs;

  chdir($inqdir);
  my @instat;
  my @outstat;
  my $indevice;
  my $outdevice;
  @instat = stat('.');
  $indevice = $instat[0];

  my @aux1=@ZMOutQueueDirs;
  my @aux2=();
  @ZMOutQueueDirs=();
  # first, expand globs
  for (@aux1) {
    push @aux2, ( /[\*\?\{\[\~]/ ) ? glob($_) : $_;
  }
  # Let's do some error checking.
  # We prefer to simply ignore unusable values, but you
  # can do s/WarnLog/DieLog/ here and abort if there's any error.
  for (@aux2) {
    if( ! -d $_ ) {
      MailScanner::Log::WarnLog("Configured ZM Output Queue Dir " .
                     "%s is not a directory. Ignored." , $_);
      next;
    }
    if (! chdir ($_)) {
      MailScanner::Log::WarnLog("Error accessing configured ZM Output " .
                     "Queue Dir %s: %s. Out queue dir ignored.", $_,$!);
      next;
    }
    @outstat = stat('.');
    $outdevice = $outstat[0];
    if ( $outdevice != $indevice ) {
      MailScanner::Log::WarnLog("Configured ZM Output Queue Dir " .
                     "%s is not in the same filesystem as Input Queue " .
                     "Dir %s. Out queue dir ignored." , $_,$inqdir);
      next;
    }
    push @ZMOutQueueDirs,$_;
  }
  unless( @ZMOutQueueDirs ) {
    MailScanner::Log::DieLog("ZMOutQueueDirs is empty. No Output Queue Dir left.");
  }
  MailScanner::Log::InfoLog("ChooseZMOutQueueDir initialization complete. " .
                    "Got %d directories.",$#ZMOutQueueDirs+1);
  return;
}

sub EndChooseZMOutQueueDir {
  # No shutdown code needed here at all.
  return;
}


sub ChooseZMOutQueueDir {
  # return a random Output Queue Dir
  return $ZMOutQueueDirs[rand( int( @ZMOutQueueDirs ) ) ];
}



1;


