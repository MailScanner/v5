#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: SystemDefs.pm 1180 2002-11-10 15:02:15Z jkf $
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

# System-wide operating-system specific locations of commands.
# The only one that might vaguely conceivably not be in /bin is sed.
# So that's the only one we use autoconf for. At the moment.
#
$global::rm  = '/bin/rm';
$global::cp  = '/bin/cp';
$global::cat = '/bin/cat';
$global::sed = '/bin/sed';

1;
