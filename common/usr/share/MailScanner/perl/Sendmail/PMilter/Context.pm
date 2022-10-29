# $Id: Context.pm,v 1.17 2004/08/04 17:07:51 tvierling Exp $
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

package Sendmail::PMilter::Context;

use 5.006;
use base Exporter;

use strict;
use warnings;

use Carp;
use Sendmail::Milter 0.18; # get needed constants
use Socket;
use UNIVERSAL;

use Sendmail::PMilter qw(:all);

our $VERSION = '0.94';

=pod

=head1 SYNOPSIS

Sendmail::PMilter::Context - per-connection milter context

=head1 DESCRIPTION

A Sendmail::PMilter::Context is the context object passed to milter callback
functions as the first argument, typically named "$ctx" for convenience.  
This manual explains publicly accessible operations on $ctx.

=head1 METHODS

=over 4

=cut

##### Symbols exported to the caller

use constant SMFIA_UNKNOWN	=> 'U';
use constant SMFIA_UNIX		=> 'L';
use constant SMFIA_INET		=> '4';
use constant SMFIA_INET6	=> '6';

our @EXPORT_OK = qw(
	SMFIA_UNKNOWN
	SMFIA_UNIX
	SMFIA_INET
	SMFIA_INET6
);
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

##### Protocol constants

use constant SMFIC_ABORT	=> 'A';
use constant SMFIC_BODY		=> 'B';
use constant SMFIC_CONNECT	=> 'C';
use constant SMFIC_MACRO	=> 'D';
use constant SMFIC_BODYEOB	=> 'E';
use constant SMFIC_HELO		=> 'H';
use constant SMFIC_HEADER	=> 'L';
use constant SMFIC_MAIL		=> 'M';
use constant SMFIC_EOH		=> 'N';
use constant SMFIC_OPTNEG	=> 'O';
use constant SMFIC_RCPT		=> 'R';
use constant SMFIC_QUIT		=> 'Q';
use constant SMFIC_DATA		=> 'T'; # v4
use constant SMFIC_UNKNOWN	=> 'U'; # v3

use constant SMFIR_ADDRCPT	=> '+';
use constant SMFIR_DELRCPT	=> '-';
use constant SMFIR_ACCEPT	=> 'a';
use constant SMFIR_REPLBODY	=> 'b';
use constant SMFIR_CONTINUE	=> 'c';
use constant SMFIR_DISCARD	=> 'd';
use constant SMFIR_ADDHEADER	=> 'h';
use constant SMFIR_INSHEADER	=> 'i'; # v3, or v2 and Sendmail 8.13+
use constant SMFIR_CHGHEADER	=> 'm';
use constant SMFIR_PROGRESS	=> 'p';
use constant SMFIR_QUARANTINE	=> 'q';
use constant SMFIR_REJECT	=> 'r';
use constant SMFIR_SETSENDER	=> 's';
use constant SMFIR_TEMPFAIL	=> 't';
use constant SMFIR_REPLYCODE	=> 'y';

use constant SMFIP_NOCONNECT	=> 0x01;
use constant SMFIP_NOHELO	=> 0x02;
use constant SMFIP_NOMAIL	=> 0x04;
use constant SMFIP_NORCPT	=> 0x08;
use constant SMFIP_NOBODY	=> 0x10;
use constant SMFIP_NOHDRS	=> 0x20;
use constant SMFIP_NOEOH	=> 0x40;
use constant SMFIP_NONE		=> 0x7F;

##### Private data

no strict 'refs';
my %replynames = map { &{$_} => $_ } qw(
	SMFIR_ADDRCPT
	SMFIR_DELRCPT
	SMFIR_ACCEPT
	SMFIR_REPLBODY
	SMFIR_CONTINUE
	SMFIR_DISCARD
	SMFIR_ADDHEADER
	SMFIR_INSHEADER
	SMFIR_CHGHEADER
	SMFIR_PROGRESS
	SMFIR_QUARANTINE
	SMFIR_REJECT
	SMFIR_SETSENDER
	SMFIR_TEMPFAIL
	SMFIR_REPLYCODE
);
use strict 'refs';

##### Constructor, main loop, and internal calls

sub new ($$$$) {
	my $this = bless {}, shift;
	$this->{socket} = shift;
	my $callbacks = $this->{callbacks} = shift;
	$this->{callback_flags} = shift;

	# Determine required protocol; include any that are needed.
	# We always need CONNECT to get hostname and address.
	# We always need MAIL FROM: to determine start-of-message.

	$this->{protocol} = SMFIP_NONE & ~(SMFIP_NOCONNECT|SMFIP_NOMAIL);
	$this->{protocol} &= ~SMFIP_NOHELO if $callbacks->{helo};
	$this->{protocol} &= ~SMFIP_NORCPT if $callbacks->{envrcpt};
	$this->{protocol} &= ~SMFIP_NOBODY if $callbacks->{body};
	$this->{protocol} &= ~SMFIP_NOHDRS if $callbacks->{header};
	$this->{protocol} &= ~SMFIP_NOEOH if $callbacks->{eoh};

	$this;
}

sub main ($) {
	my $this = shift;
	my $socket = $this->{socket} || return undef;

	my $buf = '';
	my $gotquit = 0;

	my $split_buf = sub {
		$buf =~ s/\0$//; # remove trailing NUL
		return [ split(/\0/, $buf) ];
	};

	$socket->autoflush(1);

	$this->{lastsymbol} = '';

	eval {
		while (1) {
			$this->read_block(\$buf, 4) || last;
			my $len = unpack('N', $buf);

			die "bad packet length $len\n" if ($len <= 0 || $len > 131072);

			# save the overhead of stripping the first byte from $buf
			$this->read_block(\$buf, 1) || last;
			my $cmd = $buf;

			# get actual data
			$this->read_block(\$buf, $len - 1) || die "EOF in stream\n";

			if ($cmd eq SMFIC_ABORT) {
				delete $this->{symbols}{&SMFIC_MAIL};
				$this->call_hooks('abort');
			} elsif ($cmd eq SMFIC_BODY) {
				$this->call_hooks('body', $buf, length($buf));
			} elsif ($cmd eq SMFIC_CONNECT) {
				# Perl RE doesn't like matching multiple \0 instances.
				# To avoid problems, we slice the string to the first null,
				# then use unpack for the rest.

				unless ($buf =~ s/^([^\0]*)\0(.)//) {
					die "SMFIC_CONNECT: invalid connect info\n";
					# XXX should print a hexdump here?
				}

				my $host = $1;
				my $af = $2;
				my ($port, $addr) = unpack('nZ*', $buf);
				my $pack; # default undef

				if ($af eq SMFIA_INET) {
					$pack = pack_sockaddr_in($port, inet_aton($addr));
				} elsif ($af eq SMFIA_INET6) {
					$pack = eval {
						require Socket6;
						$addr =~ s/^IPv6://;
						Socket6::pack_sockaddr_in6($port,
							Socket6::inet_pton(&Socket6::AF_INET6, $addr));
					};
				} elsif ($af eq SMFIA_UNIX) {
					$pack = eval {
						sockaddr_un($addr);
					};
				}

				$this->call_hooks('connect', $host, $pack);
			} elsif ($cmd eq SMFIC_MACRO) {
				die "SMFIC_MACRO: empty packet\n" unless ($buf =~ s/^(.)//);

				my $code = $this->{lastsymbol} = $1;
				my $marray = &$split_buf;

				# odd number of entries: give last empty value
				push(@$marray, '') if ((@$marray & 1) != 0);

				my %macros = @$marray;

				while (my ($name, $value) = each(%macros)) {
					$this->{symbols}{$code}{$name} = $value;
				}
			} elsif ($cmd eq SMFIC_BODYEOB) {
				$this->call_hooks('eom');
			} elsif ($cmd eq SMFIC_HELO) {
				my $helo = &$split_buf;
				die "SMFIC_HELO: bad packet\n" unless (@$helo == 1);

				$this->call_hooks('helo', @$helo);
			} elsif ($cmd eq SMFIC_HEADER) {
				my $header = &$split_buf;

				# empty value: ensure an empty string
				push(@$header, '') if (@$header == 1);

				$this->call_hooks('header', @$header);
			} elsif ($cmd eq SMFIC_MAIL) {
				delete $this->{symbols}{&SMFIC_MAIL}
					if ($this->{lastsymbol} ne SMFIC_MAIL);

				my $envfrom = &$split_buf;
				die "SMFIC_MAIL: bad packet\n" unless (@$envfrom >= 1);

				$this->call_hooks('envfrom', @$envfrom);
			} elsif ($cmd eq SMFIC_EOH) {
				$this->call_hooks('eoh');
			} elsif ($cmd eq SMFIC_OPTNEG) {
				die "SMFIC_OPTNEG: packet has wrong size\n" unless (length($buf) == 12);

				my ($ver, $actions, $protocol) = unpack('NNN', $buf);
				die "SMFIC_OPTNEG: unknown milter protocol version $ver\n" unless ($ver >= 2 && $ver <= 6);

				$this->write_packet(SMFIC_OPTNEG, pack('NNN', 2,
					$this->{callback_flags} & $actions,
					$this->{protocol} & $protocol));
			} elsif ($cmd eq SMFIC_RCPT) {
				my $envrcpt = &$split_buf;
				die "SMFIC_RCPT: bad packet\n" unless (@$envrcpt >= 1);

				$this->call_hooks('envrcpt', @$envrcpt);

				delete $this->{symbols}{&SMFIC_RCPT};
			} elsif ($cmd eq SMFIC_DATA) {
				$this->call_hooks('data');
			} elsif ($cmd eq SMFIC_QUIT) {
				last;
				# that's all, folks!
			} elsif ($cmd eq SMFIC_UNKNOWN) {
				# this is not an unknown packet, but a packet
				# to tell the milter that an unknown smtp command
				# has been received.
			} else {
				die "unknown milter packet type $cmd\n";
			}
		}
	};

	my $err = $@;
	$this->call_hooks('close');

	# XXX better error handling?  die here to let an eval further up get it?
	if ($err) {
		$this->write_packet(SMFIR_TEMPFAIL) if defined($socket);
		warn $err;
	} else {
		$this->write_packet(SMFIR_CONTINUE) if defined($socket);
	}

	undef;
}

sub read_block {
	my $this = shift;
	my $bufref = shift;
	my $len = shift;

	my $socket = $this->{socket};
	my $sofar = 0;

	$$bufref = '';

	while ($len > $sofar) {
		my $read = $socket->sysread($$bufref, $len - $sofar, $sofar);
		return undef if (!defined($read) || $read <= 0); # if EOF
		$sofar += $read;
	}
	1;
}

sub write_packet {
	my $this = shift;
	my $code = shift;
	my $out = shift;

	$out = '' unless defined($out);

	my $len = pack('N', length($out) + 1);
	my $socket = $this->{socket};

	$socket->syswrite($len);
	$socket->syswrite($code);
	$socket->syswrite($out);
}

sub call_hooks ($$;@) {
	my $this = shift;
	my $what = $this->{cb} = shift;

	my $sub = $this->{callbacks}{$what};
	my $rc = SMFIS_CONTINUE;

	$rc = &$sub($this, @_) if defined($sub);

	# translate to response codes
	if ($rc eq SMFIS_CONTINUE) {
		$rc = SMFIR_CONTINUE;
	} elsif ($rc eq SMFIS_ACCEPT) {
		$rc = SMFIR_ACCEPT;
	} elsif ($rc eq SMFIS_DISCARD) {
		$rc = SMFIR_DISCARD;
	} elsif ($rc eq SMFIS_REJECT) {
		if (defined($this->{reply})) {
			$rc = SMFIR_REPLYCODE;
		} else {
			$rc = SMFIR_REJECT;
		}
	} elsif ($rc eq SMFIS_TEMPFAIL) {
		if (defined($this->{reply})) {
			$rc = SMFIR_REPLYCODE;
		} else {
			$rc = SMFIR_TEMPFAIL;
		}
	} else {
		die "invalid callback return $rc";
	}

	if ($what ne 'abort' && $what ne 'close') {
		if ($rc eq SMFIR_REPLYCODE) {
			$this->write_packet($rc, $this->{reply}."\0");
		} else {
			$this->write_packet($rc);
		}
	}

	undef $this->{reply};
}

##### General methods

=pod

=item $ctx->getpriv

Returns the private data object for this milter instance, set by
$ctx->setpriv() (see below).  Returns undef if setpriv has never been called
by this milter instance.

=cut

sub getpriv ($) {
	my $this = shift;

	$this->{priv};
}

=pod

=item $ctx->getsymval(NAME)

Retrieves the macro symbol named NAME from the macros available from the MTA
for the current callback.  This typically consists of a one-letter macro
name, or a multi-letter macro name enclosed in {curly braces}.  If the
requested macro was not defined by the MTA ny the time getsymval is called,
returns undef.

Some common macros include the following.  (Since milter is a protocol first
implemented in the Sendmail MTA, the macro names are the same as those in
Sendmail itself.)

=over 2

=item $ctx->getsymval('_')

The remote host name and address, in standard SMTP "name [address]" form.

=item $ctx->getsymval('i')

The MTA's queue ID for the current message.

=item $ctx->getsymval('j')

The MTA's idea of local host name.

=item $ctx->getsymval('{if_addr}')

The local address of the network interface upon which the connection was
received.

=item $ctx->getsymval('{if_name}')

The local hostname of the network interface upon which the connection was
received.

=item $ctx->getsymval('{mail_addr}')

The MAIL FROM: sender's address, canonicalized and angle bracket stripped.
(This is typically not the same value as the second argument to the
"envfrom" callback.)  Will be defined to the empty string '' if the client
issued a MAIL FROM:<> null return path command.

=item $ctx->getsymval('{rcpt_addr}')

The RCPT TO: recipient's address, canonicalized and angle bracket stripped.
(This is typically not the same value as the second argument to the
"envrcpt" callback.)

=back

Not all macros may be available at all times, of course.  Some macros are
only available after a specific phase is reached, and some macros may only
be available from certain MTA implementations.  Care should be taken to
check for undef returns in order to cover these cases.

=cut

sub getsymval ($$) {
	my $this = shift;
	my $key = shift;

	foreach my $code (SMFIC_RCPT, SMFIC_MAIL, SMFIC_HELO, SMFIC_CONNECT) {
		my $val = $this->{symbols}{$code}{$key};

		return $val if defined($val);
	}

	undef;
}

=pod

=item $ctx->setpriv(DATA)

This is the place to store milter-private data that is sensitive to the
current SMTP client connection.  Only one value can be stored, so typically
an arrayref or hashref is initialized in the "connect" callback and set with
$ctx->setpriv.

This value can be retrieved on subsequent callback runs with $ctx->getpriv.

=cut

sub setpriv ($$) {
	my $this = shift;
	$this->{priv} = shift;
	1;
}

=pod

=item $ctx->setreply(RCODE, XCODE, MESSAGE)

Set an extended SMTP status reply (before returning SMFIS_REJECT or
SMFIS_TEMPFAIL).  RCODE should be a short (4xx or 5xx) numeric reply code,
XCODE should be a long ('4.x.x' or '5.x.x') ESMTP reply code, and MESSAGE is
the full text of the message to send.  Example:

        $ctx->setreply(451, '4.7.0', 'Cannot authenticate you right now');
        return SMFIS_TEMPFAIL;

Note that after setting a reply with this method, the SMTP result code comes
from RCODE, not the difference between SMFIS_REJECT or SMFIS_TEMPFAIL.  
However, for consistency, callbacks that set a 4xx response code should use
SMFIS_TEMPFAIL, and those that set a 5xx code should return SMFIS_REJECT.

Returns a true value on success, undef on failure.  In the case of failure,
typically only caused by bad parameters, a generic message will still be
sent based on the SMFIS_* return code.

=cut

sub setreply ($$$$) {
	my $this = shift;
	my $rcode = shift || '';
	my $xcode = shift || '';
	my $message = shift || '';

	if ($rcode !~ /^[45]\d\d$/ || $xcode !~ /^[45]\.\d\.\d$/ || substr($rcode, 0, 1) ne substr($xcode, 0, 1)) {
		warn 'setreply: bad reply arguments';
		return undef;
	}

	$this->{reply} = "$rcode $xcode $message";
	1;
}

=item $ctx->shutdown()

A special case of C<< $ctx->setreply() >> which sets the short numeric reply 
code to 421 and the ESMTP code to 4.7.0.  Under Sendmail 8.13 and higher, 
this will close the MTA's communication channel quickly, which should 
immediately result in a "close" callback and end of milter execution. 
(However, Sendmail 8.11-8.12 will treat this as a regular 4xx error and 
will continue processing the message.)

Always returns a true value.

This method is an extension that is not available in the standard 
Sendmail::Milter package.

=cut

sub shutdown ($) {
	my $this = shift;

	$this->setreply(421, '4.7.0', 'Closing communications channel');
}

##### Protocol action methods

=pod

=item $ctx->addheader(HEADER, VALUE)

Add header HEADER with value VALUE to this mail.  Does not change any
existing headers with the same name.  Only callable from the "eom" callback.

Returns a true value on success, undef on failure.

=cut

sub addheader ($$$) {
	my $this = shift;
	my $header = shift || die "addheader: no header name\n";
	my $value = shift || die "addheader: no header value\n";

	die "addheader: called outside of EOM\n" if ($this->{cb} ne 'eom');
	die "addheader: SMFIF_ADDHDRS not in capability list\n" unless ($this->{callback_flags} & SMFIF_ADDHDRS);

	$this->write_packet(SMFIR_ADDHEADER, "$header\0$value\0");
	1;
}

=pod

=item $ctx->addrcpt(ADDRESS)

Add address ADDRESS to the list of recipients for this mail.  Only callable
from the "eom" callback.

Returns a true value on success, undef on failure.

=cut

sub addrcpt ($$) {
	my $this = shift;
	my $rcpt = shift || die "addrcpt: no recipient specified\n";

	die "addrcpt: called outside of EOM\n" if ($this->{cb} ne 'eom');
	die "addrcpt: SMFIF_ADDRCPT not in capability list\n" unless ($this->{callback_flags} & SMFIF_ADDRCPT);

	$this->write_packet(SMFIR_ADDRCPT, "$rcpt\0");
	1;
}

=pod

=item $ctx->chgheader(HEADER, INDEX, VALUE)

Change the INDEX'th header of name HEADER to the value VALUE.  Only callable
from the "eom" callback.

Returns a true value on success, undef on failure.

=cut

sub chgheader ($$$$) {
	my $this = shift;
	my $header = shift || die "chgheader: no header name\n";
	my $num = shift || 0;
	my $value = shift;

	$value = '' unless defined($value);

	die "chgheader: called outside of EOM\n" if ($this->{cb} ne 'eom');
	die "chgheader: SMFIF_CHGHDRS not in capability list\n" unless ($this->{callback_flags} & SMFIF_CHGHDRS);

	$this->write_packet(SMFIR_CHGHEADER, pack('N', $num)."$header\0$value\0");
	1;
}

=pod

=item $ctx->delrcpt(ADDRESS)

Remove address ADDRESS from the list of recipients for this mail.  The
ADDRESS argument must match a prior argument to the "envrcpt" callback
exactly (case sensitive, and including angle brackets if present).  Only
callable from the "eom" callback.

Returns a true value on success, undef on failure.  A success return does
not necessarily indicate that the recipient was successfully removed, but
rather that the command was queued for processing.

=cut

sub delrcpt ($$) {
	my $this = shift;
	my $rcpt = shift || die "delrcpt: no recipient specified\n";

	die "delrcpt: called outside of EOM\n" if ($this->{cb} ne 'eom');
	die "delrcpt: SMFIF_DELRCPT not in capability list\n" unless ($this->{callback_flags} & SMFIF_DELRCPT);

	$this->write_packet(SMFIR_DELRCPT, "$rcpt\0");
	1;
}

=pod

=item $ctx->progress()

Sends an asynchronous "progress" message to the MTA, which should reset 
the MTA's internal communications timer.  This can allow longer than 
normal operations, such as a deliberate delay, to continue running without 
dropping the milter-MTA connection.  This command can be issued at any 
time during any callback, although issuing it during a "close" callback 
may trigger socket connection warnings in Perl.

Always returns a true value.

This method is an extension that is not available in the standard 
Sendmail::Milter package.

=cut

sub progress ($) {
	my $this = shift;

	$this->write_packet(SMFIR_PROGRESS);
	1;
}

=pod

=item $ctx->quarantine(REASON)

Quarantine the current message in the MTA-defined quarantine area, using 
the given REASON as a text string describing the quarantine status.  Only 
callable from the "eom" callback.

Returns a true value on success, undef on failure.

This method is an extension that is not available in the standard 
Sendmail::Milter package.

=cut

sub quarantine ($$) {
	my $this = shift;
	my $reason = shift;

	die "quarantine: called outside of EOM\n" if ($this->{cb} ne 'eom');
	die "quarantine: SMFIF_QUARANTINE not in capability list\n" unless ($this->{callback_flags} & SMFIF_QUARANTINE);

	$this->write_packet(SMFIR_QUARANTINE, "$reason\0");
	1;
}

=pod

=item $ctx->replacebody(BUFFER)

Replace the message body with the data in BUFFER (a scalar).  This method
may be called multiple times, each call appending to the replacement buffer.  
End-of-line should be represented by CR-LF ("\r\n").  Only callable from the
"eom" callback.

Returns a true value on success, undef on failure.

=cut

sub replacebody ($$) {
	my $this = shift;
	my $chunk = shift;

	die "replacebody: called outside of EOM\n" if ($this->{cb} ne 'eom');
	die "replacebody: SMFIF_CHGBODY not in capability list\n" unless ($this->{callback_flags} & SMFIF_CHGBODY);

	my $len = length($chunk);
	my $socket = $this->{socket};

	$len = pack('N', ($len + 1));
	$socket->syswrite($len);
	$socket->syswrite(SMFIR_REPLBODY);
	$socket->syswrite($chunk);
	1;
}

=pod

=item $ctx->setsender(ADDRESS)

Replace the envelope sender address for the given mail message.  This
method provides an implementation to access the mlfi_setsender method
added to the libmilter library as part of the mlfi-setsender project 
(http://www.sourceforge.net/projects/mlfi-setsender).

Returns a true value on success, undef on failure.  A success return does
not necessarily indicate that the recipient was successfully removed, but
rather that the command was queued for processing.

=cut

sub setsender ($$) {
	my $this = shift;
	my $sender = shift || die "setsender: no sender specified\n";

	die "setsender: not enabled (see \"perldoc Sendmail::PMilter\" for information)\n" unless $Sendmail::PMilter::enable_setsender;
	die "setsender: called outside of EOM\n" if ($this->{cb} ne 'eom');
	die "setsender: SMFIF_SETSENDER not in capability list\n" unless ($this->{callback_flags} & SMFIF_SETSENDER);

	$this->write_packet(SMFIR_SETSENDER, "$sender\0");
	1;
}

1;

__END__

=pod

=back

=head1 SEE ALSO

L<Sendmail::PMilter>
