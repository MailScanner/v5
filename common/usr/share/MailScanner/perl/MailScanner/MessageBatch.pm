#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: MessageBatch.pm 5048 2010-08-03 11:19:15Z sysjkf $
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

#
# All functions for dealing with the entire batch of messages.
#

package MailScanner::MessageBatch;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use DirHandle;
use Time::HiRes qw ( time );
use POSIX;
use File::Temp qw ( tempfile tempdir );
use DBI qw(:sql_types);

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5048 $, 10;

my $maxcleanbytes    = 0;
my $maxcleanmessages = 0;
my $maxdirtybytes    = 0;
my $maxdirtymessages = 0;
my $initialised = 0;

#
# Members:
# $starttime			Set by new
# $endtime			Set by EndBatch
# $bytespersecond		Set by EndBatch
# $totalmessages		Set by CreateBatch
# $totalbytes			Set by CreateBatch
# $dirtymessages		Set by CreateBatch
# $dirtybytes			Set by CreateBatch
#

# Constructor.
# Builds the batch full of messages.
# Note: this currently does not archive messages anywhere, it just works
#       out where they will need archiving. Do the archiving once we
#       are about to remove it from the inqueue.
sub new {
  my $type   = shift;
  my $lint   = shift;
  my $OnlyID = shift; # A batch only containing this message ID, if specified
  my $this   = {};

  #print STDERR "In new MessageBatch\n";

  MailScanner::Log::DieLog("Tried to create a MessageBatch without calling initglobals")
    unless $initialised;

  if ($lint eq 'lint') {
    # Fake a batch containing the Eicar message
    bless $this, $type;
    $this->CreateEicarBatch();
  } else {
    $global::MS->{mta}->CreateBatch($this, $OnlyID);
  }

  $this->{starttime} = time;

  bless $this, $type;
  return $this;
}

# Work out the overall speed figures and log them
sub EndBatch {
  my $this = shift;

  my $now = time;
  my $totalbytes = $this->{totalbytes};
  my $totaltime  = $now - $this->{starttime};
  my $speed;

  #print STDERR "Started at " . $this->{starttime} . "\n";
  #print STDERR "Finished at " . $now . "\n";
  #print STDERR "Tool " . $totaltime . "\n";

  $this->{endtime} = $now;
  $this->{totaltime} = $totaltime;
  $totaltime = 1 unless $totaltime > 0.001; # Minimum of 1 m-second
  $speed = ($totalbytes*1.0) / ($totaltime*1.0) if $totaltime > 0;
  $this->{bytespersecond} = $speed;
  $speed = 0 if $speed > 1_000_000 || $speed < 0;
  if (MailScanner::Config::Value('logspeed')) {
    MailScanner::Log::InfoLog("Batch completed at %d bytes per second (%d / %d)",
                              $speed, $totalbytes, $now-$this->{starttime});

    # Work out current size of batch.
    my $msgs = $this->{messages};
    my $msgcount = scalar(keys %$msgs);

    MailScanner::Log::InfoLog("Batch (%d message%s) processed in %.2f seconds",
                              $msgcount, ($msgcount==1?'':'s'), $totaltime);
  }
}

# Start the timing for a section of the main code
# Using $varprefix as a prefix on the property name,
# set up properties for the figures.
sub StartTiming {
  my $this = shift;
  my($varprefix, $usertext) = @_;
  $this->{$varprefix . '_starttime'} = time;
}

# Stop the timing for a section of the main code
# Uses the xxx_starttime property created in StartTiming
sub StopTiming {
  my $this = shift;
  my($varprefix, $usertext) = @_;

  my $now = time;
  my $totaltime;
  my $speed;

  # totaltime = now - starttime
  $totaltime = $now - $this->{$varprefix . '_starttime'};

  # endtime = now
  $this->{$varprefix . '_endtime'} = $now;
  # totaltime = totaltime
  $this->{$varprefix . '_totaltime'} = $totaltime;
  $totaltime = 1 unless $totaltime > 0; # Minimum of 1 second
  # speed = bytes / totaltime
  $speed = ($this->{totalbytes}*1.0) / ($totaltime*1.0) if $totaltime > 0;
  $speed = 0 if $speed > 1_000_000 || $speed < 0;
  # bytespersecond = speed
  $this->{$varprefix . '_bytespersecond'} = $speed;

  MailScanner::Log::InfoLog("%s completed at %d bytes per second",
                            $usertext, $speed)
    if MailScanner::Config::Value('logspeed') && $speed > 0;
}

# This must be called as a class method before new() is used
sub initialise {
  #my $type = shift;

  $maxcleanbytes    = MailScanner::Config::Value('maxunscannedbytes');
  $maxcleanmessages = MailScanner::Config::Value('maxunscannedmessages');
  $maxdirtybytes    = MailScanner::Config::Value('maxdirtybytes');
  $maxdirtymessages = MailScanner::Config::Value('maxdirtymessages');
  $initialised = 1;
  #print STDERR "MessageBatch class has been initialised\n";
  #print STDERR "Limits are $maxcleanbytes, $maxcleanmessages, $maxdirtybytes, $maxdirtymessages\n";
}

# Return the max size of the batch
sub BatchLimits {
  return ($maxcleanbytes, $maxcleanmessages,
          $maxdirtybytes, $maxdirtymessages);
}

sub print {
  my $this = shift;

  my($id, $msg);
  my $msgs = $this->{messages};

  foreach $id (keys %$msgs) {
    $msg = $msgs->{$id};
    print STDERR "\n";
    $msg->print();
  }
}

# Delete the passed in messages from the batch, this wipes them
# out so nothing will still think they are in the queue.
# It just deletes the files, it doesn't delete the data structure
# as we will probably need it later for logging.
sub RemoveDeletedMessages {
  my $this = shift;

  my($id, $message, @badentries, @deletedentries);

  my $deleteifnotdelivering = 0;
  $deleteifnotdelivering = 1
    if MailScanner::Config::IsSimpleValue('keepspamarchiveclean') &&
       !MailScanner::Config::Value('keepspamarchiveclean');
  #print STDERR "Deleteifnotdelivering = $deleteifnotdelivering\n";

  #print STDERR "About to remove deleted messages\n";
  while(($id, $message) = each %{$this->{messages}}) {
    #print STDERR "Looking at $id for deletion\n";
    if (!$message) {
     #MailScanner::Log::WarnLog("RemoveDeletedMessages: Found bad message $id");
      push @badentries, $id;
      next;
    }
    #MailScanner::Log::InfoLog("RemoveDeletedMessages: Deleting message $id")
    #  if $message->{deleted};
    #print STDERR "Message->deleted = " . $message->{deleted} . "and dontdeliver = " . $message->{dontdeliver} . "\n";
    if ($message->{deleted} ||
        ($message->{dontdeliver} && $deleteifnotdelivering)) {
      $message->DeleteMessage();
      push @deletedentries, $id;
    }

    #delete $this->{messages}{$id} if $this->{messages}{$id}->{deleted};
  }
  foreach $id (@badentries) {
    delete $this->{messages}{$id};
  }
  # Add to the list of wiped messages
  $this->{deleted} .= ' ' . join(' ', @badentries, @deletedentries);
}


# Do all the spam checks.
# Must have removed deleted messages from the batch first.
sub SpamChecks {
  my $this = shift;

  my($id, $message);
  my $counter = 0;

  #print STDERR "Starting spam checks\n";

  MailScanner::Log::InfoLog("Spam Checks: Starting")
    if MailScanner::Config::Value('logspam');

  # If the cache contents have expired then clean it all up first
  MailScanner::SA::CheckForCacheExpire();

  while(($id, $message) = each %{$this->{messages}}) {
    next if !$message->{scanmail};
    next if $message->{deleted};
    next if $message->{scanvirusonly}; # Over-rides Spam Checks setting
    next unless MailScanner::Config::Value('spamchecks', $message) =~ /1/;
 
    #print STDERR "Spam checks for $id\n";

    # Tell SpamAssassin to apply rules to binary attachments
    # This relies on a patch to Util.pm in SpamAssassin, fetch the patch from
    # http://www.mailscanner.info/mcp.html#patches
    $MailScanner::MCP::SA_Decode_Binaries = 0;
    $MailScanner::MCP::SA_Decode_Binaries = 1
      if MailScanner::Config::Value('sadecodebins', $message) =~ /1/;

    $counter += $message->IsSpam();

    if (!MailScanner::Config::Value('spamdetail', $message)) {
      $message->{spamreport} = MailScanner::Config::LanguageValue($message,
                               ($message->{isspam}?'spam':'notspam'));
    }
  }
  MailScanner::Log::NoticeLog("Spam Checks: Found $counter spam messages")
    if $counter>0;
  $MailScanner::MCP::SA_Decode_Binaries = 0; # Reset 'are we in MCP' flag
  #print STDERR "$counter messages were spam\n";
}


# Handle the spam results using the actions they have defined.
# Can deliver, delete, store, and forward or any combination.
sub HandleSpam {
  my $this = shift;

  my($id, $message);

  #print STDERR "Starting to handle spam\n";

  while(($id, $message) = each %{$this->{messages}}) {
    # Skip deleted and non-spam messages
    #print STDERR "Deleted = " . $message->{deleted} . ", isspam = " . $message->{isspam} . ", scanmail = " . $message->{scanmail} . ", spamwhitelisted = " . $message->{spamwhitelisted} . "\n";
    next if  $message->{deleted} ||
            !$message->{isspam}  ||
            !$message->{scanmail} ||
             $message->{spamwhitelisted};

    #print STDERR "Spam checks for $id\n";
    $message->HandleHamAndSpam('spam');
  }

  #print STDERR "Finished handling spam\n\n";
}

# Handle the non-spam results using the actions they have defined.
# Can deliver, delete, store, and forward or any combination.
sub HandleHam {
  my $this = shift;

  my($id, $message);

  #print STDERR "Starting to handle ham\n";

  while(($id, $message) = each %{$this->{messages}}) {
    # Skip deleted and non-spam messages
    next if $message->{deleted} ||
           !$message->{scanmail} ||
            $message->{isspam};

    #print STDERR "Ham checks for $id\n";
    $message->HandleHamAndSpam('nonspam');
  }

  #print STDERR "Finished handling ham\n\n";
}

# Reject messages that come from people we want to reject. Send nice report
# instead.
# 2009-12-04 Changed from an "All" to a "First" match rule. Much more useful.
sub RejectMessages {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    # Skip deleted and non-spam messages
    next if $message->{deleted};
    #print STDERR "May reject message $id\n";
    $message->RejectMessage()
      if MailScanner::Config::Value('rejectmessage',$message);
  }
}

# Do all the MCP checks.
# Must have removed deleted messages from the batch first.
sub MCPChecks {
  my $this = shift;

  my($id, $message);
  my $counter = 0;

  #print STDERR "Starting spam checks\n";

  MailScanner::Log::InfoLog("MCP Checks: Starting")
    if MailScanner::Config::Value('logmcp');

  # Tell SpamAssassin to apply rules to binary attachments
  $MailScanner::MCP::SA_Decode_Binaries = 1;

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted};
    next if !$message->{scanmail};
    next unless MailScanner::Config::Value('mcpchecks', $message);
 
    #print STDERR "Spam checks for $id\n";
    $counter += $message->IsMCP();

    if (!MailScanner::Config::Value('mcpdetail', $message)) {
      $message->{mcpreport} = MailScanner::Config::LanguageValue($message,
                               ($message->{ismcp}?'mcpspam':'mcpnotspam'));
    }
    #print STDERR "Spam header = \"" . $message->{spamreport} . "\"\n";
  }
  MailScanner::Log::NoticeLog("MCP Checks: Found $counter MCP messages")
    if $counter>0;
  #print STDERR "$counter messages were spam\n";

  # Tell SpamAssassin to return to normal behaviour
  $MailScanner::MCP::SA_Decode_Binaries = 0;
}


# Handle the spam results using the actions they have defined.
# Can deliver, delete, store, and forward or any combination.
sub HandleMCP {
  my $this = shift;

  my($id, $message);

  #print STDERR "Starting to handle spam\n";

  while(($id, $message) = each %{$this->{messages}}) {
    # Skip deleted and non-spam messages
    next if  $message->{deleted} ||
            !$message->{ismcp}   ||
            !$message->{scanmail} ||
             $message->{mcpwhitelisted};

    #print STDERR "Spam checks for $id\n";
    $message->HandleMCP('mcp');
  }

  #print STDERR "Finished handling spam\n\n";
}

# Handle the non-spam results using the actions they have defined.
# Can deliver, delete, store, and forward or any combination.
sub HandleNonMCP {
  my $this = shift;

  my($id, $message);

  #print STDERR "Starting to handle ham\n";

  while(($id, $message) = each %{$this->{messages}}) {
    # Skip deleted and non-spam messages
    next if $message->{deleted} ||
           !$message->{scanmail} ||
            $message->{ismcp};

    #print STDERR "Ham checks for $id\n";
    $message->HandleMCP('nonmcp');
  }

  #print STDERR "Finished handling ham\n\n";
}


# Return true if all the messages in the batch are deleted!
# Return false otherwise.
sub Empty {
  my $this = shift;

  my($id, $message);
  while(($id,$message) = each %{$this->{messages}}) {
    if (!$message->{deleted}) {
      # Do not remove the next line, it is vital to reset "each()"!
      keys %{$this->{messages}};
      return 0;
    }
  }
  return 1;
}


# Deliver the messages that aren't to be scanned.
# Uses the "virusscanme" property to determine this.
# This does not add the clean sig or anything like that.
sub DeliverUnscanned {
  my $this = shift;

  my($OutQ, @messages, $id, $message);

  while(($id,$message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};

    # This is for mail we don't want to touch at all
    if (!$message->{scanmail}) {
      $OutQ = MailScanner::Config::Value('outqueuedir', $message);
      $message->DeliverUntouched($OutQ);
      $message->{deleted} = 1; # This marks it for purging from disk
      push @messages, $message;
      next;
    }
  }

  # Note this passes a list now, not a ref to a list
  MailScanner::Mail::TellAbout(@messages);

  MailScanner::Log::InfoLog("Unscanned: Delivered %d messages",
                            scalar(@messages)) if @messages;
}

sub DeliverUnscanned2 {
  my $this = shift;
  
  my($OutQ, @messages, $id, $message);
  
  while(($id,$message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};

    if (!$message->{scanme}) {
      #print STDERR "Delivering unscanned message $id\n";

      # Strip it if necessary
      $message->StripHTML() if $message->{needsstripping};
      #print STDERR "Tagstoconvert = " . $message->{tagstoconvert} . "\n";
      $message->DisarmHTML() if $message->{tagstoconvert};
      # Encapsulate the message if necessary
      $message->EncapsulateMessage() if $message->{needsencapsulating};
      # The message might have been changed by the RFC822 encapsulation
      # or the HTML stripping.
      if ($message->{bodymodified}) {
        $message->DeliverModifiedBody('unscannedheader');
      } else {
        $OutQ = MailScanner::Config::Value('outqueuedir', $message);
        $message->DeliverUnscanned($OutQ);
      }
      $message->{deleted} = 1; # This marks it for purging from disk
      push @messages, $message;
    }
  }

  # Note this passes a list now, not a ref to a list
  MailScanner::Mail::TellAbout(@messages);

  MailScanner::Log::InfoLog("Unscanned: Delivered %d messages",
                            scalar(@messages)) if @messages;
}


# Parse all the messages and expand all the attachments
sub Explode {
  my $this = shift;
  my($Debug) = @_;

  my($key, $message);

  # jjh 2004-03-12 reap as many as we can.
  # JKF Test 2004-11-23 1 until waitpid(-1, &POSIX::WNOHANG) == -1;
  unless ($Debug) {
    1 until waitpid(-1, WNOHANG) == -1;
  }

  #print STDERR "About to explode messages\n";
  #print STDERR "Ignore errors about failing to find EOCD signature\n";
  umask $global::MS->{work}->{fileumask};
  while(($key, $message) = each %{$this->{messages}}) {
    next if $message->{deleted};
    #print STDERR "About to explode message $key $message\n";
    $message->Explode();
    # jjh 2004-03-12 reap as many as we can.
    # JKF Test 2004-11-23 1 until waitpid(-1, &POSIX::WNOHANG) == -1;
    unless ($Debug) {
      1 until waitpid(-1, WNOHANG) == -1;
    }
  }
  umask 0077;
}


# Do all the checking and log the number of viruses/problems found
sub VirusScan {
  my $this = shift;

  # Don't do any virus scanning at all if the batch is empty!
  return if $this->Empty();

  #MailScanner::Log::InfoLog("Other Checks: Starting");
  my $others  = MailScanner::SweepOther::ScanBatch($this, 'scan');
  MailScanner::Log::NoticeLog("Other Checks: Found %d problems", $others+0)
    if defined $others && $others>0;

  # Call them with the scanning settings
  MailScanner::Log::InfoLog("Virus and Content Scanning: Starting");
  my $viruses = MailScanner::SweepViruses::ScanBatch($this, 'scan');
  MailScanner::Log::NoticeLog("Virus Scanning: Found %d viruses", $viruses+0)
    if defined $viruses && $viruses>0;

  #MailScanner::Log::InfoLog("Content Checks: Starting");
  my $content  = MailScanner::SweepContent::ScanBatch($this, 'scan');
  MailScanner::Log::NoticeLog("Content Checks: Found %d problems", $content+0)
    if defined $content && $content>0;
}


# Print the infection reports for all the messages
sub PrintInfections {
  my $this = shift;

  my($key, $message);

  #print "In PrintInfections(), this = $this\n";
  while(($key, $message) = each %{$this->{messages}}) {
    #print STDERR "Key is $key and Message is $message\n";
    $message->PrintInfections() unless $message->{deleted};
  }
}


# Convert errors that occurred in the extraction process into infection reports
sub ReportBadMessages {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted};
    if ($message->{cantparse}) {
      $message->{otherreports}{""} .=
        MailScanner::Config::LanguageValue($message, 'cantanalyze') . "\n";
      $message->{othertypes}{""}   .= 'e';
    }
    if ($message->{toomanyattach}) {
      $message->{otherreports}{""} .=
        MailScanner::Config::LanguageValue($message, 'toomanyattachments') . "\n";
      $message->{othertypes}{""}   .= 'e';
    }
    if ($message->{badtnef}) {
      $message->{entityreports}{$this->{tnefentity}} .=
        MailScanner::Config::LanguageValue($message, 'badtnef') . "\n";
      $message->{entitytypes}{$this->{tnefentity}}   .= 'e';
    }
  }
}


# Remove any infected spam or mcp from their archives. We have saved
# all the spam+mcp archive places we stored this message, so go delete
# the dirs and all the files in each one.
sub RemoveInfectedSpam {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    #print STDERR "Message is infected\n" if $message->{infected};
    next unless $message->{infected};
    next unless
      MailScanner::Config::Value('keepspamarchiveclean', $message) =~ /1/;
    #print STDERR "Deleting " . join(',',@{$message->{spamarchive}}) . "\n";
    unlink @{$message->{spamarchive}}; # Wipe the spamarchive files
    @{$this->{spamarchive}} = (); # Wipe the spamarchive array
  }
}

# Set up the entity2file and entity2parent hashes in every message
sub CreateEntitiesHelpers {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    $message->CreateEntitiesHelpers() unless $message->{deleted};
  }
}


# Print out the number of parts in each message
sub PrintNumParts {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted};
    #print "Message $id has " . $message->{numberparts} . " parts\n";
  }
}


# Print out the filenames in each message
sub PrintFilenames {
  my $this = shift;

  my($id, $message);
  my($fnames, @filenames);

  while(($id, $message) = each %{$this->{messages}}) {
    #next if $message->{deleted};
    #print STDERR "Message $id has filenames ";
    @filenames = keys %{$message->{file2entity}};
    #print STDERR join(", ", @filenames) . "\n";
  }
}


# Print out the infected sections of all messages
sub PrintInfectedSections {
  my $this = shift;

  my($id, $message);
  my($parts, $file, $entity);

  #print STDERR "\nInfected sections are:\n";
  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted};
    $parts = $message->{virusreports};
    foreach $file (keys %$parts) {
      $entity = $message->{file2entity}{$file};
      $entity->dump_skeleton();
    }
    $parts = $message->{otherreports};
    foreach $file (keys %$parts) {
      $entity = $message->{file2entity}{$file};
      $entity->dump_skeleton();
    }
  }
}


# Clean all the messages.
# Clean ==> remove the viruses, it doesn't imply macro-virus disinfection.
sub Clean {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};
    #print STDERR "\nCleaning message $id\n";
    $message->Clean();
  }
}

# Zip up all the attachments in the messages, to save space on the
# mail servers.
sub ZipAttachments {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};
    #print STDERR "\nZipping attachments, message $id\n";
    $message->ZipAttachments();
  }
}

# Combine the virus and other reports and types for all the messages.
# Might change this to do it at source later.
sub CombineReports {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    $message->CombineReports() unless $message->{deleted};
  }
}


# Store all the infected files in the quarantine if they want me to.
# Quarantine decision has to be done on a per-message basis.
sub QuarantineInfections {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted};
    next unless $message->{infected};
    next if $message->{silent} && !$message->{noisy} &&
            MailScanner::Config::Value('quarantinesilent', $message) !~ /1/;
    next unless MailScanner::Config::Value('quarantineinfections', $message)
                =~ /1/;
    #print STDERR "Quarantining infections for $id\n";
    $global::MS->{quar}->StoreInfections($message);
    $message->{quarantinedinfections} = 1; # Stop it quarantining it twice
  }
}

# Store all the disarmed files in the quarantine if they want me to.
# Quarantine decision has to be done on a per-message basis.
sub QuarantineModifiedBody {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next unless $message->{bodymodified};
    next if $message->{quarantinedinfections}; # Optimisation
    next if MailScanner::Config::Value ('quarantinemodifiedbody', $message) !~
            /1/;

    $global::MS->{quar}->StoreInfections($message);
    MailScanner::Log::NoticeLog("Quarantining modified message for %s", $id);
  }
}

# Sign all the messages that were clean with a tag line saying
# (ideally) that MailScanner is wonderful :-)
sub SignUninfected {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};
    if (MailScanner::Config::Value('signcleanmessages', $message) &&
         !$message->{infected}) {
      $message->IsAReply();
      $message->SignUninfected();
    }
  }
}


# Deliver all the messages that were never infected.
# This uses the "bodychanged" tag in the message properties
# to know whether to just move the incoming body to the out queue,
# or whether the outgoing message has got to be reconstructed.
# Also tag the message for future deletion.
sub DeliverUninfected {
  my $this = shift;

  my($id, $message, @messages);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};
    #print STDERR "Possibly delivering uninfected message $id\n";
    next if $message->{infected};
    #print STDERR "Delivering uninfected message $id\n";
    $message->DeliverUninfected();
    $message->{deleted} = 1;
    push @messages, $message;
  }

  MailScanner::Mail::TellAbout(@messages);

  MailScanner::Log::InfoLog("Uninfected: Delivered %d messages",
                            scalar(@messages)) if @messages;
}


# If we aren't delivering cleaned messages from a local domain,
# i.e. we are trying to ensure that no-one outside our local domains
# discovers we have a virus, then just delete the messages rather
# that deliver them.
# This replaces the "Deliver From Local Domains" keyword and the
# "Deliver To Recipients" keyword.
# When we delete them here, we still want to be able to issue the
# warnings, so this is only a "semi-deletion".
sub DeleteUnwantedCleaned {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if !$message->{infected} || $message->{deleted};
    next if MailScanner::Config::Value('delivercleanedmessages', $message)
            =~ /1/;
    #print STDERR "Deleting unwanted cleaned message $id\n";
    $message->{deleted}   = 1;
    $message->{stillwarn} = 1;
  }
}


# Find all the messages infected with a "Silent" virus.
# Really must try to rename this option before shipping this!
# Set the "silent" flag as appropriate.
sub FindSilentAndNoisyInfections {
  my $this = shift;

  my($id, $message);

  while(($id, $message) = each %{$this->{messages}}) {
    next if !$message->{infected};
    next if $message->{deleted} && !$message->{stillwarn};
    next if $message->{spamvirusreport}; # Silent exclude Spam-Viruses
    $message->FindSilentAndNoisyInfections();
  }
}


# Deliver all the "silent" and not noisy infected messages,
# and mark them for deletion from the queue.
sub DeliverOrDeleteSilentExceptSpamViruses {
  my $this = shift;

  my($id, $message, @messages);

  while(($id, $message) = each %{$this->{messages}}) {
    next if !$message->{silent}  || $message->{noisy} ||
             $message->{deleted} || $message->{dontdeliver};
    #MailScanner::Log::WarnLog("Deliversilent for %s is %s", $message->{id},
    #                MailScanner::Config::Value('deliversilent', $message));
    if (MailScanner::Config::Value('deliversilent', $message)) {
      $message->DeliverCleaned();
      #print STDERR "Deleting silent-infected message " . $message->{id} . "\n";
      push @messages, $message;
    }
    $message->{deleted} = 1;
    $message->{stillwarn} = 1;
  }

  if (@messages) {
    MailScanner::Mail::TellAbout(@messages);
    MailScanner::Log::NoticeLog("Silent: Delivered %d messages containing " .
                              "silent viruses", scalar(@messages));
  }
}


# Deliver all the "cleaned" messages from the queue. Any
# unwanted ones will have already been deleted.
sub DeliverCleaned {
  my $this = shift;

  my($id, $message, @messages);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};
    $message->DeliverCleaned();
    #print STDERR "Deleting cleaned message " . $message->{id} . "\n";
    # BUGFIX: JKF $message->{deleted} = 1;
    push @messages, $message;
  }

  MailScanner::Mail::TellAbout(@messages);

  MailScanner::Log::NoticeLog("Cleaned: Delivered %d cleaned messages",
                            scalar(@messages)) if @messages;
}


# Warn the senders of the infected/troublesome messages that we
# didn't like them. Only do this if we've been told to!
sub WarnSenders {
  my $this = shift;

  my($id, $message, $counter, $reasons, $warnviruses);

  $counter = 0;
  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} && !$message->{stillwarn};
    next if $message->{silent} && !$message->{noisy};
    #print STDERR "Looking to warn sender of $id\n";
    next unless $message->{infected};
    #print STDERR "Warning sender of $id who is " .  $message->{from} . "\n";
    next unless MailScanner::Config::Value('warnsenders', $message) =~ /1/;
    #print STDERR "2Warning sender of $id who is " .  $message->{from} . "\n";

    # Count up the number of reasons why we want to warn the sender.
    # If it's 0 then don't warn them.
    # However, let the "warnvirussenders" take priority over the other 2.
    # So if there is a virus and they don't want to warn virus senders
    # then don't send a warning regardless of the other traps.
    $warnviruses = MailScanner::Config::Value('warnvirussenders', $message);
    next if $message->{virusinfected} && !$warnviruses;

    $reasons = 0;
    $reasons++ if $message->{virusinfected} &&
                  $warnviruses;
    $reasons++ if $message->{nameinfected}  &&
                  MailScanner::Config::Value('warnnamesenders', $message);
    $reasons++ if $message->{sizeinfected} &&
                  MailScanner::Config::Value('warnsizesenders', $message);
    $reasons++ if $message->{otherinfected} &&
                  MailScanner::Config::Value('warnothersenders', $message);
    # JKF 19/12/2007
    # $reasons++ if $message->{passwordinfected} &&
    #               MailScanner::Config::Value('warnpasswordsenders', $message);
    next if $reasons==0;

    $message->WarnSender();
    $counter++;
  }

  MailScanner::Log::NoticeLog("Sender Warnings: Delivered %d warnings to " .
                            "virus senders", $counter) if $counter;
}


# Warn the local postmaster (or whoever is receiving the notices)
# a summary of the infections found.
# Save the notices into different emails, one per different postmaster,
# so that the notices can be sent to different people depending on the
# domain.
sub WarnLocalPostmaster {
  my $this = shift;

  my($id, $message, $counter);
  my(%notices, $notice, %headers, %signatures, $email);
  my(@posties, $posties, $postie, $sig, %reasons, $reasons, $thisreason);

  # Create all the email messages
  $counter = 0;
  while(($id, $message) = each %{$this->{messages}}) {
    next if !$message->{infected};
    next if $message->{deleted} && !$message->{stillwarn};
    next unless MailScanner::Config::Value('sendnotices', $message) =~ /1/;
    $posties = MailScanner::Config::Value('noticerecipient', $message);
    if ($posties =~ /^\s*$/) {
      keys %{$this->{messages}}; # Necessary line to reset "each()"
      # Return if no posties defined
      return;
    }
    @posties = split(" ", $posties);
    foreach $postie (@posties) {
      $headers{$postie} = $message->CreatePostmasterHeaders($postie)
        unless $headers{$postie};

      # Change the subject to include the problem types
      %reasons = ();
      $reasons = "";
      $reasons{virusinfected}     = 1 if $message->{virusinfected};
      $reasons{filenameinfected}  = 1 if $message->{nameinfected};
      $reasons{otherinfected}     = 1 if $message->{otherinfected};
      $reasons{sizeinfected}      = 1 if $message->{sizeinfected};
      # JKF 19/12/2007 $reasons{passwordinfected}  = 1 if $message->{passwordinfected};
      $reasons{passwordprotected} = 1 if $message->{passwordprotected};
      $reasons{nonpasswordprotected} = 1 if $message->{nonpasswordprotected};
      foreach $thisreason (sort keys %reasons) {
        $reasons .= " : " if $reasons ne "";
        $reasons .= MailScanner::Config::LanguageValue($message, "notice" .
                                                       $thisreason);
      }
      $headers{$postie} =~ s/\nSubject:.*?\n/\nSubject: $reasons\n/si;

      $notices{$postie} .= $message->CreatePostmasterNotice();
      unless ($signatures{$postie}) {
        $sig = MailScanner::Config::Value('noticesignature', $message);
        $sig =~ s/\\n/\n/g;
        $signatures{$postie} = $sig;
      }
    }
    $counter++;
  }
  while(($postie,$notice) = each %notices) {
    $email = $headers{$postie} . "\n" .
      #MailScanner::Config::LanguageValue($message, 'noticeheading') . ":\n" .
      #$notices{$postie} . "\n" . $signatures{$postie} . "\n";
      MailScanner::Config::LanguageValue($message, 'noticeprefix') . ": " .
      $reasons . "\n" . $notices{$postie} . "\n" . $signatures{$postie} . "\n";

    $global::MS->{mta}->SendMessageString(undef, $email, $postie) or
      MailScanner::Log::WarnLog("Could not notify postmaster from $postie, %s",
                                $!);
  }

  MailScanner::Log::NoticeLog("Notices: Warned about %d messages", $counter)
    if $counter;
}


# Disinfect the cleaned messages as far as possible,
# then deliver the disinfected attachments.
# The only messages left on disk are
# 1. the unparsable ones, which I am about to delete anyway, and
# 2. the cleaned ones, which is what I want to work on.
sub DisinfectAndDeliver {
  my $this = shift;

  my($id, $message, @interesting);

  # Delete all the unparsable messages from disk,
  # and all the messages with "whole body" infections
  # such as DoS attacks.
  while(($id, $message) = each %{$this->{messages}}) {
    if ($message->{deleted} ||
        $message->{dontdeliver} ||
        $message->{cantparse} ||
        $message->{badtnef} ||
        $message->{nameinfected} ||
        $message->{cantdisinfect} ||
        ($message->{allreports} && $message->{allreports}{""}) ||
        !MailScanner::Config::Value('deliverdisinfected',$message)) {
      $message->DeleteMessage();
    } else {
      if ($message->{virusinfected}) {
        #print STDERR "Found message $id to be worth disinfecting\n";
        push @interesting, $id;
      }
    }
  }

  # Nothing to do?
  return unless @interesting;

  MailScanner::Log::NoticeLog("Disinfection: Attempting to disinfect %d " .
                            "messages", scalar(@interesting));

  # Save the infection reports, they will be needed to compare
  # with the post-disinfection reports.
  foreach $id (@interesting) {
    $message = $this->{messages}{$id};
    # Move its reports somewhere safe
    $message->{oldviruses} = $message->{virusreports};
    $message->{virusreports} = {}; # I want a new hashref
    $message->{virusinfected} = 0;    # Reset its status
  }

  # Re-scan the batch of messages (just for viruses)
  # with the disinfection settings.
  # This should not produce any output reports at all.
  #print STDERR "Calling disinfection code for messages " .
  #             join(', ', @interesting) . "\n";
  MailScanner::SweepViruses::ScanBatch($this, 'disinfect');

  # Throw away the disinfection reports if there are any
  foreach $id (@interesting) {
    $message->{virusreports} = {};
  }

  # Now re-scan the batch to find revised virus reports
  my $viruses = MailScanner::SweepViruses::ScanBatch($this, 'rescan');
  #print STDERR "Revised scanning found $viruses viruses\n";
  MailScanner::Log::NoticeLog("Disinfection: Rescan found only %d viruses",
                            $viruses+0);

  # Look through the original list of reports, finding reports that
  # were present in the old list that are not in the new list.
  foreach $id (@interesting) {
    $this->{messages}{$id}->DeliverDisinfectedAttachments();
  }
}


# Copy raw message files to archive directories
sub ArchiveToFilesystem {
  my $this = shift;

  my($id, $message, $DidAnything, $log);

  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted};
    $DidAnything = $message->ArchiveToFilesystem();
    $log .= " " . $id if $DidAnything;
  }

  MailScanner::Log::NoticeLog("Saved archive copies of%s", $log) if $log;
}


# Strip the HTML out of messages that need to be stripped,
# either because strip ruleset says they should be stripped
# or because striphtml was one of the spam actions.
sub StripHTML {
  my $this = shift;

  my($id, $message);
  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};
    next unless $message->{needsstripping};
    $message->StripHTML();
  }
}


# Disarm some of the HTML tags in messages.
sub DisarmHTML {
  my $this = shift;

  my($id, $message);
  while(($id, $message) = each %{$this->{messages}}) {
    #print STDERR "In MessageBatch, tags are " .
    #             $message->{tagstoconvert} . "\n";
    next if $message->{deleted} || $message->{dontdeliver};
    next unless $message->{tagstoconvert};
    $message->DisarmHTML();
  }
}


# Turn the entire message into an RFC822 attachment off a multipart
# message, if this is one of their spam/ham actions.
sub Encapsulate {
  my $this = shift;

  my($id, $message);
  while(($id, $message) = each %{$this->{messages}}) {
    next if $message->{deleted} || $message->{dontdeliver};
    next unless $message->{needsencapsulating};
    $message->EncapsulateMessage();
  }
}

# Add the virus statistics to the SpamAssassin results cache
# so we know to keep the cache record for much longer.
sub AddVirusInfoToCache {
  my $this = shift;

  my($id, $message);
  while(($id, $message) = each %{$this->{messages}}) {
    MailScanner::SA::AddVirusStats($message);
  }
}


# This simply evaluates a known configuration parameter for every message
# in the batch, whether it has been deleted or not. This solely exists so
# that the lookup can be a Custom Function that has "side-effects" such
# as logging data about the message.
sub LastLookup {
  my $this = shift;

  my $start = time;

  my($id, $message);
  while(($id, $message) = each %{$this->{messages}}) {
    MailScanner::Config::Value('lastlookup', $message);
  }

  unless (MailScanner::Config::IsSimpleValue('lastlookup') &&
          !MailScanner::Config::Value('lastlookup')) {
    MailScanner::Log::InfoLog("\"Always Looked Up Last\" took %.2f seconds",
                              time-$start+0.0)
      if MailScanner::Config::Value('logspeed') =~ /1/;
  }

  # Lookup one remaining value after end of batch
  # Putting in $this is against the rules as it isn't a message,
  # but it doesn't actually cause any problems and gives MailWatch
  # a way of getting hold of the batch statistics.
  MailScanner::Config::Value('lastafterbatch', $this);
}

sub CreateEicarBatch {
  my $batch = shift;

  #print STDERR "Creating EICAR batch\n";
  my $headerfileumask = $global::MS->{work}->{fileumask};

  $batch->{messages} = {};
  $batch->{totalmessages} = 1;
  umask $headerfileumask;
  # Create and write the header file
  # Message number = 1
  # Path = irrelevant as we're not actually reading anything
  # It's a fake that we simulate ==> 1
  my $MessageDir = tempdir( 'MSlintXXXXXX', TMPDIR => 1, CLEANUP => 1);
  my $newmessage = MailScanner::Message->new(1, $MessageDir, 0, 1);
  @{$newmessage->{headers}} = ();
  @{$newmessage->{to}} = ();
  @{$newmessage->{touser}} = ();
  @{$newmessage->{todomain}} = ();
  $newmessage->{size} = 200;
  $newmessage->{from} = 'sender@example.com';
  $newmessage->{fromuser} = 'sender';
  $newmessage->{fromdomain} = 'example.com';
  push @{$newmessage->{to}}, 'recip@example.com';
  push @{$newmessage->{touser}}, 'recip';
  push @{$newmessage->{todomain}}, 'example.com';
  $newmessage->{clientip} = '10.1.1.1';
  $newmessage->{subject} = 'Virus Scanner Test Message';
  push @{$newmessage->{headers}}, ('From: <sender@example.com>',
                                   'To: <recip@example.com>',
                                   'Subject: Virus Scanner Test Message',
                                   'Mime-Version: 1.0',
                                   'Content-Type: application/octet-stream; name="eicar.com"',
                                   'Content-Transfer-Encoding: base64',
'Content-Disposition: attachment; filename="eicar.com"'
  );

  $newmessage->{virusinfected} = 0;
  $newmessage->{stillwarn} = 0;
  $newmessage->{scanmail} = 1;

  # Write out the .header file
  $newmessage->WriteHeaderFile();

  # Create a file of the body
  my($fh, $temporaryname);
  ($fh, $temporaryname) = tempfile()
    or die "Could not create temp file $temporaryname for test message, $!";
  # This is a Base64-encoded, then ROT13-encoded copy of the EICAR test string.
  # Had to ROT13 it, otherwise new clamd detects it and quarantines this file.
  my $eicarstring = "JQICVINyDRSDJmEpHScLAGDbHS4cA0AQXGq9WRIWD0SFYIAHDH5RDIWRYHSBIRyJFIWIHl1HEIAH\nYHMWGRHuWRteFPb=\n";
  $eicarstring =~ tr[a-zA-Z][n-za-mN-ZA-M]; # Undo ROT13 encoding
  print $fh $eicarstring;

  $fh->close();
  $newmessage->{store}->{dpath} = $temporaryname;

  # Add it to the batch
  $batch->{messages}{"1"} = $newmessage;
  $newmessage->NeedsScanning(1);

  umask 0077;
}

# JKF 20090301 Delete all entries from the processed database table
# which have been successfully processed. Anything with the "abandoned"
# property will not be removed, all other members of the batch will be.
sub ClearOutProcessedDatabase {
  my $this = shift;

  # Don't forget the master switch!
  return unless MailScanner::Config::Value('procdbattempts');

  # Clear out the entries for all the messages in the batch that don't
  # have "abandoned" set, and all the entries in "{deleted}" property
  # of the batch as well, space-separated list.
  my $sth = $MailScanner::SthDeleteId;
  #ProcDBH->prepare("DELETE FROM processing WHERE (id=?)");
  MailScanner::Log::DieLog("Database complained about this: %s. I suggest you delete your %s file and let me re-create it for you", $DBI::errstr, MailScanner::Config::Value("procdbname")) unless $sth;

  my($id, $message, $count, %gotridof);
  $count = 0;
  while(($id, $message) = each %{$this->{messages}}) {
    next unless $message;
    # Skip this message if it succeeded or failed due to global failure,
    # e.g. disk space.
    next if $message->{abandoned};
    # Delete this $message->{id} from the database table
    #my $rows = $sth->execute($id);
    #print STDERR "Delete1: Rows = $rows\n";
    #$count++ if $rows;
    $gotridof{$id} = 1;
  }
          
  foreach $id (split " ", $this->{deleted}) {
    next unless $id;
    # Delete this $message->{id} from the database table
    #my $rows = $sth->execute($id);
    #print STDERR "Delete2: Rows = $rows\n";
    #$count++ if $rows;
    $gotridof{$id} = 1;
  }

  foreach $id (keys %gotridof) {
    next unless $id;
    #$sth->bind_param(1, "$id", SQL_VARCHAR);
    $sth->execute("$id");
    #$MailScanner::ProcDBH->do("DELETE FROM processing WHERE (id='$id')");
  }
  #$sth->finish;

  $count = keys %gotridof;
  MailScanner::Log::InfoLog("Deleted %d messages from processing-database",
                             $count);
}

# If we are killed while processing a batch, then decrement the counter by 1
# for each message in the batch. If that gives a counter of 0 then delete
# the record from the database altogether.
sub DecrementProcDB {
  my($this) = @_;

  return unless $this;
  return unless $MailScanner::ProcDBH;

  my($id, $message, @attempts);

  my $selectsth = $MailScanner::SthSelectCount; #ProcDBH->prepare(
  #                "SELECT count FROM processing WHERE (id=?)");
  my $deletesth = $MailScanner::SthDeleteId; #ProcDBH->prepare(
  #                "DELETE FROM processing WHERE (id=?)");
  my $updatesth = $MailScanner::SthDecrementId; #ProcDBH->prepare(
  #                "UPDATE processing SET count=count-1 WHERE (id=?)");

  while(($id, $message) = each %{$this->{messages}}) {
    $selectsth->execute($id);
    @attempts = $selectsth->fetchrow_array();
    if (@attempts) {
      # There is a record, so delete it or decrement it
      if ($attempts[0]>1) {
        # Decrement it
        $updatesth->execute($id);
      } else {
        # Delete it
        $deletesth->execute($id);
      }
    }
  }

  # Remove all the messages which have already been deleted from the batch.
  foreach $id (split " ", $this->{deleted}) {
    next unless $id;
    # Delete this $message->{id} from the database table
    $deletesth->execute($id);
  }

  # Clear up
  #$selectsth->finish;
  #$deletesth->finish;
  #$updatesth->finish;
}

# Delete all the messages from the batch. Used when none of the virus
# scanners worked and we have been told to not process mail when the
# scanners are all dead.
sub DropBatch {
  my($this) = @_;

  return unless $this;

  while(my($id, $message) = each %{$this->{messages}}) {
    $message->{deleted} = 1;
    $message->{gonefromdisk} = 1; # Don't try to delete the original
    $message->{store}->Unlock(); # Unlock it so other processes can pick it up
  }

  # This is a very good place for a snooze.
  # If the entire batch has been abandoned, it will instantly loop all the
  # way around and try to pick up the same messages into a new batch.
  # This will cause the CPU load and disk load to go through the roof as it
  # will run away with itself trying to collect batches and them drop them
  # again.
  sleep 10;
}


1;

