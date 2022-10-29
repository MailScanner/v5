# $Id: PMilter.pm,v 1.28 2004/08/04 17:08:34 tvierling Exp $
#
# Copyright (c) 2002-2004 Todd Vierling <tv@pobox.com> <tv@duh.org>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of the author nor the names of contributors may be used
# to endorse or promote products derived from this software without specific
# prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package Sendmail::PMilter;

use 5.006;
use base Exporter;

use strict;
use warnings;

use Carp;
use Errno;
use IO::Select;
use POSIX;
use Sendmail::Milter 0.18; # get needed constants
use Socket;
use Symbol;
use UNIVERSAL;

our $VERSION = '1.00';
our $DEBUG = 0;

=pod

=head1 NAME

Sendmail::PMilter - Perl binding of Sendmail Milter protocol

=head1 SYNOPSIS

    use Sendmail::PMilter;

    my $milter = new Sendmail::PMilter;

    $milter->auto_setconn(NAME);
    $milter->register(NAME, { CALLBACKS }, FLAGS);
    $milter->main();

=head1 DESCRIPTION

Sendmail::PMilter is a mail filtering API implementing the Sendmail
milter protocol in pure Perl.  This allows Sendmail servers (and perhaps
other MTAs implementing milter) to filter and modify mail in transit
during the SMTP connection, all in Perl.

It should be noted that PMilter 0.90 and later is NOT compatible with
scripts written for PMilter 0.5 and earlier.  The API has been reworked
significantly, and the enhanced APIs and rule logic provided by PMilter
0.5 and earlier has been factored out for inclusion in a separate package
to be called Mail::Milter.

=head1 METHODS

=over 4

=cut

##### Symbols exported to the caller

my @smflags = qw(
	SMFIS_CONTINUE
	SMFIS_REJECT
	SMFIS_DISCARD
	SMFIS_ACCEPT
	SMFIS_TEMPFAIL

	SMFIF_ADDHDRS
	SMFIF_CHGBODY
	SMFIF_ADDRCPT
	SMFIF_DELRCPT
	SMFIF_CHGHDRS
	SMFIF_MODBODY
	SMFIF_QUARANTINE
	SMFIF_SETSENDER

	SMFI_V1_ACTS
	SMFI_V2_ACTS
	SMFI_CURR_ACTS
);
our @EXPORT_OK = (@smflags, qw(
	%DEFAULT_CALLBACKS
));
our %EXPORT_TAGS = ( all => [ @smflags ] );

use constant SMFIF_QUARANTINE	=> 0x20;
use constant SMFIF_SETSENDER	=> 0x40;

our $enable_setsender = 0;

##### Methods

sub new ($) {
	bless {}, shift;
}

=pod

=item get_max_interpreters()

Returns the maximum number of interpreters passed to C<main()>.  This is
only useful when called from within the dispatcher, as it is not set before
C<main()> is called.

=cut

sub get_max_interpreters ($) {
	my $this = shift;

	$this->{max_interpreters} || 0;
}

=pod

=item get_max_requests()

Returns the maximum number of requests per interpreter passed to C<main()>.  
This is only useful when called from within the dispatcher, as it is not set
before C<main()> is called.

=cut

sub get_max_requests ($) {
	my $this = shift;

	$this->{max_requests} || 0;
}

=pod

=item main([MAXCHILDREN[, MAXREQ]])

This is the last method called in the main block of a milter program.  If
successful, this call never returns; the protocol engine is launched and
begins accepting connections.

MAXCHILDREN (default 0, meaning unlimited) specifies the maximum number of
connections that may be serviced simultaneously.  If a connection arrives
with the number of active connections above this limit, the milter will
immediately return a temporary failure condition and close the connection.

MAXREQ (default 0, meaning unlimited) is the maximum number of requests that
a child may service before being recycled.  It is not guaranteed that the
interpreter will service this many requests, only that it will not go over
the limit.

Any callback which C<die>s will have its output sent to C<warn>, followed by
a clean shutdown of the milter connection.  To catch any warnings generated
by the callbacks, and any error messages caused by a C<die>, set
C<$SIG{__WARN__}> to a user-defined subroutine.  (See L<perlvar>.)

=cut

sub main ($;$$) {
	require Sendmail::PMilter::Context;

	my $this = shift;

	croak 'main: socket not bound' unless defined($this->{socket});
	croak 'main: callbacks not registered' unless defined($this->{callbacks});

	my $max_interpreters = shift;
	my $max_requests = shift;

	$this->{max_interpreters} = $max_interpreters if (defined($max_interpreters) && $max_interpreters !~ /\D/);
	$this->{max_requests} = $max_requests if (defined($max_requests) && $max_requests !~ /\D/);

	my $dispatcher = $this->{dispatcher};

	unless (defined($dispatcher)) {
		my $dispatcher_name = ($ENV{PMILTER_DISPATCHER} || 'postfork').'_dispatcher';
		$dispatcher = &{\&{qualify_to_ref($dispatcher_name, 'Sendmail::PMilter')}};
	}

	my $handler = sub {
		my $ctx = new Sendmail::PMilter::Context(shift, $this->{callbacks}, $this->{callback_flags});

		$ctx->main();
	};

	&$dispatcher($this, $this->{socket}, $handler);
	undef;
}

=pod

=item register(NAME, CALLBACKS[, FLAGS])

Sets up the main milter loop configuration.

NAME is the name of the milter.  For compatibility with the official
Sendmail::Milter distribution, this should be the same name as passed to
auto_getconn() or auto_setconn(), but this PMilter implementation does not
enforce this.

CALLBACKS is a hash reference containing one or more callback subroutines.  
If a callback is not named in this hashref, the caller's package will be
searched for subroutines named "CALLBACK_callback", where CALLBACK is the
name of the callback function.

FLAGS, if specified, is a bitmask of message modification actions (a bitwise
OR of the SMFIF_* constants, or SMFI_CURR_ACTS to ask for all capabilities)
that are requested by the callback object for use during message processing.  
If any bit is not set in this mask, its corresponding action will not be
allowed during message processing.

C<register()> must be called successfully exactly once.  If called a second
time, the previously registered callbacks will be erased.

Returns a true value on success, undef on failure.

=cut

sub register ($$$;$) {
	my $this = shift;
	$this->{name} = shift;

	carp 'register: no name supplied' unless defined($this->{name});
	carp 'register: passed ref as name argument' if ref($this->{name});

	my $callbacks = shift;
	my $pkg = caller;

	croak 'register: callbacks is undef' unless defined($callbacks);
	croak 'register: callbacks not hash ref' unless UNIVERSAL::isa($callbacks, 'HASH');

	# make internal copy, and convert to code references
	$callbacks = { %$callbacks };

	foreach my $cbname (keys %Sendmail::Milter::DEFAULT_CALLBACKS) {
		my $cb = $callbacks->{$cbname};

		if (defined($cb) && !UNIVERSAL::isa($cb, 'CODE')) {
			$cb = qualify_to_ref($cb, $pkg);
			if (exists(&$cb)) {
				$callbacks->{$cbname} = \&$cb;
			} else {
				delete $callbacks->{$cbname};
			}
		}
	}

	$this->{callbacks} = $callbacks;
	$this->{callback_flags} = shift || 0;
	1;
}

=pod

=item setconn(DESC)

Sets up the server socket with connection descriptor DESC.  This is
identical to the descriptor syntax used by the "X" milter configuration
lines in sendmail.cf (if using Sendmail).  This should be one of the
following:

=over 2

=item local:PATH

A local ("UNIX") socket on the filesystem, named PATH.  This has some smarts
that will auto-delete the pathname if it seems that the milter is not
currently running (but this currently contains a race condition that may not
be fixable; at worst, there could be two milters running with one never
receiving connections).

=item inet:PORT[@HOST]

An IPv4 socket, bound to address HOST (default INADDR_ANY), on port PORT.  
It is not recommended to open milter engines to the world, so the @HOST part
should be specified.

=item inet6:PORT[@HOST]

An IPv6 socket, bound to address HOST (default INADDR_ANY), on port PORT.  
This requires IPv6 support and the Perl INET6 package to be installed.
It is not recommended to open milter engines to the world, so the @HOST part
should be specified.

=back

Returns a true value on success, undef on failure.

=cut

sub setconn ($$) {
	my $this = shift;
	my $conn = shift;
	my $backlog = $this->{backlog} || 5;
	my $socket;

	croak "setconn: $conn: unspecified protocol"
		unless ($conn =~ /^([^:]+):([^:@]+)(?:@([^:@]+|\[[0-9a-f:\.]+\]))?$/);

	if ($1 eq 'local' || $1 eq 'unix') {
		require IO::Socket::UNIX;

		my $path = $2;
		my $addr = sockaddr_un($path);

		croak "setconn: $conn: path not absolute"
			unless ($path =~ m,^/,,);

		if (-e $path && ! -S $path) { # exists, not a socket
			$! = Errno::EEXIST;
		} else {
			$socket = IO::Socket::UNIX->new(Type => SOCK_STREAM);
		}

		# Some systems require you to unlink an orphaned inode.
		# There's a race condition here, but it's unfortunately
		# not easily fixable.  Using an END{} block doesn't
		# always work, and that's too wonky with fork() anyway.

		if (defined($socket) && !$socket->bind($addr)) {
			if ($socket->connect($addr)) {
				close $socket;
				undef $socket;
				$! = Errno::EADDRINUSE;
			} else {
				unlink $path; # race condition
				$socket->bind($addr) || undef $socket;
			}
		}

		if (defined($socket)) {
			$socket->listen($backlog) || croak "setconn: listen $conn: $!";
		}
	} elsif ($1 eq 'inet') {
		require IO::Socket::INET;

		$socket = IO::Socket::INET->new(
			Proto => 'tcp',
			ReuseAddr => 1,
			Listen => $backlog,
			LocalPort => $2,
			LocalAddr => $3
		);
	} elsif ($1 eq 'inet6') {
		require IO::Socket::INET6;

		$socket = IO::Socket::INET6->new(
			Proto => 'tcp',
			ReuseAddr => 1,
			Listen => $backlog,
			LocalPort => $2,
			LocalAddr => $3
		);
	} else {
		croak "setconn: $conn: unknown protocol";
	}

	if (defined($socket)) {
		$this->set_socket($socket);
	} else {
		carp "setconn: $conn: $!";
		undef;
	}
}

=pod

=item set_dispatcher(CODEREF)

Sets the dispatcher used to accept socket connections and hand them off to
the protocol engine.  This allows pluggable resource allocation so that the
milter script may use fork, threads, or any other such means of handling
milter connections.  See C<DISPATCHERS> below for more information.

The subroutine (code) reference will be called by C<main()> when the
listening socket object is prepared and ready to accept connections.  It
will be passed the arguments:

    MILTER, LSOCKET, HANDLER

MILTER is the milter object currently running.  LSOCKET is a listening
socket (an instance of C<IO::Socket>), upon which C<accept()> should be
called.  HANDLER is a subroutine reference which should be called, passing
the socket object returned by C<< LSOCKET->accept() >>.

Note that the dispatcher may also be set from one of the off-the-shelf
dispatchers noted in this document by setting the PMILTER_DISPATCHER
environment variable.  See C<DISPATCHERS>, below.

=cut

sub set_dispatcher($&) {
	my $this = shift;

	$this->{dispatcher} = shift;
	1;
}

=pod

=item set_listen(BACKLOG)

Set the socket listen backlog to BACKLOG.  The default is 5 connections if
not set explicitly by this method.  Only useful before calling C<main()>.

=cut

sub set_listen ($$) {
	my $this = shift;
	my $backlog = shift;

	croak 'set_listen: socket already bound' if defined($this->{socket});

	$this->{backlog} = $backlog;
	1;
}

=pod

=item set_socket(SOCKET)

Rather than calling C<setconn()>, this method may be called explicitly to
set the C<IO::Socket> instance used to accept inbound connections.

=cut

sub set_socket ($$) {
	my $this = shift;
	my $socket = shift;

	croak 'set_socket: socket already bound' if defined($this->{socket});
	croak 'set_socket: not an IO::Socket instance' unless UNIVERSAL::isa($socket, 'IO::Socket');

	$this->{socket} = $socket;
	1;
}

=pod

=back

=head1 SENDMAIL-SPECIFIC METHODS

The following methods are only useful if Sendmail is the MTA connecting to
this milter.  Other MTAs likely don't use Sendmail's configuration file, so
these methods would not be useful with them.

=over 4

=cut

=pod

=item auto_getconn(NAME[, CONFIG])

Returns the connection descriptor for milter NAME in Sendmail configuration
file CONFIG (default C</etc/mail/sendmail.cf> or whatever was set by
C<set_sendmail_cf()>).  This can then be passed to setconn(), below.

Returns a true value on success, undef on failure.

=cut

sub auto_getconn ($$;$) {
	my $this = shift;
	my $milter = shift || die "milter name not supplied\n";
	my $cf = shift || $this->get_sendmail_cf();
	local *CF;

	open(CF, '<'.$cf) || die "open $cf: $!";

	while (<CF>) {
		s/\s+$//; # also trims newlines

		s/^X([^,\s]+),\s*// || next;
		($milter eq $1) || next;

		while (s/^(.)=([^,\s]+)(,\s*|\Z)//) {
			if ($1 eq 'S') {
				close(CF);
				return $2;
			}
		}
	}

	close(CF);
	undef;
}

=pod

=item auto_setconn(NAME[, CONFIG])

Creates the server connection socket for milter NAME in Sendmail
configuration file CONFIG.

Essentially, does:

    $milter->setconn($milter->auto_getconn(NAME, CONFIG))

Returns a true value on success, undef on failure.

=cut

sub auto_setconn ($$;$) {
	my $this = shift;
	my $name = shift;
	my $conn = $this->auto_getconn($name, shift);

	if (defined($conn)) {
		$this->setconn($conn);
	} else {
		carp "auto_setconn: no connection for $name found";
		undef;
	}
}

=pod

=item get_sendmail_cf()

Returns the pathname of the Sendmail configuration file set by
C<set_sendmail_cf()>, else the default of C</etc/mail/sendmail.cf>.

=cut

sub get_sendmail_cf ($) {
	my $this = shift;

	$this->{sendmail_cf} || '/etc/mail/sendmail.cf';
}

=pod

=item get_sendmail_class(CLASS[, CONFIG])

Returns a list containing all members of the Sendmail class CLASS, in
Sendmail configuration file CONFIG (default C</etc/mail/sendmail.cf> or
whatever is set by C<set_sendmail_cf()>).  Typically this is used to look up
the entries in class "w", the local hostnames class.

=cut

sub get_sendmail_class ($$;$) {
	my $this = shift;
	my $class = shift;
	my $cf = shift || $this->get_sendmail_cf();
	my %entries;
	local *CF;

	open(CF, '<'.$cf) || croak "get_sendmail_class: open $cf: $!";

	while (<CF>) {
		s/\s+$//; # also trims newlines

		if (s/^C\s*$class\s*//) {
			foreach (split(/\s+/)) {
				$entries{$_} = 1;
			}
		} elsif (s/^F\s*$class\s*(-o)?\s*//) {
			my $required = !defined($1);
			local *I;

			croak "get_sendmail_class: class $class lookup resulted in pipe: $_" if (/^\|/);

			if (open(I, '<'.$_)) {
				while (<I>) {
					s/#.*$//;
					s/\s+$//;
					next if /^$/;
					$entries{$_} = 1;
				}
				close(I);
			} elsif ($required) {
				croak "get_sendmail_class: class $class lookup: $_: $!";
			}
		}
	}

	close(CF);
	keys %entries;
}

=pod

=item set_sendmail_cf(FILENAME)

Set the default filename used by C<auto_getconn>, C<auto_setconn>, and
C<sendmail_class> to find Sendmail-specific configuration data.  If not
explicitly set by this method, it defaults to C</etc/mail/sendmail.cf>.

=cut

sub set_sendmail_cf ($) {
	my $this = shift;

	$this->{sendmail_cf} = shift;
	1;
}

### off-the-shelf dispatchers

=pod

=back

=head1 DISPATCHERS

Milter requests may be dispatched to the protocol handler in a pluggable
manner (see the description for the C<set_dispatcher()> method above).
C<Sendmail::PMilter> offers some off-the-shelf dispatchers that use
different methods of resource allocation.

Each of these is referenced as a non-object function, and return a value
that may be passed directly to C<set_dispatcher()>.

=over 4

=item Sendmail::PMilter::ithread_dispatcher()

=item (environment) PMILTER_DISPATCHER=ithread

The C<ithread> dispatcher spins up a new thread upon each connection to
the milter socket.  This provides a thread-based model that may be more
resource efficient than the similar C<postfork> dispatcher.  This requires
that the Perl interpreter be compiled with C<-Duseithreads>, and uses the
C<threads> module (available on Perl 5.8 or later only).

=cut

sub ithread_dispatcher {
	require threads;
	require threads::shared;

	my $nchildren = 0;

	threads::shared::share($nchildren);

	sub {
		my $this = shift;
		my $lsocket = shift;
		my $handler = shift;
		my $maxchildren = $this->get_max_interpreters();

		my $siginfo = exists($SIG{INFO}) ? 'INFO' : 'USR1';
		local $SIG{$siginfo} = sub {
			warn "Number of active children: $nchildren\n";
		};

		my $child_sub = sub {
			my $socket = shift;

			eval {
				&$handler($socket);
				$socket->close();
			};
			my $died = $@;

			lock($nchildren);
			$nchildren--;
			warn $died if $died;
		};

		while (1) {
			my $socket = $lsocket->accept();
			next if $!{EINTR};

			warn "$$: incoming connection\n" if ($DEBUG > 0);

			# If the load's too high, fail and go back to top of loop.
			if ($maxchildren) {
				my $cnchildren = $nchildren; # make constant

				if ($cnchildren >= $maxchildren) {
					warn "load too high: children $cnchildren >= max $maxchildren";

					$socket->autoflush(1);
					$socket->print(pack('N/a*', 't')); # SMFIR_TEMPFAIL
					$socket->close();
					next;
				}
			}

			# scoping block for lock()
			{
				lock($nchildren);

				die "thread creation failed: $!\n"
					unless (threads->create($child_sub, $socket));

				threads->yield();
				$nchildren++;
			}
		}
	};
}

=pod

=item Sendmail::PMilter::prefork_dispatcher([PARAMS])

=item (environment) PMILTER_DISPATCHER=prefork

The C<prefork> dispatcher forks the main Perl process before accepting
connections, and uses the main process to monitor the children.  This
should be appropriate for steady traffic flow sites.  Note that if
MAXINTERP is not set in the call to C<main()> or in PARAMS, an internal
default of 10 processes will be used; similarly, if MAXREQ is not set, 100
requests will be served per child.

Currently the child process pool is fixed-size:  discarded children will
be immediately replaced.  This may change to use a dynamic sizing method
in the future, more like the Apache webserver's fork-based model.

PARAMS, if specified, is a hash of key-value pairs defining parameters for
the dispatcher.  The available parameters that may be set are:

=over 2

=item child_init

subroutine reference that will be called after each child process is forked.
It will be passed the C<MILTER> object.

=item child_exit

subroutine reference that will be called just before each child process
terminates.  It will be passed the C<MILTER> object.

=item max_children

Maximum number of child processes active at any time.  Equivalent to the
MAXINTERP option to main() -- if not set in the main() call, this value
will be used.

=item max_requests_per_child

Maximum number of requests a child process may service before being
recycled.  Equivalent to the MAXREQ option to main() -- if not set in the
main() call, this value will be used.

=back

=cut

sub prefork_dispatcher (@) {
	my %params = @_;
	my %children;

	my $child_dispatcher = sub {
		my $this = shift;
		my $lsocket = shift;
		my $handler = shift;
		my $max_requests = $this->get_max_requests() || $params{max_requests_per_child} || 100;
		my $i = 0;

		local $SIG{PIPE} = 'IGNORE'; # so close_callback will be reached

		my $siginfo = exists($SIG{INFO}) ? 'INFO' : 'USR1';
		local $SIG{$siginfo} = sub {
			warn "$$: requests handled: $i\n";
		};

		# call child_init handler if present
		if (defined $params{child_init}) {
			my $method = $params{child_init};
			$this->$method();
		}

		while ($i < $max_requests) {
			my $socket = $lsocket->accept();
			next if $!{EINTR};

			warn "$$: incoming connection\n" if ($DEBUG > 0);

			$i++;
			&$handler($socket);
			$socket->close();
		}

		# call child_exit handler if present
		if (defined $params{child_exit}) {
			my $method = $params{child_exit};
			$this->$method();
		}
	};

	# Propagate some signals down to the entire process group.
	my $killall = sub {
		my $sig = shift;

		kill 'TERM', keys %children;
		exit 0;
	};
	local $SIG{INT} = $killall;
	local $SIG{QUIT} = $killall;
	local $SIG{TERM} = $killall;

	setpgrp();

	sub {
		my $this = $_[0];
		my $maxchildren = $this->get_max_interpreters() || $params{max_children} || 10;

		while (1) {
			while (scalar keys %children < $maxchildren) {
				my $pid = fork();
				die "fork: $!" unless defined($pid);

				if ($pid) {
					# Perl reset these to IGNORE.  Restore them.
					$SIG{INT} = $killall;
					$SIG{QUIT} = $killall;
					$SIG{TERM} = $killall;
					$children{$pid} = 1;
				} else {
					# Perl reset these to IGNORE.  Set to defaults.
					$SIG{INT} = 'DEFAULT';
					$SIG{QUIT} = 'DEFAULT';
					$SIG{TERM} = 'DEFAULT';
					&$child_dispatcher(@_);
					exit 0;
				}
			}

			# Wait for a pid to exit, then loop back up to fork.
			my $pid = wait();
			delete $children{$pid} if ($pid > 0);
		}
	};
}

=pod

=item Sendmail::PMilter::postfork_dispatcher()

=item (environment) PMILTER_DISPATCHER=postfork

In this release, this is the default dispatcher for PMilter if no explicit
dispatcher is set.

The C<postfork> dispatcher forks the main Perl process upon each connection
to the milter socket.  This is adequate for machines that get bursty but
otherwise mostly idle mail traffic, as the idle-time resource consumption is
very low.

=cut

sub postfork_dispatcher () {
	my $nchildren = 0;
	my $sigchld;

	$sigchld = sub {
		my $pid;
		$nchildren-- while (($pid = waitpid(-1, WNOHANG)) > 0);
		$SIG{CHLD} = $sigchld;
	};

	sub {
		my $this = shift;
		my $lsocket = shift;
		my $handler = shift;
		my $maxchildren = $this->get_max_interpreters();

		# Decrement child count on child exit.
		local $SIG{CHLD} = $sigchld;

		my $siginfo = exists($SIG{INFO}) ? 'INFO' : 'USR1';
		local $SIG{$siginfo} = sub {
			warn "Number of active children: $nchildren\n";
		};

		while (1) {
			my $socket = $lsocket->accept();
			next if !$socket;

			warn "$$: incoming connection\n" if ($DEBUG > 0);

			# If the load's too high, fail and go back to top of loop.
			if ($maxchildren) {
				my $cnchildren = $nchildren; # make constant

				if ($cnchildren >= $maxchildren) {
					warn "load too high: children $cnchildren >= max $maxchildren";

					$socket->autoflush(1);
					$socket->print(pack('N/a*', 't')); # SMFIR_TEMPFAIL
					$socket->close();
					next;
				}
			}

			my $pid = fork();

			if ($pid < 0) {
				die "fork: $!\n";
			} elsif ($pid) {
				$nchildren++;
				$socket->close() if defined($socket);
			} else {
				$lsocket->close();
				undef $lsocket;
				undef $@;
				$SIG{PIPE} = 'IGNORE'; # so close_callback will be reached
				$SIG{$siginfo} = 'DEFAULT';

				&$handler($socket);
				$socket->close() if defined($socket);
				exit 0;
			}
		}
	};
}

=pod

=item Sendmail::PMilter::sequential_dispatcher()

=item (environment) PMILTER_DISPATCHER=sequential

The C<sequential> dispatcher forces one request to be served at a time,
making other requests wait on the socket for the next pass through the loop.
This is not suitable for most production installations, but may be quite
useful for milter debugging or other software development purposes.

Note that, because the default socket backlog is 5 connections, it may be
wise to increase this backlog by calling C<set_listen()> before entering
C<main()> if using this dispatcher.

=cut

sub sequential_dispatcher () {
	sub {
		my $this = shift;
		my $lsocket = shift;
		my $handler = shift;
		local $SIG{PIPE} = 'IGNORE'; # so close_callback will be reached

		while (1) {
			my $socket = $lsocket->accept();
			next if $!{EINTR};

			warn "$$: incoming connection\n" if ($DEBUG > 0);

			&$handler($socket);
			$socket->close();
		}
	};
}

1;
__END__

=pod

=head1 EXPORTS

Each of these symbols may be imported explicitly, imported with tag C<:all>,
or referenced as part of the C<Sendmail::PMilter::> package.

=over 2

=item Callback Return Values

Of these, SMFIS_CONTINUE will allow the milter to continue being called for
the remainder of the message phases.  All others will terminate processing
of the current message and take the noted action.

As a special exception, SMFIS_REJECT and SMFIS_TEMPFAIL in the C<envrcpt>
callback will reject only the current recipient, otherwise continuing
message processing as if SMFIS_CONTINUE were returned.

  SMFIS_CONTINUE - continue processing the message
  SMFIS_REJECT - reject the message with a 5xx error
  SMFIS_DISCARD - accept, but discard the message
  SMFIS_ACCEPT - accept the whole message as-is
  SMFIS_TEMPFAIL - reject the message with a 4xx error

=item Milter Capability Request Flags

These values are bitmasks passed as the FLAGS argument to C<register()>.  
Some MTAs may choose different methods of resource allocation, so keeping
this list short may help the MTA's memory usage.  If the needed capabilities
are not known, however, C<SMFI_CURR_ACTS> should be used.

  SMFIF_ADDHDRS - allow $ctx->addheader()
  SMFIF_CHGBODY - allow $ctx->replacebody()
  SMFIF_MODBODY - (compatibility synonym for SMFIF_CHGBODY)
  SMFIF_ADDRCPT - allow $ctx->addrcpt()
  SMFIF_DELRCPT - allow $ctx->delrcpt()
  SMFIF_CHGHDRS - allow $ctx->chgheader()

  SMFIF_QUARANTINE - allow $ctx->quarantine()
    (requires Sendmail 8.13; not defined in Sendmail::Milter)

  SMFIF_SETSENDER - allow $ctx->setsender()
    (requires special Sendmail patch; see below[*])

  SMFI_V1_ACTS - SMFIF_ADDHDRS through SMFIF_DELRCPT
    (Sendmail 8.11 _FFR_MILTER capabilities)

  SMFI_V2_ACTS - SMFIF_ADDHDRS through SMFIF_CHGHDRS
  SMFI_CURR_ACTS - (compatibility synonym for SMFI_V2_ACTS)
    (Sendmail 8.12 capabilities)

  (Currently no combined macro includes SMFIF_QUARANTINE or
  SMFIF_SETSENDER.)

[*] NOTE: SMFIF_SETSENDER is not official as of Sendmail 8.13.x. To enable
this flag, Sendmail must be patched with the diff available from:

  C<http://www.sourceforge.net/projects/mlfi-setsender>

Additionally, the following statement must appear after the "use"
statements in your milter program; otherwise, setsender() will always fail
when called:

  local $Sendmail::PMilter::enable_setsender = 1;

=back

=back

=head1 SECURITY CONSIDERATIONS

=over 4

=item Running as root

Running Perl as root is dangerous.  Running C<Sendmail::PMilter> as root may
well be system-assisted suicide at this point.  So don't do that.

More specifically, though, it is possible to run a milter frontend as root,
in order to gain access to network resources (such as a filesystem socket in
/var/run), and then drop privileges before accepting connections.  To do
this, insert drop-privileges code between calls to setconn/auto_setconn and
main; for instance:

    $milter->auto_setconn('pmilter');
    $> = 65534; # drop root privileges
    $milter->main();

The semantics of properly dropping system administrator privileges in Perl
are, unfortunately, somewhat OS-specific, so this process is not described
in detail here.

=back

=head1 AUTHOR

Todd Vierling, E<lt>tv@duh.orgE<gt> E<lt>tv@pobox.comE<gt>

=head1 Maintenance

Since 0.96 Sendmail::Pmilter is no longer maintained on
sourceforge.net, cpan:AVAR took it over in version 0.96 to fix a minor
bug and currently owns the module in PAUSE.

However this module is effectively orphaned and looking for a new
maintainer. The current maintainer doesn't use Sendmail and probably
never will again. If this code is important to you and you find a bug
in it or want something new implemented please:

=over

=item *

Fork it & fix it on GitHub at
L<http://github.com/avar/sendmail-pmilter>

=item *

Send AVAR an E-Mail requesting upload permissions so you can upload
the fixed version to the CPAN.

=back

=head1 SEE ALSO

L<Sendmail::PMilter::Context> for a description of the arguments
passed to each callback function

The project homepage:  http://pmilter.sourceforge.net/

=head1 THANKS

rob.casey@bluebottle.com - for the prefork mechanism idea

=cut

1;

__END__
