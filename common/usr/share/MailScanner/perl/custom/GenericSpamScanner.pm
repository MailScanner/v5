#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: GenericSpamScanner.pm 3119 2005-07-12 11:27:14Z jkf $
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

use IPC::Open2;
use FileHandle;

sub GenericSpamScanner {
  my($ip, $from, $to, $message) = @_;

  print STDERR "Generic Spam Scanner\n";
  print STDERR "====================\n";
  print STDERR "\n";
  print STDERR "IP = \"$ip\"\n";
  print STDERR "From = \"$from\"\n";
  print STDERR "To = \"" . join(", ", @$to) . "\"\n";
  #print STDERR "Message = \"" . join(", ", @$message) . "\"\n";

 # To call a remote program you might want to do this:
 my($fhread, $fhwrite, $pid, $score, $report);
 die "Can't fork: $!" unless defined($pid = open2($fhread, $fhwrite,
                                     '/usr/local/bin/yourprogramhere'));
 $fhwrite->print("$ip\n");
 $fhwrite->print("$from\n");
 foreach my $address (@$to) {
  $fhwrite->print("$address\n");
 }
 $fhwrite->print(@$message);
 $fhwrite->flush();
 $fhwrite->close();
 $score = <$fhread>;
 chomp $score;
 print STDERR "Read \"$score\" from your program\n\n";
 $score = $score+0.0;

 $report = <$fhread>;
 chomp $report; 
 print STDERR "Read \"$report\" from your program\n\n";

 return ($score, $report);

 # return (0.0, 'No report');
}

1;

__DATA__

#------------------------------------------------------------
#
# C source code of a skeleton yourprogramhere program
#
#------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>

char buffer[256];

int main(void) {
  char *result;

  result = fgets(buffer, 256, stdin);
  while(result!=NULL) {
    result = fgets(buffer, 256, stdin);
  }

  printf("55\n");
  printf("This is a report\n");
}

