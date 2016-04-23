#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: SweepContent.pm 5044 2010-07-31 16:58:58Z sysjkf $
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

package MailScanner::SweepContent;

use strict 'vars';
use strict 'refs';
no  strict 'subs'; # Allow bare words for parameter %'s

use MIME::Head;
use DirHandle;

use vars qw($VERSION);

### The package version, both in 1.23 style *and* usable by MakeMaker:
$VERSION = substr q$Revision: 5044 $, 10;

# Attributes are
#

# Constructor.
sub new {
  my $type = shift;
  my $this = {};

  bless $this, $type;
  return $this;
}

# Do all the message content scanning in here
sub ScanBatch {
  my $batch = shift;
  my $ScanType = shift;

  # Insert your own checking here.

  # In $BaseDir, you will find a directory for each message, which has the
  # same name as the message id. Also there is a messageid.header file
  # containing all the headers for the message.
  # Add entries into %$infections, where they are referenced as
  # $infections->{"message id"}{"filename"} but please don't over-write ones
  # that are already there.
  # If the danger was detected in a header or applies to the whole message
  # then append the error report (and a newline) to
  # $infections->{"message id"}{""}.
  # Return the number of infections/problems you found.
  # Can play with the MIME headers of a message using $mime.

  my($id,$message,$ent,$partialcount);
  my($stripdangerous, $counter, $stripcounter);
  $counter = 0;
  $stripcounter = 0; # No. of messages we need to strip HTML from

  $0 = 'MailScanner: dangerous content scanning';
  while(($id, $message) = each %{$batch->{messages}}) {
    next if $message->{deleted};
    next if $message->{scanvirusonly};

    $ent = $message->{entity};

    #
    # Do the partial and external checks even if they don't want
    # dangerous content scanning, as they directly affect our ability
    # to scan for viruses.
    #

    # Search for multipart/partial messages. This is entity-based as
    # the last part of the message (which is what is split into the
    # next message) probably won't have a filename.
    if ((! MailScanner::Config::Value('allowpartial', $message)) &&
        FindPartialMessage($message, $ent)) {
      #$message->{otherreports}{""} .=
      #  MailScanner::Config::LanguageValue($message, 'partialmessage') . "\n";
      #$message->{othertypes}{""} .= "e";
      #$message->{otherinfected}++;
      $counter++;
      # Force replacement of the last bit of the MIME message
      #$message->{entityreports}{LastEntity($message, $ent)} .=
      #  "Fragmented messages cannot be reliably scanned\n";
      MailScanner::Log::WarnLog('Content Checks: Detected and rejected ' .
                                'fragmented message section in %s', $id);
    }

    # Search for message/external-body messages. This is entity-based
    # as, almost by definition, we won't have the filename worked out
    # for the file that is external.
    if ((! MailScanner::Config::Value('allowexternal', $message)) &&
        FindExternalBody($message, $ent)) {
      $counter++;
      MailScanner::Log::WarnLog('Content Checks: Detected and rejected ' .
                                'external message body in %s', $id);
    }

    # Do the remaining checks if any recipient wants dangerous content checking
    next unless MailScanner::Config::Value('dangerscan', $message) =~ /1/;

    # Go through the attachments and remove any that are bigger than this
    # user/domain/site is allowed.
    my $maxmessagesize = MailScanner::Config::Value('maxmessagesize', $message);
    $message->{maxmessagesize} = $maxmessagesize; # Store it for reporting
    if ($maxmessagesize>0 && $message->{size}>$maxmessagesize) {
      MailScanner::Log::WarnLog("Content Checks: Message %s is bigger than " .
                                "%d bytes", $message->{id}, $maxmessagesize);
      $message->{otherreports}{""} .=
        MailScanner::Config::LanguageValue($message, 'toobig') . ": " .
                                           $message->{size} . " bytes\n";
      $message->{othertypes}{""} .= "s";
      $message->{sizeinfected}++;
      $counter++;
    }

    # Check all the files for the attachment-size limit
    $counter += CheckAttachmentSizes($message, $id);

    # Search for Microsoft-specific attacks
    # Disallow both by default. Allow them only if all addresses agree.
    my $iframevalue = MailScanner::Config::Value('allowiframetags', $message);
    my $objectvalue = MailScanner::Config::Value('allowobjecttags', $message);
    my $formvalue   = MailScanner::Config::Value('allowformtags',   $message);
    my $scriptvalue = MailScanner::Config::Value('allowscripttags', $message);
    my $webbugvalue = MailScanner::Config::Value('allowwebbugtags', $message);
    my $phishingvalue = MailScanner::Config::Value('findphishing',  $message);
    my $allowiframes = 0;
    my $allowobjects = 0;
    my $allowforms   = 0;
    my $allowscripts = 0;
    my $allowwebbugs = 0;
    my $convertiframes = 0;
    my $convertobjects = 0;
    my $convertforms   = 0;
    my $convertscripts = 0;
    my $convertwebbugs = 0;
    my $allowphishing = 0;
    # Allow the tags only if everyone allows them
    $allowiframes = 1 if $iframevalue =~ /^[1\s]+$/;
    $allowobjects = 1 if $objectvalue =~ /^[1\s]+$/;
    $allowforms   = 1 if $formvalue   =~ /^[1\s]+$/;
    $allowscripts = 1 if $scriptvalue =~ /^[1\s]+$/;
    $allowwebbugs = 1 if $webbugvalue =~ /^[1\s]+$/;
    $allowphishing =1 if $phishingvalue !~ /1/;
    # Convert the tags if no-one blocks them and someone converts them
    $convertiframes = 1 if $iframevalue !~ /0/ && $iframevalue =~ /convert/i;
    $convertobjects = 1 if $objectvalue !~ /0/ && $objectvalue =~ /convert/i;
    $convertforms   = 1 if $formvalue   !~ /0/ && $formvalue   =~ /convert/i;
    $convertscripts = 1 if $scriptvalue !~ /0/ && $scriptvalue =~ /convert/i;
    $convertwebbugs = 1 if $webbugvalue !~ /0/ && $webbugvalue =~ /convert/i;
    $stripdangerous = MailScanner::Config::Value('stripdangeroustags',$message);

    #print STDERR "WebBugvalue = $webbugvalue\n";
    #print STDERR "Allowforms = $allowforms and convertforms = $convertforms\n";

    #print STDERR "Allowphishing = $allowphishing\n";

    # Shortcut the check completely if they want to allow everything
    # and are not converting nasty tags to text
    if (!($allowiframes && $allowforms && $allowscripts && $allowobjects &&
          $allowphishing && !$stripdangerous) &&
        FindHTMLExploits($message, $id, $ent,
                         $allowiframes, $allowobjects, $allowforms,
                         $allowscripts, $allowwebbugs,
                         $convertiframes, $convertobjects, $convertforms,
                         $convertscripts, $convertwebbugs,
                         $stripdangerous)) {
      $counter++;
      MailScanner::Log::WarnLog('Content Checks: Detected HTML-' .
                                'specific exploits in %s', $id);
    }

    # Look for encrypted messages. They can allow some and block some
    # so we need to find the messages then apply the rules to the result.
    my $reason;
    my $encrypted = EncryptionStatus($message, $ent);
    if ($encrypted && MailScanner::Config::Value('blockencrypted',
                                                 $message) =~ /1/) {
      $reason = 'encrypted';
    }
    if (!$encrypted && MailScanner::Config::Value('blockunencrypted',
                                                  $message) =~ /1/) {
      $reason = 'unencrypted';
    }
    if ($reason) {
      $message->{otherreports}{""} .= MailScanner::Config::LanguageValue(
                                      $message, $reason) . "\n";
      $message->{othertypes}{""} .= "e";
      #$message->{otherinfected}++;
      $counter++;
      MailScanner::Log::WarnLog('Content Checks: Detected and blocked ' .
                                '%s message in %s', $reason, $id);
    }

    # Replace the MIME boundary string, for any multipart/alternative
    # sections inside multipart/mixed sections, where the outer
    # boundary is a substring of the inner boundary. Works around bugs
    # in the Cyrus IMAP server, and some old versions of Eudora.
    FixSubstringBoundaries($message, $id);

    # Check for nasty subject lines and quietly fix them
    FixMaliciousSubjects($message);

    # Find and save all the public keys (X.509 and PGP) in each message.
    #ExtractPublicKeys($message, $ent)
    #  if MailScanner::Config::Value('archivepublickeys', $message);

    # Convert text/html components into text/plain attachments.
    # Do this if any of the recipients need it done.
    # This involves forcing the message to rebuild itself from the
    # MIME structure. We will end up replacing MIME entities in the
    # message with ones pointing to new files/strings.
    if (MailScanner::Config::Value('htmltotext', $message) =~ /1/) {
      $message->{needsstripping} = 1;
      $stripcounter++;
      #MailScanner::Log::InfoLog('Content Checks: Detected and will convert ' .
      #                          'HTML message to plain text in %s', $id);
      #$message->{otherreports}{""} .= "Converted HTML to plain text\n";
      #$message->{othertypes}{""} .= "m"; # Modified body, but no infection
    }
  }

  # Print just a summary of the HTML stripping that needs doing
  MailScanner::Log::InfoLog('Content Checks: Need to convert HTML to plain ' .
                 'text in %s messages', $stripcounter) if $stripcounter>0;
  return $counter;
}


# Remove all trailing space from the subject line and remove any large
# blocks of spaces.
sub FixMaliciousSubjects {
  my($message) = @_;

  my $subject = $message->{subject};
  my $newsubject = $subject;
	# will break things like dkim 
	# j benton 30 jan 2016
  #$newsubject =~ s/\s{20,}.*\..{1,4}\s*$//; # Delete file extensions at end of filename
  #$newsubject =~ s/\s*$//g;
  #$newsubject =~ s/\s{20,}//g;

  # If it has changed then force an update
  #print STDERR "Message metadata is:\n" . join("\n", @{$message->{metadata}}) . "\n";
  if ($newsubject ne $subject) {
    $message->{subjectwasunsafe} = 1;
    $message->{safesubject} = $newsubject;
    #$global::MS->{mta}->ReplaceHeader($message, 'Subject:', $newsubject);
  } else {
    $message->{subjectwasunsafe} = 0;
    $message->{safesubject} = $message->{subject};
  }
}

# Check each of the file attachments to make sure they are all within
# the acceptable limit. Replace each one that's too big with a warning
# message.
sub CheckAttachmentSizes {
  my($message, $id) = @_;

  my($BaseDir, $basefh, $safename, $maxsize, $attachsize, $tnefname);
  my($unsafename, $counter, $minsize, $attachentity);

  # Read the configuration setting, value<=0 implies setting not in use.
  $maxsize = MailScanner::Config::Value('maxattachmentsize', $message);
  $minsize = MailScanner::Config::Value('minattachmentsize', $message);
  return 0 if $maxsize<0 && $minsize<0;
  $tnefname = substr($message->{tnefname},1); # Without type inndicator

  # Get into the directory containing all the attachments
  $BaseDir = $global::MS->{work}->{dir} . "/$id";
  chdir $BaseDir or die "Cannot chdir to $BaseDir for file size checking, $!";

  $basefh = new DirHandle;
  $basefh->open('.')
    or MailScanner::Log::DieLog("Could not open attachment dir %s, %s",
                                $BaseDir, $!);
  $counter = 0;
  while ($safename = $basefh->read()) {
    next if $safename eq '.' || $safename eq '..';

    # "Safe" attachment filename is in $safename, this is what we stat
    $attachsize = -s "$BaseDir/$safename";
    $unsafename = $message->{safefile2file}{$safename} || $tnefname;
    $attachentity = $message->{file2entity}{$unsafename};
    next unless $attachentity; # Only check attachment, not contents of zips
    next if $safename =~ /^.msg[-\d]+\.(txt|html)$/;
    #print STDERR "\nSafename = $safename\n";
    #print STDERR "Attachsize=$attachsize\nMin=$minsize\nMax=$maxsize\n";
    if ($maxsize>=0 && $attachsize > $maxsize) {
      #print STDERR "$safename is too big $attachsize > $maxsize\n";
      #print STDERR "Unsafename is $unsafename\n";
      MailScanner::Log::NoticeLog("Attachment size check: %s > %s (%s) in %s",
                                $attachsize, $maxsize, $unsafename, $id);
      $message->{otherreports}{$safename} .=
       MailScanner::Config::LanguageValue($message,'attachmenttoolarge') .
         ": $attachsize bytes\n";
      $message->{othertypes}{$safename}   .= "s";
      $counter++;
      $message->{sizeinfected}++;
    }
    if ($minsize>=0 && $attachsize < $minsize) {
      #print STDERR "Attachment is too small\n";
      MailScanner::Log::NoticeLog("Attachment size check: %s < %s (%s) in %s",
                                $attachsize, $minsize, $unsafename, $id);
      $message->{otherreports}{$safename} .=
       MailScanner::Config::LanguageValue($message,'attachmenttoosmall') . "\n";
      $message->{othertypes}{$safename}   .= "s";
      $counter++;
      $message->{sizeinfected}++;
    }
  }

  return $counter;
}



# Walk the entire tree of a message, looking for any
# Content-type: message/partial
# headers.
# Write an entity report about them so we keep the rest of the message.
sub FindPartialMessage {
  my($message, $entity) = @_;

  # Track number of dangerous things found
  my $counter = 0;

  # Reached a leaf node?
  return 0 unless $entity && defined($entity->head);

  # Mark the message as a problem if it's a "message/partial"
  my $type = $entity->head->mime_attr('content-type');
  if ($type && $type =~ /message\/partial/i) {
    #print STDERR "Found partial message at entity $entity\n";
    # Found one, so work out where it's stored and quarantine it
    my $body = $entity->bodyhandle;
    my $bodypath;
    if ($body) {
      $bodypath = $entity->bodyhandle->path;
    } elsif ($entity->parts) {
      my $part = $entity->parts(0);
      $bodypath = $part->bodyhandle->path if $part && $part->bodyhandle;
    } else {
      $bodypath = "";
    }
    $bodypath =~ s/^.*\///; # Just want the filename
    if ($bodypath) {
      $message->{otherreports}{$bodypath} .=
        MailScanner::Config::LanguageValue($message, 'partialmessage') . "\n";
      $message->{othertypes}{$bodypath} .= 'e';
    }
    $message->{otherinfected}++;
    $counter++;
    #$message->{entityreports}{$entity} .=
    #  MailScanner::Config::LanguageValue($message, 'partialmessage') . "\n";
    #$message->{entitytypes}{$entity} .= "e";
  }

  # Now try the same on all the parts
  my(@parts, $part);
  @parts = $entity->parts;
  foreach $part (@parts) {
    $counter += FindPartialMessage($message, $part);
  }

  return $counter;
}


# Find the last MIME entity in the tree. This will be the part that
# we need to replace if we found a message/partial.
# This is no longer used. We did try to just clean out the split
# attachments in partial messages, but it isn't feasible to do. Sorry.
sub LastEntity {
  my($message, $entity) = @_;
  my($NumParts);

  #print STDERR "Looking for LastEntity of $message\n";
  #print STDERR "Skeleton is " . $entity->dump_skeleton() . "\n";
  # Is this a nested entity? If so, search the last part of it
  if ($entity && !$entity->bodyhandle) {
    # How many parts?
    $NumParts = $entity->parts;
    #print STDERR "Message is multipart with $NumParts parts\n";
    return LastEntity($message, $entity->parts($NumParts-1)) if $NumParts>0;
    return $entity; # NumParts == 0 so it's not actually multipart at all
  } else {
    # It's not multipart, so I must be at the end
    return $entity;
  }
}

# Look through all the message parts finding text/html entities
# that contain Microsoft-specific exploits.
sub FindHTMLExploits {
  my($message, $id, $entity, $allowiframes, $allowobjects, $allowforms,
     $allowscripts, $allowwebbugs,
     $convertiframes, $convertobjects, $convertforms, $convertscripts,
     $convertwebbugs,
     $stripdangerous) = @_;

  # Track number of dangerous things found
  my $counter = 0;

  # Reached a leaf node?
  return 0 unless $entity && defined($entity->head);

  # Look for text/html sections
  my $type = $entity->head->mime_attr('content-type');
  #my $disposition = $entity->head->mime_attr('content-disposition');
  #$disposition = 'inline' unless $disposition;
  if ($type && $type =~ /text\/html/i &&
      #$disposition !~ /attachment/i &&
      defined($entity->bodyhandle) &&
      defined($entity->body) &&
      defined($entity->bodyhandle->path)) {
    $counter += SearchHTMLBody($message, $id, $entity->bodyhandle->path,
                               $allowiframes, $allowobjects, $allowforms,
                               $allowscripts, $allowwebbugs,
                               $convertiframes, $convertobjects, $convertforms,
                               $convertscripts, $convertwebbugs,
                               $stripdangerous);
  }

  # Now try the same on all the parts
  my(@parts, $part);
  @parts = $entity->parts;
  foreach $part (@parts) {
    $counter += FindHTMLExploits($message, $id, $part,
                               $allowiframes, $allowobjects, $allowforms,
                               $allowscripts, $allowwebbugs,
                               $convertiframes, $convertobjects, $convertforms,
                               $convertscripts, $convertwebbugs,
                               $stripdangerous);
  }

  return $counter;
}


# Search an HTML part of the message body for dangerous HTML
# that either uses the <IFRAME> tag or the <OBJECT CODEBASE=...> tag.
sub SearchHTMLBody {
  my($message, $id, $filename, $allowiframes, $allowobjects, $allowforms,
     $allowscripts, $allowwebbugs,
     $convertiframes, $convertobjects, $convertforms, $convertscripts,
     $convertwebbugs,
     $stripdangerous) = @_;

  my($fh, $counter, $silentviruses);
  $counter = 0;
  $fh = new FileHandle;
  if ($fh->open("$filename")) {

    my $loggingtags = MailScanner::Config::Value('loghtmltags', $message);

    # Search the file
    my $inobject    = 0;
    my $iframefound = 0;
    my $formfound   = 0;
    my $scriptfound = 0;
    my $webbugfound = 0;
    my $phishingfound = 0;
    my $codebasefound = 0;
    my $attach = $filename;
    $attach = $1 if $filename =~ /([^\/]+)$/; # Strip off the path
    while(<$fh>) {
      # Skip whitespace lines
      next if /^\s*$/;

      # Find the iframe tag start, but only if we're not allowed them
      $iframefound = 1 if /\<iframe/i;
        
      # Find the form tag start
      $formfound = 1 if /\<form/i;

      # Find the script tag start
      $scriptfound = 1 if /\<script/i;

      # Find the img tag start
      $webbugfound = 1 if /\<img/i;

      # Find the link tag start
      $phishingfound = 1 if /\<a/i;

      # Find the object tag start
      $inobject = 1 if /\<object/i;

      # Find a codebase or data within an object tag
      $codebasefound = 1 if $inobject && /codebase|data/i;

      # Find the object tag end
      $inobject = 0 if /\<\/object/i;
    }
    $fh->close();

    # Get this so we can set the silent flag if they don't want reports
    # about IGrames or Object-Codebases
    $silentviruses = ' ' .  MailScanner::Config::Value('silentviruses',
                     $message) . ' ';

    if ($phishingfound && MailScanner::Config::Value('findphishing', $message)){
      # Log the <A>
      MailScanner::Log::InfoLog("<A> tag found in message %s from %s",
        $id, $message->{from}) if $loggingtags;
      # Mark the message
      $message->{tagstoconvert} .= 'phishing ';
      #$message->{bodymodified}   = 1;
    }
    if ($iframefound) {
      # Log the <IFrame>
      MailScanner::Log::NoticeLog("HTML-IFrame tag found in message %s from %s",
        $id, $message->{from}) if $loggingtags;
      # Mark the message
      if ($allowiframes) {
        if ($stripdangerous) {
          $message->{needsstripping} = 1;
          $message->{bodymodified}   = 1; # Mark it for rebuilding
          $counter++;
        }
      } elsif ($convertiframes) {
        $message->{tagstoconvert} .= 'iframe ';
        $message->{bodymodified}   = 1;
      } else {
        $message->{otherreports}{"$attach"} .= 
          MailScanner::Config::LanguageValue($message, 'foundiframe') . "\n";
        $message->{othertypes}{"$attach"}   .= "c";
        $message->{otherinfected}++;
        $message->{silent} = 1 if $silentviruses =~ / HTML-IFrame /i;
        $counter++;
      }
    }
    if ($formfound) {
      ## Log the <Form>
      MailScanner::Log::NoticeLog("HTML-Form tag found in message %s from %s",
        $id, $message->{from}) if $loggingtags;
      # Mark the message
      if ($allowforms) {
        if ($stripdangerous) {
          $message->{needsstripping} = 1;
          $message->{bodymodified}   = 1; # Mark it for rebuilding
          $counter++;
        }
      } elsif ($convertforms) {
        $message->{tagstoconvert} .= 'form ';
        $message->{bodymodified}   = 1;
      } else {
        $message->{otherreports}{"$attach"} .=
          MailScanner::Config::LanguageValue($message, 'foundform') . "\n";
        $message->{othertypes}{"$attach"}   .= "c";
        $message->{otherinfected}++;
        $message->{silent} = 1 if $silentviruses =~ / HTML-Form /i;
        $counter++;
      }
    }
    if ($scriptfound) {
      ## Log the <script>
      MailScanner::Log::NoticeLog("HTML-Script tag found in message %s from %s",
        $id, $message->{from}) if $loggingtags;
      # Mark the message
      if ($allowscripts) {
        if ($stripdangerous) {
          $message->{needsstripping} = 1;
          $message->{bodymodified}   = 1; # Mark it for rebuilding
          $counter++;
        }
      } elsif ($convertscripts) {
        $message->{tagstoconvert} .= 'script ';
        $message->{bodymodified}   = 1;
      } else {
        $message->{otherreports}{"$attach"} .=
          MailScanner::Config::LanguageValue($message, 'foundscript') . "\n";
        $message->{othertypes}{"$attach"}   .= "c";
        $message->{otherinfected}++;
        $message->{silent} = 1 if $silentviruses =~ / HTML-Script /i;
        $counter++;
      }
    }
    if ($webbugfound) {
      ## Log the <img>
      MailScanner::Log::NoticeLog("HTML Img tag found in message %s from %s",
        $id, $message->{from}) if $loggingtags;
      #  if MailScanner::Config::Value('logwebbugs', $message);
      # Mark the message
      if ($allowwebbugs) {
        #print STDERR "Web Bug allowed\n";
        if ($stripdangerous) {
          #print STDERR "Web Bug stripped\n";
          $message->{needsstripping} = 1;
          $message->{bodymodified}   = 1; # Mark it for rebuilding
          $counter++;
        }
      } elsif ($convertwebbugs) {
        #print STDERR "Web Bug converted\n";
        $message->{tagstoconvert} .= 'webbug ';
        # Only mark it for rebuilding if we actually found a webbug
        # as we shouldn't rebuild if it was an innocent image
        #$message->{bodymodified}   = 1;
        #print STDERR "Going to disarm web bugs\n";
      } else {
        #print STDERR "Web Bug ignored\n";
        # Web bugs neither allowed nor converted. So must be stopped.
        $message->{otherreports}{"$attach"} .=
          MailScanner::Config::LanguageValue($message, 'foundwebbug') . "\n";
        $message->{othertypes}{"$attach"}   .= "c";
        $message->{otherinfected}++;
        $message->{silent} = 1 if $silentviruses =~ / HTML-WebBug /i;
        $counter++;
        1;
      }
    }
    if ($codebasefound) {
      MailScanner::Log::NoticeLog("HTML-Object tag found in message %s from %s",
        $id, $message->{from}) if $loggingtags;
      if ($allowobjects) {
        if ($stripdangerous) {
          $message->{needsstripping} = 1;
          $message->{bodymodified}   = 1; # Mark it for rebuilding
          $counter++;
        }
      } elsif ($convertobjects) {
        $message->{tagstoconvert} .= 'codebase data ';
        $message->{bodymodified}   = 1;
      } else {
        # Mark the message
        $message->{otherreports}{"$attach"} .=
          MailScanner::Config::LanguageValue($message, 'foundobject') . "\n";
        $message->{othertypes}{"$attach"}   .= "c";
        $message->{otherinfected}++;
        $message->{silent} = 1 if $silentviruses =~ / HTML-Codebase /i;
        $counter++;
      }
    }
  } else {
    MailScanner::Log::WarnLog("Could not search \"%s\" in message %s for " .
                              "dangerous HTML", $filename, $id);
    $counter++;
  }

  return $counter;
}


# Walk the entire tree of a message, looking for any
# Content-type: message/external-body
# headers. If we find any, write a report about them
# as we can't support them.
sub FindExternalBody {
  my($message, $entity) = @_;

  # Track number of dangerous things found
  my $counter = 0;

  # Reached a leaf node?
  return 0 unless $entity && defined($entity->head);

  # Mark the message as a problem if it's a "message/external-body"
  my $type = $entity->head->mime_attr('content-type');
  if ($type && $type =~ /message\/external-body/i) {
    #print STDERR "FindExternalBody: Found one at $entity\n";
    $message->{entityreports}{$entity} .=
      MailScanner::Config::LanguageValue($message, 'externalbody') . "\n";
    $message->{otherinfected}++;
    $counter++;
  }

  # Now try the same on all the parts
  my(@parts, $part);
  @parts = $entity->parts;
  foreach $part (@parts) {
    # Escape out of the tree if we found something
    $counter += FindExternalBody($message, $part);
  }

  return $counter;
}


# Search for any encrypted sections of the message.
# Bail out as soon as I find anything encrypted.
sub EncryptionStatus {
  my($message, $entity) = @_;

  # Reached a leaf nose?
  return 0 unless $entity && defined($entity->head);

  my $type = $entity->head->mime_attr('content-type');
  return 1 if ($type =~ /\/encrypted/i);

  # Now try the same on all the parts
  my(@parts, $part);
  @parts = $entity->parts;
  foreach $part (@parts) {
    # Escape out of the tree if we found something
    return 1 if EncryptionStatus($message, $part);
  }

  # Didn't find any trace of encryption
  return 0;
}

# Search for (and save) all the public keys stored in the current message.
# It currently finds PGP and X.509 public keys.
sub ExtractPublicKeys {
  my($message, $entity) = @_;

  # Reached a leaf node?
  return 0 unless $entity && defined($entity->head);

  my $type = $entity->head->mime_attr('content-type');
  if ($type =~ /application\/pgp-signature/i ||
      $type =~ /application\/x-pkcs7-signature/i) {
    SavePublicKey($message, $entity);
  }

  # Now try the same on all the parts
  my(@parts, $part);
  @parts = $entity->parts;
  foreach $part (@parts) {
    # Escape out of the tree if we found something
    ExtractPublicKeys($message, $part);
  }
}

# Save the entity out as a file named after the sender of the message
# and the date.
sub SavePublicKey {
  my($message, $entity) = @_;

  # Create filename of output file for public key
  my($date, $from, $keyfilename);

  # This is the yyyymmddhhmmss timestamp part
  my($sec,$min,$hour,$day,$month,$year);
  ($sec,$min,$hour,$day,$month,$year) = (localtime)[0,1,2,3,4,5];
  $month++;
  $year += 1900;
  $date = sprintf("%04d%02d%02d%02d%02d%02d",
                  $year, $month, $day, $hour, $min, $sec);

  # This is the email address part
  $from = lc($message->{from});
  $from =~ tr/a-z0-9_.\@\-//cd; # Delete all nasty characters

  # Now join it all together
  $keyfilename = MailScanner::Config::Value('publickeyarchivedir', $message) .
                 '/' . $date . '-' . $from;

  # Write the contents of the file out to a key archive
  my($keyfh);
  $keyfh = new FileHandle;
  unless ($keyfh->open(">$keyfilename")) {
    MailScanner::Log::WarnLog('Could not create public key file %s',
                              $keyfilename);
    return;
  }
  $entity->bodyhandle->print($keyfh);
  $keyfh->close();
}


#
# Search for multipart/alternative sections inside multipart/mixed
# sections, where the outer boundary is a substring of the inner boundary.
# This causes a problem for the Cyrus IMAP server and some old versions of
# Eudora, so make sure the 2 boundary strings are distinct.
#
sub FixSubstringBoundaries {
  my($message, $id) = @_;

  # Avoid messages with no MIME structure at all
  my $root = $message->{entity};
  return unless $root;

  # The top level must be multipart/mixed
  return unless $root->is_multipart && $root->head;

  my($topboundary, $innerboundary);

  # Read the top-level multipart boundary
  $topboundary = $root->head->multipart_boundary;
  $topboundary = quotemeta($topboundary); # We're going to use it in a regexp

  # Loop through all the top-level parts
  my($firstlevel, @toplevel, $changedit);
  @toplevel = $root->parts;
  $changedit = 0;
  foreach $firstlevel (@toplevel) {
    # Now look at $toplevel to find multipart sections within it
    next unless $firstlevel->is_multipart && $firstlevel->head;

    # This is a multipart section, so read its boundary
    $innerboundary = $firstlevel->head->multipart_boundary;
    #print STDERR "Inner boundary = \"$innerboundary\"\n";
    #print STDERR "Top   boundary = \"$topboundary\"\n";
    next unless $innerboundary =~ /$topboundary/;
    #print STDERR "top is a substring of inner\n";

    # We now know that topboundary is a substring of innerboundary
    $root->head->mime_attr("Content-type.boundary" =>
                   "__MailScanner_found_Cyrus_boundary_substring_problem__");
    # We need to build a report of it. This is special as it is just
    # a modification to the body, not actually a security problem.
    $changedit = 1;
    #$message->{otherreports}{""} .= "Eudora boundary substring bug\n";
    #$message->{othertypes}{""} .= "m"; # Modified body, but no infection
    #print STDERR "Fixed boundary.\n";
    last;
  }
  if ($changedit) {
    MailScanner::Log::WarnLog('Content Checks: Fixed awkward MIME boundary ' .
         'for Cyrus IMAP server in %s', $id);
    $message->{bodymodified} = 1;
  }
}

1;

