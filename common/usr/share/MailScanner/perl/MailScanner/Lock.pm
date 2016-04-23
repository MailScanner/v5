#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: Lock.pm 5098 2011-06-25 20:11:06Z sysjkf $
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

# Provide functions to deal with opening + locking spool files

package MailScanner::Lock;

use strict;
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(:unistd_h :errno_h);
#use MailScanner::Log;

use vars qw($FLOCK_STRUCT);

my $have_module;
my $LockType;

sub ReportLockType {
  return $LockType;
}

# Run-time initialisation

sub initialise {

  eval {
      require MailScanner::Fcntl;
      import MailScanner::Fcntl (@MailScanner::Fcntl::EXPORT,
                                 @MailScanner::Fcntl::EXPORT_OK);
      1;
  };

  $have_module = ($@ eq ""?1:0);

  # Determine locktype to use
  $LockType = (MailScanner::Config::Value('locktype'))?
    MailScanner::Config::Value('locktype') : $global::MS->{mta}->{LockType};

  #print STDERR "Debug = " . MailScanner::Config::Value('debug') . "\n";
  #print STDERR "Config Value = " . MailScanner::Config::Value('locktype') . "\n";
  #print STDERR "Global = " . $global::MS->{mta}->{LockType} . "\n";
  #print STDERR "Lock Type = $LockType\n";

  MailScanner::Log::DebugLog("lock.pl sees Config  LockType =  " .
                             $LockType);
  #MailScanner::Log::DebugLog("lock.pl sees MTA::LockType =  ".$MTA::LockType);
  MailScanner::Log::DebugLog("lock.pl sees have_module =  ".$have_module);

  # module has bugs
  $LockType =~ /posix/ and $have_module and $LockType = "module";

  MailScanner::Log::InfoLog("Using locktype = " . $LockType);


  # Note that in IEEE Std 1003.1-2001,
  # "The interaction between fcntl() and lockf() locks is unspecified."
  #
  # (bother)
  #
  # And we shouldn't really call these "posix" locks, as although they are
  # specified in POSIX, there are two possible types, which may or may not
  # be the same. DOH!

  # Determine correct struct_flock to use at include time

  # HORRIBLY HARDWIRED
  # would like to "use File::lockf" but that would make
  # installation harder. And lockf isn't guaranteed to
  # do the same thing as fcntl :(
  #
  # CPAN File::Lock also appears to be broken (doesn't build, then when
  # built, doesn't pass it's own tests - including segfaulting)
  #
  # So I'll do it myself.

  if ($LockType =~ /posix/i) {
    
    for ($^O) {
	
	# $^O returns:
	#  Linux: "linux"
	#  OpenBSD: "openbsd"
	#  Solaris: "solaris"
	#  SunOS4: "sunos"
	#  AIX: "aix"
	#  IRIX: "irix"
	#

	if (/bsd/) {

	    #MailScanner::Log::InfoLog("Creating hardcoded struct_flock subroutine for $^O (BSD-type)");

	    # from "man fcntl" and /usr/include/sys/fcntl.h on OBSD 2.7:
	    #     struct flock {
	    #             off_t   l_start;        /* starting offset */
	    #             off_t   l_len;          /* len = 0 means until end of file */
	    #             pid_t   l_pid;          /* lock owner */
	    #             short   l_type;         /* lock type: read/write, etc. */
	    #             short   l_whence;       /* type of l_start */
	    #     };
	    #
	    # FreeBSD exim.tulsaconnect.com 4.5-RELEASE FreeBSD 4.5-RELEASE #0: Sun May
	    # 19 23:53:40 CDT 2002
	    #
	    # from /usr/include/sys/fcntl.h:
	    #
	    # /*
	    #  * Advisory file segment locking data type -
	    #  * information passed to system by user
	    #  */
	    # struct flock {
	    #         off_t   l_start;        /* starting offset */
	    #         off_t   l_len;          /* len = 0 means until end of file */
	    #         pid_t   l_pid;          /* lock owner */
	    #         short   l_type;         /* lock type: read/write, etc. */
	    #         short   l_whence;       /* type of l_start */
	    # };
	    #
	    # FreeBSD off_t is typedef'd to _BSD_OFF_T_ which is in turn __int64_t
	    #

	    eval <<'__EOD';
	    
	    # XXX: should be Q not LL but
	    # "Quads are available only if your system supports 64-bit
	    # integer values _and_ if Perl has been compiled to support those.
	    # Causes a fatal error otherwise."
	    #
	    $FLOCK_STRUCT = 'LL LL L l s';
	    
	    sub struct_flock {
		my ($xxstart, $start, $xxlen, $len, $pid, $type, $whence);
		if (wantarray) {
		    ($xxstart, $start, $xxlen, $len, $pid, $type, $whence) =
		      unpack($FLOCK_STRUCT, $_[0]);
		    return ($type, $whence, $start, $len, $pid);
		} else {
		    ($type, $whence, $start, $len, $pid) = @_;
		    ($xxstart, $xxlen) = (0,0);
		    return pack($FLOCK_STRUCT, $xxstart, $start, $xxlen, $len, $pid, $type, $whence);
		}
	    }
	    
__EOD
	    if ($@ ne "") {
		MailScanner::Log::DieLog("Unable to create struct_flock subroutine: $@");
	    }
	    next;
	}
	
        if ($_ eq 'linux') {

	    #MailScanner::Log::InfoLog("Creating hardcoded struct_flock subroutine for $^O (Linux-type)");

	    # from linux 2.2 /usr/include/asm/fcntl.h:
	    #	struct flock {
	    #        short l_type;
	    #        short l_whence;
	    #        off_t l_start;
	    #        off_t l_len;
	    #        pid_t l_pid;
	    #	};
	    #
	    # size of off_t appears to depend on whether we've got large file support etc. ugh.
	    #
	    # was previously using ssx32 to pack and sslls to unpack
	    #
	    
	    eval <<'__EOD';

	    $FLOCK_STRUCT = 's s LL LL I';

	    sub struct_flock {
		my ($start, $len, $pid, $type, $whence);
		if (wantarray) {
                    # Interpreting a returned struct
		    ($type, $whence, $start, $len, $pid) =
		      unpack($FLOCK_STRUCT, $_[0]);
		    return ($type, $whence, $start, $len, $pid);
		} else {
                    # Building a struct
		    ($type, $whence, $start, $len, $pid) = @_;
		    return pack($FLOCK_STRUCT, $type, $whence, $start, $len, $pid);
		}
	    }

__EOD
	    if ($@ ne "") {
		MailScanner::Log::DieLog("Unable to create struct_flock subroutine: $@");
	    }
	    next;
	}

        if (/solaris|irix|aix/) {

	    #MailScanner::Log::InfoLog("Creating hardcoded struct_flock subroutine for $^O (misc-type)");

	    # from solaris 2.7 /usr/include/sys/fcntl.h:
	    #	/* regular version, for both small and large file compilation environment */
	    #	typedef struct flock {
	    #		short   l_type;
	    #		short   l_whence;
	    #		off_t   l_start;
	    #		off_t   l_len;          /* len == 0 means until end of file */
	    #		int     l_sysid;
	    #		pid_t   l_pid;
	    #		long    l_pad[4];               /* reserve area */
	    #	} flock_t;
	    #
	    # and:
	    #	/* transitional large file interface version */
	    #
	    #	#if     defined(_LARGEFILE64_SOURCE)
	    #
	    #	typedef struct flock64 {
	    #		short   l_type;
	    #		short   l_whence;
	    #		off64_t l_start;
	    #		off64_t l_len;          /* len == 0 means until end of file */
	    #		int     l_sysid;
	    #		pid_t   l_pid;
	    #		long    l_pad[4];               /* reserve area */
	    #	} flock64_t;
	    #
	    # and:
	    #	/* SVr3 flock type; needed for rfs across the wire compatibility */
	    #	typedef struct o_flock {
	    #		int16_t l_type;
	    #		int16_t l_whence;
	    #		int32_t l_start;
	    #		int32_t l_len;          /* len == 0 means until end of file */
	    #		int16_t l_sysid;
	    #		int16_t l_pid;
	    #	} o_flock_t;
	    #
	    # so even thought that one's not used in solaris any more, I guess there'll
	    # be systems "out there" that use it.
	    #
	    #
	    # From IRIX 5.3 man pages:
	    # The structure flock describes a file lock.  It includes the following
	    # members:
	    #
	    #  short   l_type;     /* Type of lock */
	    #  short   l_whence;   /* Flag for starting offset */
	    #  off_t   l_start;    /* Relative offset in bytes */
	    #  off_t   l_len;      /* Size; if 0 then until EOF */
	    #  long    l_sysid;    /* Returned with F_GETLK */
	    #  pid_t   l_pid;      /* Returned with F_GETLK */
	    #
	    #
	    # The structure flock64 describes a file lock for use on large files.  It
	    # includes the following members:
	    #
	    #  short   l_type;     /* Type of lock */
	    #  short   l_whence;   /* Flag for starting offset */
	    #  off64_t l_start;    /* Relative offset in bytes */
	    #  off64_t l_len;      /* Size; if 0 then until EOF */
	    #  long    l_sysid;    /* Returned with F_GETLK */
	    #  pid_t   l_pid;      /* Returned with F_GETLK */
	    #
	    # Apparently the 64-bit version is used with a different fcntl command
	    # (F_SETLK64 as opposed to F_SETLK).
	    #
	    #
	    # It seems that under AIX, a struct flock is:
	    # l_type, l_whence, l_start, l_len, l_sysid, l_pid, l_vfs
	    # Again, things vary depending on whether large file support is being
	    # used.
	    #

	    eval <<'__EOD';

	    # TEST THIS!
	    $FLOCK_STRUCT = 's s L L I I'; # ignore solaris' pad on the end

	    sub struct_flock {
		my ($type, $whence, $start, $len, $sysid, $pid);
		if (wantarray) {
		    ($type, $whence, $start, $len, $sysid, $pid) =
		      unpack($FLOCK_STRUCT, $_[0]);
		    return ($type, $whence, $start, $len, $pid);
		} else {
		    ($type, $whence, $start, $len, $pid) = @_;
		    $sysid = 0;
		    return pack($FLOCK_STRUCT, $type, $whence, $start, $len, $sysid, $pid);
		}
	    }

__EOD
	    if ($@ ne "") {
		MailScanner::Log::DieLog("Unable to create struct_flock subroutine: $@");
	    }
	    next;
	}
	
        MailScanner::Log::DieLog("1\n2\n3\n4\n5\nDon't know how to do fcntl locking on '$^O'\nPlease contact mailscanner authors.5\n4\n3\n2\n1");

    }
  }
}


# Open and lock a file.
#
# Pass in a filehandle, a filespec (including ">", "<", or
# whatever on the front), and (optionally) the type of lock
# you want - "r" or "s" for shared/read lock, or pretty much
# anything else (but "w" or "x" really) for exclusive/write
# lock.
#
# Lock type used (flock or fcntl/lockf/posix) depends on
# config. If you're using posix locks, then don't try asking
# for a write-lock on a file opened for reading - it'll fail
# with EBADF (Bad file descriptor).
#
# If $quiet is true, then don't print any warning.
#
sub openlock {
    my ($fh, $fn, $rw, $quiet) = @_;
    
    my ($struct_flock);

    defined $rw or $rw = ((substr($fn,0,1) eq '>')?"w":"r");
    $rw =~ /^[rs]/i or $rw = 'w';

    # Set umask every time as SpamAssassin might have reset it
    #umask 0077; # Now cleared up after SpamAssassin runs

    $fn =~ /^(.*)$/;
    $fn = $1;
    unless (open($fh, $fn)) { # TAINT
	MailScanner::Log::NoticeLog("Could not open file $fn: %s", $!)
          unless $quiet;
	return 0;
    }

    if ($LockType =~ /module/i) {
	#MailScanner::Log::DebugLog("Using module to lock $fn");
	MailScanner::Fcntl::setlk($fh, ($rw eq 'w' ? F_WRLCK : F_RDLCK)) == 0 and return 1;
    }
    elsif ($LockType =~ /posix/i) {
        # Added 3 zeroes for 'start, length, + pid',
        # otherwise pack was being called with undefined values -- nwp
	#MailScanner::Log::DebugLog("Using fcntl() to lock $fn");
	$struct_flock =  struct_flock(($rw eq 'w' ? F_WRLCK : F_RDLCK),0,0,0,0);
	fcntl($fh, F_SETLK, $struct_flock) and return 1;
    }
    elsif ($LockType =~ /flock/i) {
	#MailScanner::Log::DebugLog("Using flock() to lock $fn");
	flock($fh, ($rw eq 'w' ? LOCK_EX : LOCK_SH) + LOCK_NB) and return 1;
    }
    else {
	MailScanner::Log::DebugLog("Not locking spool file $fn");
	return 1;
    }

    close ($fh);

    if (($! == POSIX::EAGAIN) || ($! == POSIX::EACCES)) {
	MailScanner::Log::DebugLog("Failed to lock $fn: %s", $!)
          unless $quiet;
    }
    else {
	MailScanner::Log::NoticeLog("Failed to lock $fn with unexpected error: %s", $!);
    }

    return 0;
}


sub unlockclose {
    my ($fh) = @_;

    if ($LockType =~ /module/i) {
	MailScanner::Fcntl::setlk($fh, F_UNLCK);
    }
    elsif ($LockType =~ /posix/i) {
	fcntl($fh, F_SETLK, struct_flock(F_UNLCK,0,0,0,0));
    }
    elsif ($LockType =~ /flock/i) {
	flock($fh, LOCK_UN);
    }
# else {
#   default - do nothing, as we didn't lock it in the first place
# }

    close ($fh);
    return 1;
}


1;
