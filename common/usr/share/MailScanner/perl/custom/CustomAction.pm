#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: MyExample.pm 2331 2004-03-23 09:23:43Z jkf $
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

package MailScanner::CustomConfig;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 2331 $, 10;

#
# This file contains the CustomAction() function which is called by the
# Spam Action 'custom'. If the spam action is 'custom(flag)' then this
# is called with yes_or_no set to 'yes'. If the spam action is
# notcustom(flag)' then this is called with yes_or_no set to 'no'.
#
# You can use this to implement anything you want in the way of custom
# spam actions on messages. Combine this with the 'SpamAssassin Rule Actions'
# setting and you can make any property of a message cause any effect on
# your system.
#

sub CustomAction {
  my($message, $yes_or_no, $flag) = @_;

  print STDERR "CustomAction: $message $yes_or_no $flag\n";

  return unless $message;
  if ($yes_or_no =~ /y/) {
    $message->{usecaution} = 1 if $flag eq 'caution';
  } else {
    $message->{usecaution} = 0 if $flag eq 'caution';
  }
}

1;

