#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: MailScanner.pm 2102 2003-11-27 14:45:56Z jkf $
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

# This is the top-level MailScanner class, of which there is one instance
# and which is global. Means no other global vars are needed, but there
# aren't loads of cross-reference attributes in other classes.

package MailScanner;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 2102 $, 10;

# Attributes are
#
# @inq			set by new = list of directory names
# $work			set by new
# $mta			set by new
# $quar                 set by new
# $batch		set by WorkForHours
#

# Constructor.
# Takes dir => directory queue resides in
sub new {
  my $type = shift;
  my %params = @_;
  my $this = {};

  $this->{inq}  = $params{InQueue};
  $this->{work} = $params{WorkArea};
  $this->{mta}  = $params{MTA};
  $this->{quar} = $params{Quarantine};

  bless $this, $type;
  return $this;
}

