<?php
/*
** Auto-generated DefenderMX MailScanner GUI configuration guide
*/

$conf = array (
  'aallowfilemimetypes' => 
  array (
    'external' => 'archivesallowfilemimetypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'aallowfilenames' => 
  array (
    'external' => 'archivesallowfilenames',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'aallowfiletypes' => 
  array (
    'external' => 'archivesallowfiletypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'adenyfilemimetypes' => 
  array (
    'external' => 'archivesdenyfilemimetypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'adenyfilenames' => 
  array (
    'external' => 'archivesdenyfilenames',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'adenyfiletypes' => 
  array (
    'external' => 'archivesdenyfiletypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'afilenamerules' => 
  array (
    'external' => 'archivesfilenamerules',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'afiletyperules' => 
  array (
    'external' => 'archivesfiletyperules',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
  ),
  'ldapbase' => 
  array (
    'external' => 'ldapbase',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
  ),
  'ldapserver' => 
  array (
    'external' => 'ldapserver',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
  ),
  'ldapsite' => 
  array (
    'external' => 'ldapsite',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
  ),
  'publickeyarchivedir' => 
  array (
    'external' => 'publickeyarchivedir',
    'type' => 'dir',
    'ruleset' => 'first',
    'default' => '',
  ),
  'qmailhashdirectorynumber' => 
  array (
    'external' => 'qmailhashdirectorynumber',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '23',
  ),
  'qmailintdhashnumber' => 
  array (
    'external' => 'qmailintdhashnumber',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '1',
  ),
  'attachimageinternalname' => 
  array (
    'external' => 'signatureimageimgfilename',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '',
  ),
  'archivepublickeys' => 
  array (
    'external' => 'archivepublickeys',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
  ),
  'insistpasszips' => 
  array (
    'external' => 'archivesmustbepasswordprotected',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
  ),
  'mcpusespamassassin' => 
  array (
    'external' => 'mcpusespamassassin',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
  ),
  'sophosallowederrors' => 
  array (
    'external' => 'allowedsophoserrormessages',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Allowed Sophos Error Messages',
    'desc' => ' Anything on the next line that appears in brackets at the end of a line
 of output from Sophos will cause the error/infection to be ignored.
 Use of this option is dangerous, and should only be used if you are having
 trouble with lots of corrupt PDF files, for example.
 If you need to specify more than 1 string to find in the error message,
 then put each string in quotes and separate them with a comma.
 For example:
Allowed Sophos Error Messages = "corrupt", "format not supported", "File was encrypted", "The main body of virus data is out of date", "Password protected file"',
    'value' => '',
  ),
  'allowfilemimetypes' => 
  array (
    'external' => 'allowfilemimetypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Allow File MIME Types',
    'desc' => ' Allow any attachment MIME types matching any of the patterns listed here.
 If this setting is empty, it is ignored and no matches are made.
 This can also be the filename of a ruleset.',
    'value' => '',
  ),
  'allowfilenames' => 
  array (
    'external' => 'allowfilenames',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Allow Filenames',
    'desc' => ' Allow any attachment filenames matching any of the patterns listed here.
 If this setting is empty, it is ignored and no matches are made.
 This can also be the filename of a ruleset.',
    'value' => '',
  ),
  'allowfiletypes' => 
  array (
    'external' => 'allowfiletypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Allow Filetypes',
    'desc' => ' Allow any attachment filetypes matching any of the patterns listed here.
 If this setting is empty, it is ignored and no matches are made.
 This can also be the filename of a ruleset.',
    'value' => '',
  ),
  'antiword' => 
  array (
    'external' => 'antiword',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '/usr/bin/antiword -f',
    'name' => 'Antiword',
    'desc' => ' Location and full command of the "antiword" program
 Using a ruleset here, you could have different output styles for
 different people.
 This can also be the filename of a ruleset.',
    'value' => ' /usr/bin/antiword -f',
  ),
  'antiwordtimeout' => 
  array (
    'external' => 'antiwordtimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '50',
    'name' => 'Antiword Timeout',
    'desc' => ' The maximum length of time the "antiword" command is allowed to run for 1
 Word document (in seconds)',
    'value' => ' 50',
  ),
  'archivemail' => 
  array (
    'external' => 'archivemail',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Archive Mail',
    'desc' => ' Space-separated list of any combination of
 1. email addresses to which mail should be forwarded,
 2. directory names where you want mail to be stored,
 3. file names (they must already exist unless "Missing Mail Archive Is =
    directory" is set below) which mail will be appended
    in "mbox" format suitable for importing into most mail systems.

 Any of the items above can contain 3 magic strings, which are subsituted
 as follows:
 _DATE_       will be replaced with the current date in yyyymmdd format.
              This will make archive-rolling and maintenance much easier,
              as you can guarantee that yesterday\'s mail archive will not
              be in active use today.
 _HOUR_       will be replaced with the number of the current hour, with
              a leading zero if necessary to make it 2 digits.
 _TOUSER_     will be replaced with the left-hand side of the email
              address of each of the recipients in turn.
 _TODOMAIN_   will be replaced with the right-hand side of the email
              address of each of the recipients in turn.
 _FROMUSER_   will be replaced with the left-hand side of the email
              address of the sender.
 _FROMDOMAIN_ will be replaced with the right-hand side of the email
              address of the sender.

 If you give this option a ruleset, you can control exactly whose mail
 is archived or forwarded. If you do this, beware of the legal implications
 as this could be deemed to be illegal interception unless the police have
 asked you to do this.

 Note: This setting still works even if "Scan Messages" is no.

Archive Mail = /var/spool/MailScanner/archive',
    'value' => '',
  ),
  'archivesare' => 
  array (
    'external' => 'archivesare',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'zip rar ole',
    'name' => 'Archives Are',
    'desc' => ' What sort of attachments are considered to be archives?
 You may well consider, for example, zip and rar files to be archives, but
 maybe TNEF files to not be archives as they are really just another way
 of supplying attachments that is only used by Microsoft Exchange and Outlook.
 This is a space-separated list of the types which are treated as archives.
 Valid keywords within this are:
       zip  -- Zip files and Microsoft Office 2007 documents
       rar  -- Rar archives
       uu   -- UU-encoded files
       ole  -- Microsoft ".doc" and ".xls" and ".ppt" files
       tnef -- "winmail.dat" files created by Microsoft Exchange or Outlook',
    'value' => ' zip rar ole',
  ),
  'attachmentcharset' => 
  array (
    'external' => 'attachmentencodingcharset',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'ISO-8859-1',
    'name' => 'Attachment Encoding Charset',
    'desc' => ' What character set do you want to use for the attachment that
 replaces viruses (VirusWarning.txt)?
 The default is ISO-8859-1 as even Americans have to talk to the
 rest of the world occasionally :-)
 This can also be the filename of a ruleset.',
    'value' => ' ISO-8859-1',
  ),
  'attachzipignore' => 
  array (
    'external' => 'attachmentextensionsnottozip',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '.zip .rar .gz .tgz .mpg .mpe .mpeg .mp3 .rpm',
    'name' => 'Attachment Extensions Not To Zip',
    'desc' => ' Attachments whose filenames end in these strings will not be zipped.
 This can also be the filename of a ruleset.',
    'value' => ' .zip .rar .gz .tgz .jpg .jpeg .mpg .mpe .mpeg .mp3 .rpm .htm .html .eml',
  ),
  'attachzipminsize' => 
  array (
    'external' => 'attachmentsmintotalsizetozip',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '100000',
    'name' => 'Attachments Min Total Size To Zip',
    'desc' => ' If the original total size of all the attachments to be compressed is
 less than this number of bytes, they will not be zipped at all.
 This can also be the filename of a ruleset.',
    'value' => ' 100k',
  ),
  'attachzipname' => 
  array (
    'external' => 'attachmentszipfilename',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'MessageAttachments.zip',
    'name' => 'Attachments Zip Filename',
    'desc' => ' If the attachments are to be compressed into a single zip file,
 this is the filename of the zip file.
 This can also be the filename of a ruleset.',
    'value' => ' MessageAttachments.zip',
  ),
  'attachmentwarningfilename' => 
  array (
    'external' => 'attachmentwarningfilename',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'VirusWarning.txt',
    'name' => 'Attachment Warning Filename',
    'desc' => ' When a virus or attachment is replaced by a plain-text warning,
 and that warning is an attachment, this is the filename of the
 new attachment.
 This can also be the filename of a ruleset.',
    'value' => ' %org-name%-Attachment-Warning.txt',
  ),
  'clamavmaxratio' => 
  array (
    'external' => 'clamavmodulemaximumcompressionratio',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '250',
    'name' => 'ClamAVmodule Maximum Compression Ratio',
    'desc' => '',
    'value' => ' 250',
  ),
  'clamavmaxfiles' => 
  array (
    'external' => 'clamavmodulemaximumfiles',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '1000',
    'name' => 'ClamAVmodule Maximum Files',
    'desc' => '',
    'value' => ' 1000',
  ),
  'clamavmaxfilesize' => 
  array (
    'external' => 'clamavmodulemaximumfilesize',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '10000000',
    'name' => 'ClamAVmodule Maximum File Size',
    'desc' => '',
    'value' => ' 10000000 # (10 Mbytes)',
  ),
  'clamavmaxreclevel' => 
  array (
    'external' => 'clamavmodulemaximumrecursionlevel',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '8',
    'name' => 'ClamAVmodule Maximum Recursion Level',
    'desc' => ' ClamAVModule only: set limits when scanning for viruses.

 The maximum recursion level of archives,
 The maximum number of files per batch,
 The maximum file of each file,
 The maximum compression ratio of archive.
 These settings *cannot* be the filename of a ruleset, only a simple number.',
    'value' => ' 8',
  ),
  'clamdlockfile' => 
  array (
    'external' => 'clamdlockfile',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Clamd Lock File',
    'desc' => '',
    'value' => ' # /var/lock/clamd',
  ),
  'clamdport' => 
  array (
    'external' => 'clamdport',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '3310',
    'name' => 'Clamd Port',
    'desc' => ' Clamd only: configuration options for using the clamd daemon.
 1. The port to use when communicating with clamd via TCP connection
 2. The Socket, or IP to use for communicating with the clamd Daemon.
    You enter either the full path to the UNIX socket file or the IP
    address the daemon is listening on.
 3. The ClamD Lock file should be created by clamd init script in most
    cases. If it is not then the entry should be blank.
 4. If MailScanner is running on a system with more then 1 CPU core (or
    more than 1 CPU) then you can set "Clamd Use Threads" to "yes" to
    speed up the scanning, otherwise there is no advantage and it should
    be set to "no".

 None of these options can be the filenames of rulesets, they must be just
 simple values.',
    'value' => ' 3310',
  ),
  'clamdsocket' => 
  array (
    'external' => 'clamdsocket',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '127.0.0.1',
    'name' => 'Clamd Socket',
    'desc' => '',
    'value' => ' /tmp/clamd.socket',
  ),
  'cleanheader' => 
  array (
    'external' => 'cleanheadervalue',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'Found to be clean',
    'name' => 'Clean Header Value',
    'desc' => ' Set the "Mail Header" to these values for clean/infected/disinfected messages.
 This can also be the filename of a ruleset.',
    'value' => ' Found to be clean',
  ),
  'contentsubjecttext' => 
  array (
    'external' => 'contentsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Dangerous Content?}',
    'name' => 'Content Subject Text',
    'desc' => ' This is the text to add to the start of the subject if the
 "Content Modify Subject" option is set.
 You might want to change this so your users can see at a glance
 whether it just was just the content that MailScanner rejected.
 This can also be the filename of a ruleset.',
    'value' => ' {Dangerous Content?}',
  ),
  'secondlevellist' => 
  array (
    'external' => 'countrysubdomainslist',
    'type' => 'file',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/country.domains.conf',
    'name' => 'Country Sub-Domains List',
    'desc' => ' This file lists all the countries that use 2nd-level and 3rd-level
 domain names to classify distinct types of website within their country.
 This cannot be the name of a ruleset, it is just a simple setting.',
    'value' => ' %etc-dir%/country.domains.conf',
  ),
  'customfunctionsdir' => 
  array (
    'external' => 'customfunctionsdir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/usr/share/MailScanner/custom',
    'name' => 'Custom Functions Dir',
    'desc' => ' Where to put the code for your "Custom Functions". No code in this
 directory should be over-written by the installation or upgrade process.
 All files starting with "." or ending with ".rpmnew" will be ignored,
 all other files will be compiled and may be used with Custom Functions.',
    'value' => ' /usr/share/MailScanner/custom',
  ),
  'gstimeout' => 
  array (
    'external' => 'customspamscannertimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '20',
    'name' => 'Custom Spam Scanner Timeout',
    'desc' => ' How long should the custom spam scanner take to run? If it takes more
 seconds than this, then it should be considered to have crashed and
 should be killed. This stops denial-of-service attacks.',
    'value' => ' 20',
  ),
  'gstimeoutlen' => 
  array (
    'external' => 'customspamscannertimeouthistory',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '20',
    'name' => 'Custom Spam Scanner Timeout History',
    'desc' => ' The total number of Custom Spam Scanner attempts during which "Max
 Custom Spam Scanner Timeouts" will cause the Custom Spam Scanner to
 be marked as "unavailable". See the previous comment for more information.
 The default values of 10 and 20 mean that 10 timeouts in any sequence of
 20 attempts will trigger the behaviour described above, until the next
 periodic restart (see "Restart Every").',
    'value' => ' 20',
  ),
  'dbdsn' => 
  array (
    'external' => 'dbdsn',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'DB DSN',
    'desc' => ' If you wish to read settings from a database or any other DBI-compatible
 data source, then this value should be set to the DBI data source name.

 This value is required for all of the database functions to work; if it
 is not supplied or is invalid, then all of the database functions will be
 disabled.  See the Perl DBI documentation for all available options.

 Example: DB DSN = DBI:DriverName:database=DataBaseName;host=Hostname;port=Port',
    'value' => '',
  ),
  'dbpassword' => 
  array (
    'external' => 'dbpassword',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'DB Password',
    'desc' => ' Optional password to use to connect to the data source defined by DB DSN.',
    'value' => '',
  ),
  'dbusername' => 
  array (
    'external' => 'dbusername',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'DB Username',
    'desc' => ' Optional username to use to connect to the data source defined by DB DSN.',
    'value' => '',
  ),
  'defaultrenamepattern' => 
  array (
    'external' => 'defaultrenamepattern',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '__FILENAME__.disarmed',
    'name' => 'Default Rename Pattern',
    'desc' => ' In the "Filename Rules" and "Filetype Rules" rule files, you can
 say that you want particular attachment names or types to be "disarmed"
 by being renamed. See the sample files for examples of this.

 The "rename" rules in filetype.rules.conf rename attachments that match
 the rule according to this setting, where the string "__FILENAME__" will
 be replaced with the attachment\'s original filename.

 In filename.rules.conf, it is a little more complex. They can work just
 like the filetype rules.conf version explained in the previous paragraph,
 or else the "rename" instruction can also supply the replacement text.
 For example, a rule starting
 rename to .txt	\\.reg$	.....
 will match all attachment filenames ending in ".reg" and replace the
 ".reg" with ".txt".

 The "rename" rules change the filename of the attachment as described
 above, so that either
 (a) the user cannot simply double-click on the attachment, but must save
     it then rename it back to its original name; only then can they
     double-click on the file.
 OR
 (b) the action taken when the user double-clicks on the file will be
     changed. In the "reg"/"txt" example above, the file will be opened
     for editing rather than immediately merged into the user\'s Windows
     Registry, which could have had disastrous consequences.

 This provides a simple safeguard so that users have to consciously
 think about what they are doing, and do not accidentally take actions
 they would probably regret. In some situations this is better than
 just denying the file completely, as the user can still see the attachment
 they were sent.

 This can also be the filename of a ruleset.',
    'value' => ' __FILENAME__.disarmed',
  ),
  'deletedcontentmessage' => 
  array (
    'external' => 'deletedbadcontentmessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/deleted.content.message.txt',
    'name' => 'Deleted Bad Content Message Report',
    'desc' => ' Set where to find the message text sent to users when one of their
 attachments has been deleted from a message.
 These can also be the filenames of rulesets.',
    'value' => ' %report-dir%/deleted.content.message.txt',
  ),
  'deletedfilenamemessage' => 
  array (
    'external' => 'deletedbadfilenamemessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/deleted.filename.message.txt',
    'name' => 'Deleted Bad Filename Message Report',
    'desc' => '',
    'value' => ' %report-dir%/deleted.filename.message.txt',
  ),
  'deletedsizemessage' => 
  array (
    'external' => 'deletedsizemessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/deleted.size.message.txt',
    'name' => 'Deleted Size Message Report',
    'desc' => '',
    'value' => ' %report-dir%/deleted.size.message.txt',
  ),
  'deletedvirusmessage' => 
  array (
    'external' => 'deletedvirusmessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/deleted.virus.message.txt',
    'name' => 'Deleted Virus Message Report',
    'desc' => '',
    'value' => ' %report-dir%/deleted.virus.message.txt',
  ),
  'denyfilemimetypes' => 
  array (
    'external' => 'denyfilemimetypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Deny File MIME Types',
    'desc' => ' Deny any attachment MIME types matching any of the patterns listed here.
 If this setting is empty, it is ignored and no matches are made.
 This can also be the filename of a ruleset.',
    'value' => '',
  ),
  'denyfilenames' => 
  array (
    'external' => 'denyfilenames',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Deny Filenames',
    'desc' => ' Deny any attachment filenames matching any of the patterns listed here.
 If this setting is empty, it is ignored and no matches are made.
 This can also be the filename of a ruleset.',
    'value' => '',
  ),
  'denyfiletypes' => 
  array (
    'external' => 'denyfiletypes',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Deny Filetypes',
    'desc' => ' Deny any attachment filetypes matching any of the patterns listed here.
 If this setting is empty, it is ignored and no matches are made.
 This can also be the filename of a ruleset.',
    'value' => '',
  ),
  'disarmsubjecttext' => 
  array (
    'external' => 'disarmedsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Disarmed}',
    'name' => 'Disarmed Subject Text',
    'desc' => ' This is the text to add to the start of the subject if the
 "Disarmed Modify Subject" option is set.
 This can also be the filename of a ruleset.',
    'value' => ' {Disarmed}',
  ),
  'disinfectedheader' => 
  array (
    'external' => 'disinfectedheadervalue',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'Disinfected',
    'name' => 'Disinfected Header Value',
    'desc' => '',
    'value' => ' Disinfected',
  ),
  'disinfectedreporttext' => 
  array (
    'external' => 'disinfectedreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/disinfected.report.txt',
    'name' => 'Disinfected Report',
    'desc' => ' Set where to find the message text sent to users explaining about the
 attached disinfected documents.
 This can also be the filename of a ruleset.',
    'value' => ' %report-dir%/disinfected.report.txt',
  ),
  'isareply' => 
  array (
    'external' => 'dontsignhtmlifheadersexist',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Dont Sign HTML If Headers Exist',
    'desc' => ' If any of these headers exist, then the message is actually a reply and
 so we may not want to sign it with an HTML signature. Plain text sig-
 natures will still apply, but HTML signatures, which may include an image,
 will not.
 By default, this feature is disabled by specifying no header names.
 This should be a space or comma-separated list of header names.
 This can also be the filename of a ruleset.',
    'value' => ' # In-Reply-To: References:',
  ),
  'envfromheader' => 
  array (
    'external' => 'envelopefromheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner-Envelope-From:',
    'name' => 'Envelope From Header',
    'desc' => ' This is the name of the Envelope From header
 controlled by the option above.
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner-From:',
  ),
  'envtoheader' => 
  array (
    'external' => 'envelopetoheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner-Envelope-To:',
    'name' => 'Envelope To Header',
    'desc' => ' This is the name of the Envelope To header
 controlled by the option above.
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner-To:',
  ),
  'filecommand' => 
  array (
    'external' => 'filecommand',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/usr/bin/file',
    'name' => 'File Command',
    'desc' => ' Where the "file" command is installed.
 This is used for checking the content type of files, regardless of their
 filename.
 To disable Filetype checking, set this value to blank.',
    'value' => ' /usr/bin/file',
  ),
  'filenamerules' => 
  array (
    'external' => 'filenamerules',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Filename Rules',
    'desc' => ' 
 Set where to find the attachment filename ruleset.
 The structure of this file is explained elsewhere, but it is used to
 accept or reject file attachments based on their name, regardless of
 whether they are infected or not.

 This can also point to a ruleset, but the ruleset filename must end in
 ".rules" so that MailScanner can determine if the filename given is
 a ruleset or not!',
    'value' => ' %etc-dir%/filename.rules.conf',
  ),
  'namesubjecttext' => 
  array (
    'external' => 'filenamesubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Filename?}',
    'name' => 'Filename Subject Text',
    'desc' => ' This is the text to add to the start of the subject if the
 "Filename Modify Subject" option is set.
 You might want to change this so your users can see at a glance
 whether it just was just the filename that MailScanner rejected.
 This can also be the filename of a ruleset.',
    'value' => ' {Filename?}',
  ),
  'filetimeout' => 
  array (
    'external' => 'filetimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '20',
    'name' => 'File Timeout',
    'desc' => ' The maximum length of time the "file" command is allowed to run for 1
 batch of messages (in seconds).',
    'value' => ' 20',
  ),
  'filetyperules' => 
  array (
    'external' => 'filetyperules',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Filetype Rules',
    'desc' => ' Set where to find the attachment filetype ruleset.
 The structure of this file is explained elsewhere, but it is used to
 accept or reject file attachments based on their content as determined
 by the "file" command, regardless of whether they are infected or not.

 This can also point to a ruleset, but the ruleset filename must end in
 ".rules" so that MailScanner can determine if the filename given is
 a ruleset or not!

 To disable this feature, set this to just "Filetype Rules =" or set
 the location of the file command to a blank string.',
    'value' => ' %etc-dir%/filetype.rules.conf',
  ),
  'firstcheck' => 
  array (
    'external' => 'firstcheck',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => 'mcp',
    'name' => 'First Check',
    'desc' => ' Do the spam checks first, or the MCP checks first?
 This cannot be the filename of a ruleset, only a fixed value.',
    'value' => ' spam',
  ),
  'fprotd6port' => 
  array (
    'external' => 'fpscandport',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '10200',
    'name' => 'Fpscand Port',
    'desc' => '
 Options specific to F-Protd-6 Anti-Virus
 ----------------------------------------

 This is the port number used by the local fpscand daemon. 10200 is the
 default value used by the F-Prot 6 installation program, and so should
 be correct.
 This option cannot be the filename of a ruleset, it must be a number.',
    'value' => ' 10200',
  ),
  'gunzipcommand' => 
  array (
    'external' => 'gunzipcommand',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/bin/gunzip',
    'name' => 'Gunzip Command',
    'desc' => ' Where the "gunzip" command is installed.
 This is used for expanding .gz files.
 To disable gzipped file checking, set this value to blank
 and the timeout to 0.',
    'value' => ' /bin/gunzip',
  ),
  'gunziptimeout' => 
  array (
    'external' => 'gunziptimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '50',
    'name' => 'Gunzip Timeout',
    'desc' => ' The maximum length of time the "gunzip" command is allowed to run to expand
 1 attachment file (in seconds).',
    'value' => ' 50',
  ),
  'highscoremcpactions' => 
  array (
    'external' => 'highscoringmcpactions',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'deliver',
    'name' => 'High Scoring MCP Actions',
    'desc' => '',
    'value' => ' deliver',
  ),
  'highmcpsubjecttext' => 
  array (
    'external' => 'highscoringmcpsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{MCP?}',
    'name' => 'High Scoring MCP Subject Text',
    'desc' => '',
    'value' => ' {MCP?}',
  ),
  'highscorespamactions' => 
  array (
    'external' => 'highscoringspamactions',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'deliver header "X-Spam-Status: Yes"',
    'name' => 'High Scoring Spam Actions',
    'desc' => ' This is just like the "Spam Actions" option above, except that it applies
 when the score from SpamAssassin is higher than the "High SpamAssassin Score"
 value.
    deliver                 - deliver the message as normal
    delete                  - delete the message
    store                   - store the message in the (spam) quarantine
    store-nonmcp            - store the message in the non-MCP quarantine
    store-mcp               - store the message in the MCP quarantine
    store-nonspam           - store the message in the non-spam quarantine
    store-spam              - store the message in the spam quarantine
    store-<directory-path>  - store the message in the <directory-path>
    forward user@domain.com - forward a copy of the message to user@domain.com
                              See the note below about the keywords that
                              can be used.
    striphtml               - convert all in-line HTML content to plain text.
                              You need to specify "deliver" as well for the
                              message to reach the original recipient.
    attachment              - Convert the original message into an attachment
                              of the message. This means the user has to take
                              an extra step to open the spam, and stops "web
                              bugs" very effectively.
    notify                  - Send the recipients a short notification that
                              spam addressed to them was not delivered. They
                              can then take action to request retrieval of
                              the original message if they think it was not
                              spam.
    header "name: value"    - Add the header
                                name: value
                              to the message. name must not contain any spaces.
                              The "value" may contain the magic keyword "_TO_"
                              anywhere in it. _TO_ will be replaced by a
                              comma-separated list of the original recipients
                              of the message. This is very useful if you just
                              forward the message to a new address and don\'t
                              use the "deliver" action, as otherwise the list
                              of the original recipients may be lost.
    custom(parameter)       - Call the CustomAction function in /usr/lib/Mail-
                              Scanner/MailScanner/CustomFunctions/CustomAction
                              .pm with the \'parameter\' passed in. This can be
                              used to implement any custom action you require.

 "forward" keywords
 ==================
 In an email address specified in the "forward" action, several keywords can
 be used which will be substituted with various properties of the message:
 _FROMUSER_   The left-hand side of the address of the sender.
 _FROMDOMAIN_ The right-hand side of the address of the sender.
 _TOUSER_     The left-hand side of each of the recipients in turn.
 _TODOMAIN_   The right-hand side of each of the recipients in turn.
 _DATE_       The date the message was received by MailScanner.
 _HOUR_       The hour the message was received by MailScanner.
 This means that you can forward messages to email addresses which show the
 original recipients of the message, which could be very useful when
 delivering into spam archive management systems.

 The default value I have set here enables Thunderbird to automatically
 handle spam when set to trust the "SpamAssassin" headers.

 This can also be the filename of a ruleset, in which case the filename
 must end in ".rule" or ".rules".',
    'value' => ' store',
  ),
  'highspamsubjecttext' => 
  array (
    'external' => 'highscoringspamsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Spam?}',
    'name' => 'High Scoring Spam Subject Text',
    'desc' => ' This is just like the "Spam Subject Text" option above, except that
 it applies when the score from SpamAssassin is higher than the
 "High SpamAssassin Score" value.
 The exact string "_SCORE_" will be replaced by the numeric
 SpamAssassin score.
 The exact string "_STARS_" will be replaced by a row of stars
 whose length is the SpamAssassin score.
 This can also be the filename of a ruleset.',
    'value' => ' {Spam?}',
  ),
  'highspamassassinscore' => 
  array (
    'external' => 'highspamassassinscore',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '10',
    'name' => 'High SpamAssassin Score',
    'desc' => ' If a message achieves a SpamAssassin score higher than this value,
 then the "High Scoring Spam Actions" are used. You may want to use
 this to deliver moderate scores, while deleting very high scoring messsages.
 This can also be the filename of a ruleset.',
    'value' => ' 10',
  ),
  'hostname' => 
  array (
    'external' => 'hostname',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'the MailScanner',
    'name' => 'Hostname',
    'desc' => ' Name of this host, or a name like "the MailScanner" if you want to hide
 the real hostname. It is used in the Help Desk note contained in the
 virus warnings sent to users.
 Remember you can use $HOSTNAME in here, so you might want to set it to
 Hostname = the %org-name% ($HOSTNAME) MailScanner
 This can also be the filename of a ruleset.',
    'value' => ' the %org-name% ($HOSTNAME) MailScanner',
  ),
  'idheader' => 
  array (
    'external' => 'idheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner-ID:',
    'name' => 'ID Header',
    'desc' => ' Setting this adds the MailScanner message id number to a header
 in the message. If you do not want this header, just set this to be
 an empty string (put nothing after the \'=\').
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner-ID:',
  ),
  'webbugwhitelist' => 
  array (
    'external' => 'ignoredwebbugfilenames',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Ignored Web Bug Filenames',
    'desc' => ' This is a list of filenames (or parts of filenames) that may appear in
 the filename of a web bug URL. They are only checked in the filename,
 not any directories or hostnames in the URL of the possible web bug.

 If it appears, then the web bug is assumed to be a harmless "spacer" for
 page layout purposes and not a real web bug at all.
 It should be a space- and/or comma-separated list of filename parts.

 Note: Use this with care, as spammers may use this to circumvent the
       web bug trap. It is disabled by default because of this problem.

 This can also be the filename of a ruleset.
Ignored Web Bug Filenames = spacer pixel.gif pixel.png',
    'value' => ' spacer pixel.gif pixel.png gap shim',
  ),
  'whitelistmaxrecips' => 
  array (
    'external' => 'ignorespamwhitelistifrecipientsexceed',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '20',
    'name' => 'Ignore Spam Whitelist If Recipients Exceed',
    'desc' => ' Spammers have learnt that they can get their message through by sending
 a message with lots of recipients, one of which chooses to whitelist
 everything coming to them, including the spammer.
 So if a message arrives with more than this number of recipients, ignore
 the "Is Definitely Not Spam" whitelist.',
    'value' => ' 20',
  ),
  'inqueuedir' => 
  array (
    'external' => 'incomingqueuedir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/var/spool/mqueue.in',
    'name' => 'Incoming Queue Dir',
    'desc' => ' Set location of incoming mail queue

 This can be any one of
 1. A directory name
    Example: /var/spool/mqueue.in
 2. A wildcard giving directory names
    Example: /var/spool/mqueue.in/*
 3. The name of a file containing a list of directory names,
    which can in turn contain wildcards.
    Example: /etc/MailScanner/mqueue.in.list.conf

 If you are using sendmail and have your queues split into qf, df, xf
 directories, then just specify the main directory, do not give me the
 directory names of the qf,df,xf directories.
 Example: if you have /var/spool/mqueue.in/qf
                      /var/spool/mqueue.in/df
                      /var/spool/mqueue.in/xf
 then just tell me /var/spool/mqueue.in. I will find the subdirectories
 automatically.
',
    'value' => ' /var/spool/mqueue.in',
  ),
  'incomingworkdir' => 
  array (
    'external' => 'incomingworkdir',
    'type' => 'dir',
    'ruleset' => 'no',
    'default' => '/var/spool/MailScanner/incoming',
    'name' => 'Incoming Work Dir',
    'desc' => ' Set where to unpack incoming messages before scanning them
 This can completely safely use tmpfs or a ramdisk, which will
 give you a significant performance improvement.
 NOTE: The path given here must not include any links at all,
 NOTE: but must be the absolute path to the directory.
 NOTE: If you change this, you should change these too:
 NOTE:        SpamAssassin Temporary Dir
 NOTE:        SpamAssassin Cache Database File',
    'value' => ' /var/spool/MailScanner/incoming',
  ),
  'workgroup' => 
  array (
    'external' => 'incomingworkgroup',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Incoming Work Group',
    'desc' => 'The group under which processing shuld be run during scanning and 
    evaluation. Systems users such as mail, clamav, sophosav, postfix, exim should be added 
    to this group. This combined with Incoming Work Permissions of 0660 will avoid
    permissions problems such as the dreaded ClamAV ./lstat() error. You may use any group
    you like. The group mtagroup is used to add relevant found system users during the
    installation process.',
    'value' => 'mtagroup',
  ),
  'workperms' => 
  array (
    'external' => 'incomingworkpermissions',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '0660',
    'name' => 'Incoming Work Permissions',
    'desc' => ' If you want processes running under the same *group* as MailScanner to
 be able to read the working files (and list what is in the
 directories, of course), set to 0640. If you want *all* other users to
 be able to read them, set to 0644. For a detailed description, if
 you\'re not already familiar with it, refer to `man 2 chmod`.
 Typical use: external helper programs of virus scanners (notably ClamAV),
 like unpackers.
 Use with care, you may well open security holes.

 Note: If the "Run As User" is "root" (or not set at all) and you are
       using the "clamd" virus scanner, you should add the clamd user
       to the mtagroup group and set this as below. Also make sure to 
       add other relevant users to the mtagroup. 
       Incoming Work Group = mtagroup
       Incoming Work Permissions = 0660',
    'value' => ' 0660',
  ),
  'workuser' => 
  array (
    'external' => 'incomingworkuser',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Incoming Work User',
    'desc' => ' If you want to create the temporary working files so they are owned
 by a user other than the "Run As User" setting at the top of this file,
 you can change that here.

 Note: If the "Run As User" is not "root" you cannot change the
       user but may still be able to change the group, if the
       "Run As User" is a member of both of the groups "Run As Group"
       and "Incoming Work Group"
 Note: If the "Run As User" is "root" (or not set at all) and you are
       using the "clamd" virus scanner AND clamd is not running as root,
       then this must be set to the group clamd is using (from your
       clamd.conf), example:
       Incoming Work Group = clamav
       Incoming Work Permissions = 0640',
    'value' => '',
  ),
  'dirtyheader' => 
  array (
    'external' => 'infectedheadervalue',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'Found to be infected',
    'name' => 'Infected Header Value',
    'desc' => '',
    'value' => ' Found to be infected',
  ),
  'infoheader' => 
  array (
    'external' => 'informationheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '',
    'name' => 'Information Header',
    'desc' => ' Add this extra header to all mail as it is processed.
 The contents is set by "Information Header Value" and is intended for
 you to be able to insert a help URL for your users.
 If you don\'t want an information header at all, just comment out this
 setting or set it to be blank.
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner-Information:',
  ),
  'infovalue' => 
  array (
    'external' => 'informationheadervalue',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'Please contact an administrator for more information',
    'name' => 'Information Header Value',
    'desc' => ' Set the "Information Header" to this value.
 This can also be the filename of a ruleset.',
    'value' => ' Please contact an administrator for more information',
  ),
  'inlinehtmlsig' => 
  array (
    'external' => 'inlinehtmlsignature',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/inline.sig.html',
    'name' => 'Inline HTML Signature',
    'desc' => ' Set where to find the HTML and text versions that will be added to the
 end of all clean messages, if "Sign Clean Messages" is set.
 These can also be the filenames of rulesets.',
    'value' => ' %report-dir%/inline.sig.html',
  ),
  'inlinehtmlwarning' => 
  array (
    'external' => 'inlinehtmlwarning',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/inline.warning.html',
    'name' => 'Inline HTML Warning',
    'desc' => ' Set where to find the HTML and text versions that will be inserted at
 the top of messages that have had viruses removed from them.
 These can also be the filenames of rulesets.',
    'value' => ' %report-dir%/inline.warning.html',
  ),
  'inlinespamwarning' => 
  array (
    'external' => 'inlinespamwarning',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/inline.spam.warning.txt',
    'name' => 'Inline Spam Warning',
    'desc' => ' If you use the \'attachment\' Spam Action or High Scoring Spam Action
 then this is the location of inline spam report that is inserted at
 the top of the message.',
    'value' => ' %report-dir%/inline.spam.warning.txt',
  ),
  'inlinetextsig' => 
  array (
    'external' => 'inlinetextsignature',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/inline.sig.txt',
    'name' => 'Inline Text Signature',
    'desc' => '',
    'value' => ' %report-dir%/inline.sig.txt',
  ),
  'inlinetextwarning' => 
  array (
    'external' => 'inlinetextwarning',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/inline.warning.txt',
    'name' => 'Inline Text Warning',
    'desc' => '',
    'value' => ' %report-dir%/inline.warning.txt',
  ),
  'ipverheader' => 
  array (
    'external' => 'ipprotocolversionheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '',
    'name' => 'IP Protocol Version Header',
    'desc' => ' Was this message transmitted using IPv6 or IPv4 in its last hop?
 To stop this header appearing, set it to be blank.
 This can also be the filename of a ruleset.',
    'value' => ' # X-%org-name%-MailScanner-IP-Protocol:',
  ),
  'webbugblacklist' => 
  array (
    'external' => 'knownwebbugservers',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Known Web Bug Servers',
    'desc' => ' This is a list of server names (or parts of) which are known to host web
 bugs. All images from these hosts will be replaced by the "Web Bug
 Replacement" defined below.
 This can also be the filename of a ruleset.',
    'value' => ' msgtag.com',
  ),
  'languagestrings' => 
  array (
    'external' => 'languagestrings',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '',
    'name' => 'Language Strings',
    'desc' => ' Set where to find all the strings used so they can be translated into
 your local language.
 This can also be the filename of a ruleset so you can produce different
 languages for different messages.',
    'value' => ' %report-dir%/languages.conf',
  ),
  'localpostmaster' => 
  array (
    'external' => 'localpostmaster',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'postmaster',
    'name' => 'Local Postmaster',
    'desc' => ' Address of the local Postmaster, which is used as the "From" address in
 virus warnings sent to users.
 This can also be the filename of a ruleset.',
    'value' => ' postmaster',
  ),
  'lockfiledir' => 
  array (
    'external' => 'lockfiledir',
    'type' => 'dir',
    'ruleset' => 'no',
    'default' => '/var/spool/MailScanner/incoming/Locks',
    'name' => 'Lockfile Dir',
    'desc' => ' Where to put the virus scanning engine lock files.
 These lock files are used between MailScanner and the virus signature
 "autoupdate" scripts, to ensure that they aren\'t both working at the
 same time (which could cause MailScanner to let a virus through).',
    'value' => ' /var/spool/MailScanner/incoming/Locks',
  ),
  'locktype' => 
  array (
    'external' => 'locktype',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Lock Type',
    'desc' => ' How to lock spool files.
 Don\'t set this unless you *know* you need to.
 For sendmail, it defaults to "posix".
 For sendmail 8.12 and older, you will probably need to change it to flock,
 particularly on Linux systems.
 For Exim, it defaults to "posix".
 No other type is implemented.',
    'value' => '',
  ),
  'mailheader' => 
  array (
    'external' => 'mailheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner:',
    'name' => 'Mail Header',
    'desc' => ' Add this extra header to all mail as it is processed.
 This *must* include the colon ":" at the end.
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner:',
  ),
  'mailscannerversionnumber' => 
  array (
    'external' => 'mailscannerversionnumber',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '1.0.0',
    'name' => 'MailScanner Version Number',
    'desc' => ' This is the version number of the MailScanner distribution that created
 this configuration file. Please do not change this value.',
    'value' => ' VersionNumberHere',
  ),
  'children' => 
  array (
    'external' => 'maxchildren',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '5',
    'name' => 'Max Children',
    'desc' => ' How many MailScanner processes do you want to run at a time?
 There is no point increasing this figure if your MailScanner server
 is happily keeping up with your mail traffic.
 If you are running on a server with more than 1 CPU, or you have a
 high mail load (and/or slow DNS lookups) then you should see better
 performance if you increase this figure.
 If you are running on a small system with limited RAM, you should
 note that each child takes just over 20MB.

 As a rough guide, try 5 children per CPU. But read the notes above.',
    'value' => ' 5',
  ),
  'maxgssize' => 
  array (
    'external' => 'maxcustomspamscannersize',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '20000',
    'name' => 'Max Custom Spam Scanner Size',
    'desc' => ' How much of the message should be passed tot he Custom Spam Scanner.
 Most spam tools only need the first 20kbytes of the message to determine
 if it is spam or not. Passing more than is necessary only slows things
 down.
 This can also be the filename of a ruleset.',
    'value' => ' 20k',
  ),
  'maxgstimeouts' => 
  array (
    'external' => 'maxcustomspamscannertimeouts',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '10',
    'name' => 'Max Custom Spam Scanner Timeouts',
    'desc' => ' If the Custom Spam Scanner times out more times in a row than this,
 then it will be marked as "unavailable" until MailScanner next re-
 starts itself.',
    'value' => ' 10',
  ),
  'maxzipdepth' => 
  array (
    'external' => 'maximumarchivedepth',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '2',
    'name' => 'Maximum Archive Depth',
    'desc' => ' The maximum depth to which zip archives, rar archives and Microsoft Office
 documents will be unpacked, to allow for checking filenames and filetypes
 within zip and rar archives and embedded within Office documents.

 Note: This setting does *not* affect virus scanning in archives at all.

 To disable this feature set this to 0.
 A common useful setting is this option = 0, and Allow Password-Protected
 Archives = no. That block password-protected archives but does not do
 any filename/filetype checks on the files within the archive.
 This can also be the filename of a ruleset.',
    'value' => ' 8',
  ),
  'maxattachmentsize' => 
  array (
    'external' => 'maximumattachmentsize',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '-1',
    'name' => 'Maximum Attachment Size',
    'desc' => ' The maximum size, in bytes, of any attachment in a message.
 If this is set to zero, effectively no attachments are allowed.
 If this is set less than zero, then no size checking is done.
 This can also be the filename of a ruleset, so you can have different
 settings for different users. You might want to set this quite small for
 large mailing lists so they don\'t get deluged by large attachments.
 This can also be the filename of a ruleset.',
    'value' => ' -1',
  ),
  'maxparts' => 
  array (
    'external' => 'maximumattachmentspermessage',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '200',
    'name' => 'Maximum Attachments Per Message',
    'desc' => ' The maximum number of attachments allowed in a message before it is
 considered to be an error. Some email systems, if bouncing a message
 between 2 addresses repeatedly, add information about each bounce as
 an attachment, creating a message with thousands of attachments in just
 a few minutes. This can slow down or even stop MailScanner as it uses
 all available memory to unpack these thousands of attachments.
 This can also be the filename of a ruleset.',
    'value' => ' 200',
  ),
  'maxmessagesize' => 
  array (
    'external' => 'maximummessagesize',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '0',
    'name' => 'Maximum Message Size',
    'desc' => ' The maximum size, in bytes, of any message including the headers.
 If this is set to zero, then no size checking is done.
 This can also be the filename of a ruleset, so you can have different
 settings for different users. You might want to set this quite small for
 dialup users so their email applications don\'t time out downloading huge
 messages.',
    'value' => ' %rules-dir%/max.message.size.rules',
  ),
  'procdbattempts' => 
  array (
    'external' => 'maximumprocessingattempts',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '6',
    'name' => 'Maximum Processing Attempts',
    'desc' => ' Limit the number of attempts made at processing any particular message.
 If you get a message which repeatedly crashes MailScanner, it will
 limit the imapact by ignoring the message and refusing to process it,
 after more than the given number of attempts have been made at it.
 Note that enabling this feature causes a slight performance hit.
 Set this to 0 to disable the limit and the entire Processing Attempts
 Database and its requirement for SQLite.
 This cannot be a ruleset, only a simple value.',
    'value' => ' 6',
  ),
  'criticalqueuesize' => 
  array (
    'external' => 'maxnormalqueuesize',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '800',
    'name' => 'Max Normal Queue Size',
    'desc' => ' If more messages are found in the queue than this, then switch to an
 "accelerated" mode of processing messages. This will cause it to stop
 scanning messages in strict date order, but in the order it finds them
 in the queue. If your queue is bigger than this size a lot of the time,
 then some messages could be greatly delayed. So treat this option as
 "in emergency only".',
    'value' => ' 800',
  ),
  'maxspamassassinsize' => 
  array (
    'external' => 'maxspamassassinsize',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '30000',
    'name' => 'Max SpamAssassin Size',
    'desc' => ' SpamAssassin is not very fast when scanning huge messages, so messages
 bigger than this value will be truncated to this length for SpamAssassin
 testing. The original message will not be affected by this. This value
 is a good compromise as very few spam messages are bigger than this.

 Now for the options:
 1) <length of data in bytes>
 2) <length of data in bytes> trackback
 3) <length of data in bytes> continue <max extra bytes allowed>

 1) Put in a simple number.
    This will be the simple cut-off point for messages that are larger than
    this number.
 2) Put in a number followed by \'trackback\'.
    Once the size limit is reached, MailScanner reverses towards the start
    of the message, until it hits a line that is blank. The message passed
    to SpamAssassin is truncated there. This stops any part-images being
    passed to SpamAssassin, and so avoids rules which trigger on this.
 3) Put in a number followed by \'continue\' followed by another number.
    Once the size limit is reached, MailScanner continues adding to the data
    passed to SpamAssassin, until at most the 2nd number of bytes have been
    added looking for a blank line. This tries to complete the image data
    that has been started when the 1st number of bytes has been reached,
    while imposing a limit on the amount that can be added (to avoid attacks).

 If all this confuses you, just leave it alone at "40k" as that is good.',
    'value' => ' 200k',
  ),
  'maxspamassassintimeouts' => 
  array (
    'external' => 'maxspamassassintimeouts',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '10',
    'name' => 'Max SpamAssassin Timeouts',
    'desc' => ' If SpamAssassin times out more times in a row than this, then it will be
 marked as "unavailable" until MailScanner next re-starts itself.
 This means that remote network failures causing SpamAssassin trouble will
 not mean your mail stops flowing.',
    'value' => ' 10',
  ),
  'maxspamchecksize' => 
  array (
    'external' => 'maxspamchecksize',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '150000',
    'name' => 'Max Spam Check Size',
    'desc' => ' Spammers do not have the power to send out huge messages to everyone as
 it costs them too much (more smaller messages makes more profit than less
 very large messages). So if a message is bigger than a certain size, it
 is highly unlikely to be spam. Limiting this saves a lot of time checking
 huge messages.
 Disable this option by setting it to a huge value.
 This is measured in bytes.
 This can also be the filename of a ruleset.',
    'value' => ' 200k',
  ),
  'maxspamlisttimeouts' => 
  array (
    'external' => 'maxspamlisttimeouts',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '7',
    'name' => 'Max Spam List Timeouts',
    'desc' => ' The maximum number of timeouts caused by any individual "Spam List" or
 "Spam Domain List" before it is marked as "unavailable". Once marked,
 the list will be ignored until the next automatic re-start (see
 "Restart Every" for the longest time it will wait).
 This can also be the filename of a ruleset.',
    'value' => ' 7',
  ),
  'maxdirtybytes' => 
  array (
    'external' => 'maxunsafebytesperscan',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '50000000',
    'name' => 'Max Unsafe Bytes Per Scan',
    'desc' => '',
    'value' => ' 50m',
  ),
  'maxdirtymessages' => 
  array (
    'external' => 'maxunsafemessagesperscan',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '30',
    'name' => 'Max Unsafe Messages Per Scan',
    'desc' => '',
    'value' => ' 30',
  ),
  'maxunscannedbytes' => 
  array (
    'external' => 'maxunscannedbytesperscan',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '100000000',
    'name' => 'Max Unscanned Bytes Per Scan',
    'desc' => '',
    'value' => ' 100m',
  ),
  'maxunscannedmessages' => 
  array (
    'external' => 'maxunscannedmessagesperscan',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '30',
    'name' => 'Max Unscanned Messages Per Scan',
    'desc' => '',
    'value' => ' 30',
  ),
  'mcpactions' => 
  array (
    'external' => 'mcpactions',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'deliver',
    'name' => 'MCP Actions',
    'desc' => '',
    'value' => ' deliver',
  ),
  'mcperrorscore' => 
  array (
    'external' => 'mcperrorscore',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '1',
    'name' => 'MCP Error Score',
    'desc' => '',
    'value' => ' 1',
  ),
  'mcpheader' => 
  array (
    'external' => 'mcpheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner-MCPCheck:',
    'name' => 'MCP Header',
    'desc' => '',
    'value' => ' X-%org-name%-MailScanner-MCPCheck:',
  ),
  'mcphighspamassassinscore' => 
  array (
    'external' => 'mcphighspamassassinscore',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '10',
    'name' => 'MCP High SpamAssassin Score',
    'desc' => '',
    'value' => ' 10',
  ),
  'mcpmaxspamassassinsize' => 
  array (
    'external' => 'mcpmaxspamassassinsize',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '100000',
    'name' => 'MCP Max SpamAssassin Size',
    'desc' => '',
    'value' => ' 100k',
  ),
  'mcpmaxspamassassintimeouts' => 
  array (
    'external' => 'mcpmaxspamassassintimeouts',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '20',
    'name' => 'MCP Max SpamAssassin Timeouts',
    'desc' => '',
    'value' => ' 20',
  ),
  'mcpreqspamassassinscore' => 
  array (
    'external' => 'mcprequiredspamassassinscore',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '1',
    'name' => 'MCP Required SpamAssassin Score',
    'desc' => ' The rest of these options are clones of the equivalent spam options',
    'value' => ' 1',
  ),
  'mcpspamassassindefaultrulesdir' => 
  array (
    'external' => 'mcpspamassassindefaultrulesdir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/mcp',
    'name' => 'MCP SpamAssassin Default Rules Dir',
    'desc' => '',
    'value' => ' %mcp-dir%',
  ),
  'mcpspamassassininstallprefix' => 
  array (
    'external' => 'mcpspamassassininstallprefix',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/mcp',
    'name' => 'MCP SpamAssassin Install Prefix',
    'desc' => '',
    'value' => ' %mcp-dir%',
  ),
  'mcpspamassassinlocalrulesdir' => 
  array (
    'external' => 'mcpspamassassinlocalrulesdir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/mcp',
    'name' => 'MCP SpamAssassin Local Rules Dir',
    'desc' => '',
    'value' => ' %mcp-dir%',
  ),
  'mcpspamassassinprefsfile' => 
  array (
    'external' => 'mcpspamassassinprefsfile',
    'type' => 'file',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/mcp/mcp.spam.assassin.prefs.conf',
    'name' => 'MCP SpamAssassin Prefs File',
    'desc' => '',
    'value' => ' %mcp-dir%/mcp.spam.assassin.prefs.conf',
  ),
  'mcpspamassassintimeout' => 
  array (
    'external' => 'mcpspamassassintimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '10',
    'name' => 'MCP SpamAssassin Timeout',
    'desc' => '',
    'value' => ' 10',
  ),
  'mcpspamassassinuserstatedir' => 
  array (
    'external' => 'mcpspamassassinuserstatedir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'MCP SpamAssassin User State Dir',
    'desc' => '',
    'value' => '',
  ),
  'mcpsubjecttext' => 
  array (
    'external' => 'mcpsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{MCP?}',
    'name' => 'MCP Subject Text',
    'desc' => '',
    'value' => ' {MCP?}',
  ),
  'minattachmentsize' => 
  array (
    'external' => 'minimumattachmentsize',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '-1',
    'name' => 'Minimum Attachment Size',
    'desc' => ' The minimum size, in bytes, of any attachment in a message.
 If this is set less than or equal to zero, then no size checking is done.
 It is very useful to set this to 1 as it removes any zero-length
 attachments which may be created by broken viruses.
 This can also be the filename of a ruleset.',
    'value' => ' -1',
  ),
  'minimumcodestatus' => 
  array (
    'external' => 'minimumcodestatus',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => 'supported',
    'name' => 'Minimum Code Status',
    'desc' => ' Minimum acceptable code stability status -- if we come across code
 that\'s not at least as stable as this, we barf.
 This is currently only used to check that you don\'t end up using untested
 virus scanner support code without realising it.
 Levels used are:
 none          - there may not even be any code.
 unsupported   - code may be completely untested, a contributed dirty hack,
                 anything, really.
 alpha         - code is pretty well untested. Don\'t assume it will work.
 beta          - code is tested a bit. It should work.
 supported     - code *should* be reliable.

 Don\'t even *think* about setting this to anything other than "beta" or
 "supported" on a system that receives real mail until you have tested it
 yourself and are happy that it is all working as you expect it to.
 Don\'t set it to anything other than "supported" on a system that could
 ever receive important mail.

 READ and UNDERSTAND the above text BEFORE changing this.
',
    'value' => ' supported',
  ),
  'minstars' => 
  array (
    'external' => 'minimumstarsifonspamlist',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '0',
    'name' => 'Minimum Stars If On Spam List',
    'desc' => ' This sets the minimum number of "Spam Score Characters" which will appear
 if a message triggered the "Spam List" setting but received a very low
 SpamAssassin score. This means that people who only filter on the "Spam
 Stars" will still be able to catch messages which receive a very low
 SpamAssassin score. Set this value to 0 to disable it.
 This can also be the filename of a ruleset.',
    'value' => ' 0',
  ),
  'clamwatchfiles' => 
  array (
    'external' => 'monitorsforclamavupdates',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/usr/local/share/clamav/*.cvd',
    'name' => 'Monitors for ClamAV Updates',
    'desc' => ' ClamAVModule only: monitor each of these files for changes in size to
 detect when a ClamAV update has happened.
 This is only used by the "clamavmodule" virus scanner, not the "clamav"
 scanner setting.',
    'value' => ' /usr/local/share/clamav/*.cld /usr/local/share/clamav/*.cvd',
  ),
  'saviwatchfiles' => 
  array (
    'external' => 'monitorsforsophosupdates',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/opt/sophos-av/lib/sav/*.ide',
    'name' => 'Monitors For Sophos Updates',
    'desc' => ' SophosSAVI only: monitor each of these files for changes in size to
 detect when a Sophos update has happened. The date of the Sophos Lib Dir
 is also monitored.
 This is only used by the "sophossavi" virus scanner, not the "sophos"
 scanner setting.',
    'value' => ' /opt/sophos-av/lib/sav/*.ide',
  ),
  'mta' => 
  array (
    'external' => 'mta',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => 'sendmail',
    'name' => 'MTA',
    'desc' => ' Set whether to use postfix, sendmail, exim or zmailer.
 If you are using postfix, then see the "SpamAssassin User State Dir"
 setting near the end of this file',
    'value' => ' sendmail',
  ),
  'nosenderprecedence' => 
  array (
    'external' => 'nevernotifysendersofprecedence',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => 'list bulk',
    'name' => 'Never Notify Senders Of Precedence',
    'desc' => ' If you supply a space-separated list of message "precedence" settings,
 then senders of those messages will not be warned about anything you
 rejected. This is particularly suitable for mailing lists, so that any
 MailScanner responses do not get sent to the entire list.',
    'value' => ' list bulk',
  ),
  'noisyviruses' => 
  array (
    'external' => 'nonforgingviruses',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => 'Joke/ OF97/ WM97/ W97M/ eicar',
    'name' => 'Non-Forging Viruses',
    'desc' => ' Strings listed here will be searched for in the output of the virus scanners.
 It works to achieve the opposite effect of the "Silent Viruses" listed above.
 If a string here is found in the output of the virus scanners, then the
 message will be treated as if it were not infected with a "Silent Virus".
 If a message is detected as both a silent virus and a non-forging virus,
 then the ___non-forging status will override the silent status.___
 In simple terms, you should list virus names (or parts of them) that you
 know do *not* forge the From address.
 A good example of this is a document macro virus or a Joke program.
 Another word that can be put in this list is the special keyword
    Zip-Password  : inserting this will cause senders to be warned about
                    password-protected zip files, when they are not allowed.
                    This will over-ride the All-Viruses setting in the list
                    of "Silent Viruses" above.
',
    'value' => ' Joke/ OF97/ WM97/ W97M/ eicar',
  ),
  'nonmcpactions' => 
  array (
    'external' => 'nonmcpactions',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'deliver',
    'name' => 'Non MCP Actions',
    'desc' => '',
    'value' => ' deliver',
  ),
  'hamactions' => 
  array (
    'external' => 'nonspamactions',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'deliver header "X-Spam-Status: No"',
    'name' => 'Non Spam Actions',
    'desc' => ' This is just like the "Spam Actions" option above, except that it applies
 to messages that are *NOT* spam.
    deliver                 - deliver the message as normal
    delete                  - delete the message
    store                   - store the message in the (non-spam) quarantine
    store-nonmcp            - store the message in the non-MCP quarantine
    store-mcp               - store the message in the MCP quarantine
    store-nonspam           - store the message in the non-spam quarantine
    store-spam              - store the message in the spam quarantine
    store-<directory-path>  - store the message in the <directory-path>
    forward user@domain.com - forward a copy of the message to user@domain.com
                              See the note below about the keywords that
                              can be used.
    striphtml               - convert all in-line HTML content to plain text
    header "name: value"    - Add the header
                                name: value
                              to the message. name must not contain any spaces.
                              The "value" may contain the magic keyword "_TO_"
                              anywhere in it. _TO_ will be replaced by a
                              comma-separated list of the original recipients
                              of the message. This is very useful if you just
                              forward the message to a new address and don\'t
                              use the "deliver" action, as otherwise the list
                              of the original recipients may be lost.
    custom(parameter)       - Call the CustomAction function in /usr/lib/Mail-
                              Scanner/MailScanner/CustomFunctions/CustomAction
                              .pm with the \'parameter\' passed in. This can be
                              used to implement any custom action you require.

 "forward" keywords
 ==================
 In an email address specified in the "forward" action, several keywords can
 be used which will be substituted with various properties of the message:
 _FROMUSER_   The left-hand side of the address of the sender.
 _FROMDOMAIN_ The right-hand side of the address of the sender.
 _TOUSER_     The left-hand side of each of the recipients in turn.
 _TODOMAIN_   The right-hand side of each of the recipients in turn.
 _DATE_       The date the message was received by MailScanner.
 _HOUR_       The hour the message was received by MailScanner.
 This means that you can forward messages to email addresses which show the
 original recipients of the message, which could be very useful when
 delivering into spam archive management systems.

 The default value I have set here enables Thunderbird to automatically
 handle spam when set to trust the "SpamAssassin" headers.

 This can also be the filename of a ruleset, in which case the filename
 must end in ".rule" or ".rules".',
    'value' => ' deliver header "X-Spam-Status: No"',
  ),
  'noticesfrom' => 
  array (
    'external' => 'noticesfrom',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'MailScanner',
    'name' => 'Notices From',
    'desc' => ' The visible part of the email address used in the "From:" line of the
 notices. The <user@domain> part of the email address is set to the
 "Local Postmaster" setting.',
    'value' => ' MailScanner',
  ),
  'noticesignature' => 
  array (
    'external' => 'noticesignature',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '-- \\nMailScanner\\nEmail Virus Scanner\\nwww.mailscanner.info',
    'name' => 'Notice Signature',
    'desc' => ' What signature to add to the bottom of the notices.
 To insert a line-break in there, use the sequence "\\n".',
    'value' => ' -- \\nMailScanner\\nEmail Virus Scanner\\nwww.mailscanner.info',
  ),
  'noticerecipient' => 
  array (
    'external' => 'noticesto',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => 'postmaster',
    'name' => 'Notices To',
    'desc' => ' Where to send the notices.
 This can also be the filename of a ruleset.',
    'value' => ' postmaster',
  ),
  'outqueuedir' => 
  array (
    'external' => 'outgoingqueuedir',
    'type' => 'dir',
    'ruleset' => 'first',
    'default' => '/var/spool/mqueue',
    'name' => 'Outgoing Queue Dir',
    'desc' => ' Set location of outgoing mail queue.
 This can also be the filename of a ruleset.',
    'value' => ' /var/spool/mqueue',
  ),
  'phishingblacklist' => 
  array (
    'external' => 'phishingbadsitesfile',
    'type' => 'file',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/phishing.bad.sites.conf',
    'name' => 'Phishing Bad Sites File',
    'desc' => ' As an opposite to the "safe" list above, there is also a live continuously-
 updated list of known bad sites, which will always trigger the "Find
 Phishing Fraud" test described above.
 This is a space-separated list of the names of files which contain
 a list of link destinations which should always trigger the test. This
 file should be updated hourly.
 This can only be the name of the file containing the list, it *cannot*
 be the filename of a ruleset.',
    'value' => ' %etc-dir%/phishing.bad.sites.conf',
  ),
  'phishingwhitelist' => 
  array (
    'external' => 'phishingsafesitesfile',
    'type' => 'file',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/phishing.safe.sites.conf',
    'name' => 'Phishing Safe Sites File',
    'desc' => ' There are some companies, such as banks, that insist on sending out
 email messages with links in them that are caught by the "Find Phishing
 Fraud" test described above.
 This is a space-separated list of the names of files which contain a
 list of link destinations which should be ignored in the test. This may,
 for example, contain the known websites of some banks.
 See the file itself for more information.
 This can only be the names of the files containing the list, it *cannot*
 be the filename of a ruleset.',
    'value' => ' %etc-dir%/phishing.safe.sites.conf',
  ),
  'phishingsubjecttag' => 
  array (
    'external' => 'phishingsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Fraud?}',
    'name' => 'Phishing Subject Text',
    'desc' => ' This is the text to add to the start of the subject if the "Phishing
 Modify Subhect" option is set.
 This can also be the filename of a ruleset.',
    'value' => ' {Fraud?}',
  ),
  'pidfile' => 
  array (
    'external' => 'pidfile',
    'type' => 'file',
    'ruleset' => 'no',
    'default' => '/var/run/MailScanner.pid',
    'name' => 'PID file',
    'desc' => ' Set where to store the process id number so you can stop MailScanner',
    'value' => ' /opt/MailScanner/var/MailScanner.pid',
  ),
  'procdbname' => 
  array (
    'external' => 'processingattemptsdatabase',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/var/spool/MailScanner/incoming/Processing.db',
    'name' => 'Processing Attempts Database',
    'desc' => ' This is the location of the database file used to track the number of
 times any message has been attempted.
 To clear out the database, just delete the file, MailScanner will re-
 create it automatically when it starts.',
    'value' => ' /var/spool/MailScanner/incoming/Processing.db',
  ),
  'quarantinedir' => 
  array (
    'external' => 'quarantinedir',
    'type' => 'dir',
    'ruleset' => 'first',
    'default' => '/var/spool/MailScanner/quarantine',
    'name' => 'Quarantine Dir',
    'desc' => ' Set where to store infected and message attachments (if they are kept)
 This can also be the filename of a ruleset.',
    'value' => ' /var/spool/MailScanner/quarantine',
  ),
  'quarantinegroup' => 
  array (
    'external' => 'quarantinegroup',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Quarantine Group',
    'desc' => '',
    'value' => '',
  ),
  'quarantineperms' => 
  array (
    'external' => 'quarantinepermissions',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '0600',
    'name' => 'Quarantine Permissions',
    'desc' => ' If you want processes running under the same *group* as MailScanner to
 be able to read the quarantined files (and list what is in the
 directories, of course), set to 0640. If you want *all* other users to
 be able to read them, set to 0644. For a detailed description, if
 you\'re not already familiar with it, refer to `man 2 chmod`.
 Typical use: let the webserver have access to the files so users can
 download them if they really want to.
 Use with care, you may well open security holes.',
    'value' => ' 0600',
  ),
  'quarantineuser' => 
  array (
    'external' => 'quarantineuser',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Quarantine User',
    'desc' => ' If you want to create the quarantine/archive so the files are owned
 by a user other than the "Run As User" setting at the top of this file,
 you can change that here.
 Note: If the "Run As User" is not "root" then you cannot change the
       user but may still be able to change the group, if the
       "Run As User" is a member of both of the groups "Run As Group"
       and "Quarantine Group".',
    'value' => '',
  ),
  'queuescaninterval' => 
  array (
    'external' => 'queuescaninterval',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '6',
    'name' => 'Queue Scan Interval',
    'desc' => ' How often (in seconds) should each process check the incoming mail
 queue for new messages? If you have a quiet mail server, you might
 want to increase this value so it causes less load on your server, at
 the cost of slightly increasing the time taken for an average message
 to be processed.',
    'value' => ' 6',
  ),
  'getipfromheader' => 
  array (
    'external' => 'readipaddressfromreceivedheader',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '0',
    'name' => 'Read IP Address From Received Header',
    'desc' => ' When working out from IP address the message was sent from,
 no or 0  ==> use the SMTP client address, ie. the address of the system
              talking to the MailScanner server. This is the normal setting.
 yes or 1 ==> use the first IP address contained in the first "Received:"
              header at the top of the email message\'s headers.
 Any number > 1 ==> use the first IP address contained in the n-th
                    "Received:" header starting from the top of the email
                    message\'s headers.
 Users of BarricadeMX should note that this setting will always be forced
 to 2, so it will always give you IP address of the system connecting to
 BarricadeMX.

 This is very useful when you are injecting mail into a MailScanner server
 using "fetchmail" as otherwise all mail will appear to be coming from the
 the IP address of the system running "fetchmail", and not the address the
 mail actually came from.
 You need to use this together with the "invisible" option in "fetchmail",
 so that "fetchmail" does not add its own "Received:" header to the start
 of the message.

 This value *cannot* be the filename of a ruleset.',
    'value' => ' no',
  ),
  'bayesrebuild' => 
  array (
    'external' => 'rebuildbayesevery',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '0',
    'name' => 'Rebuild Bayes Every',
    'desc' => ' If you are using the Bayesian statistics engine on a busy server,
 you may well need to force a Bayesian database rebuild and expiry
 at regular intervals. This is measures in seconds.
 1 day = 86400 seconds.
 To disable this feature set this to 0.
 Note: If you enable this feature, set "bayes_auto_expire 0" in
       spam.assasssin.prefs.conf which you will find in the same
       directory as this file.',
    'value' => ' 0',
  ),
  'recipientmcpreport' => 
  array (
    'external' => 'recipientmcpreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/recipient.mcp.report.txt',
    'name' => 'Recipient MCP Report',
    'desc' => '',
    'value' => ' %report-dir%/recipient.mcp.report.txt',
  ),
  'recipientspamreport' => 
  array (
    'external' => 'recipientspamreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/recipient.spam.report.txt',
    'name' => 'Recipient Spam Report',
    'desc' => ' If you use the \'notify\' Spam Action or High Scoring Spam Action then
 this is the location of the notification message that is sent to the
 original recipients of the message.',
    'value' => ' %report-dir%/recipient.spam.report.txt',
  ),
  'rejectionreport' => 
  array (
    'external' => 'rejectionreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/message.rejection.report.txt',
    'name' => 'Rejection Report',
    'desc' => ' Set where to find the message text sent to users who triggered the ruleset
 you are using with the "Reject Message" option.',
    'value' => ' %report-dir%/rejection.report.txt',
  ),
  'removeheaders' => 
  array (
    'external' => 'removetheseheaders',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => 'X-Mozilla-Status: X-Mozilla-Status2:',
    'name' => 'Remove These Headers',
    'desc' => ' If any of these headers are included in a a message, they will be deleted.
 This is a space-separated list of a mixture of any combination of
 1. Names of headers, optionally ending with a \':\'
    (the \':\' will be added if not supplied)
 2. Regular expressions starting and ending with a \'/\'.
    These regular expressions are matched against the entire header line,
    not just the name of the header.
    **NOTE** The regular expressions must *not* contain spaces,
             so use \'\\s\' instead of \' \'.
 This is very useful for removing return-receipt requests and any headers
 which mean special things to your email client application.
 X-Mozilla-Status is bad as it allows spammers to make a message appear to
 have already been read, which is believed to bypass some naive spam
 filtering systems.
 Receipt requests are bad as they give any attacker confirmation that an
 account is active and being read. You don\'t want this sort of information
 to leak outside your corporation. So you might want to remove
     Disposition-Notification-To
     Return-Receipt-To
     X-Confirm-Reading-To
     Disposition-Notification-To
     Receipt-Requested-To
     Confirm-Reading-To
     MDRcpt-To
     MDSend-Notifications-To
     Smtp-Rcpt-To
     Return-Receipt-To
     Read-Receipt-To
     X-Confirm-Reading-To
     X-Acknowledge-To
     Delivery-Receipt-To
     X-PMrqc
     Errors-To
     X-IMAPBase
     X-IMAP
     X-UID
     Status
     X-Status
     X-UIDL
     X-Keywords
     X-Mozilla-Status
     X-Mozilla-Status2
 If you are having problems with duplicate message-id headers when you
 release spam from the quarantine and send it to an Exchange server, then add
     Message-Id.
 Each header should end in a ":", but MailScanner will add it if you forget.
 Headers should be separated by commas or spaces.
 This can also be the filename of a ruleset.',
    'value' => ' X-Mozilla-Status: X-Mozilla-Status2:',
  ),
  'reqspamassassinscore' => 
  array (
    'external' => 'requiredspamassassinscore',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '6',
    'name' => 'Required SpamAssassin Score',
    'desc' => ' This replaces the SpamAssassin configuration value \'required_hits\'.
 If a message achieves a SpamAssassin score higher than this value,
 it is spam. See also the High SpamAssassin Score configuration option.
 This can also be the filename of a ruleset, so the SpamAssassin
 required_hits value can be set to different values for different messages.',
    'value' => ' 6',
  ),
  'restartevery' => 
  array (
    'external' => 'restartevery',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '14400',
    'name' => 'Restart Every',
    'desc' => ' To avoid resource leaks, re-start periodically. Forces a re-read of all
 the configuration files too, so new updates to the bad phishing sites list
 are read frequently.',
    'value' => ' 7200',
  ),
  'runasgroup' => 
  array (
    'external' => 'runasgroup',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '0',
    'name' => 'Run As Group',
    'desc' => ' Group to run as (not normally used for sendmail)
Run As Group = mail
Run As Group = postfix',
    'value' => '',
  ),
  'runasuser' => 
  array (
    'external' => 'runasuser',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '0',
    'name' => 'Run As User',
    'desc' => ' User to run as (not normally used for sendmail)
 If you want to change the ownership or permissions of the quarantine or
 temporary files created by MailScanner, please see the "Incoming Work"
 settings later in this file.
Run As User = mail
Run As User = postfix',
    'value' => '',
  ),
  'scannedsubjecttext' => 
  array (
    'external' => 'scannedsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Scanned}',
    'name' => 'Scanned Subject Text',
    'desc' => ' This is the text to add to the start/end of the subject line if the
 "Scanned Modify Subject" option is set.
 This can also be the filename of a ruleset.',
    'value' => ' {Scanned}',
  ),
  'sendercontentreport' => 
  array (
    'external' => 'senderbadcontentreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.content.report.txt',
    'name' => 'Sender Content Report',
    'desc' => ' Set where to find the messages that are delivered to the sender, when they
 sent an email containing either an error, banned content, a banned filename
 or a virus infection.
 These can also be the filenames of rulesets.',
    'value' => ' %report-dir%/sender.content.report.txt',
  ),
  'senderfilenamereport' => 
  array (
    'external' => 'senderbadfilenamereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.filename.report.txt',
    'name' => 'Sender Bad Filename Report',
    'desc' => '',
    'value' => ' %report-dir%/sender.filename.report.txt',
  ),
  'sendererrorreport' => 
  array (
    'external' => 'sendererrorreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.error.report.txt',
    'name' => 'Sender Error Report',
    'desc' => '',
    'value' => ' %report-dir%/sender.error.report.txt',
  ),
  'sendersamcpreport' => 
  array (
    'external' => 'sendermcpreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.mcp.report.txt',
    'name' => 'Sender MCP Report',
    'desc' => '',
    'value' => ' %report-dir%/sender.mcp.report.txt',
  ),
  'sendersizereport' => 
  array (
    'external' => 'sendersizereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.size.report.txt',
    'name' => 'Sender Size Report',
    'desc' => '',
    'value' => ' %report-dir%/sender.size.report.txt',
  ),
  'sendersaspamreport' => 
  array (
    'external' => 'senderspamassassinreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.spam.sa.report.txt',
    'name' => 'Sender SpamAssassin Report',
    'desc' => '',
    'value' => ' %report-dir%/sender.spam.sa.report.txt',
  ),
  'senderrblspamreport' => 
  array (
    'external' => 'senderspamlistreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.spam.rbl.report.txt',
    'name' => 'Sender Spam List Report',
    'desc' => '',
    'value' => ' %report-dir%/sender.spam.rbl.report.txt',
  ),
  'senderbothspamreport' => 
  array (
    'external' => 'senderspamreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.spam.report.txt',
    'name' => 'Sender Spam Report',
    'desc' => ' There are 3 reports:
   Sender Spam Report         -  sent when a message triggers both a Spam
                                 List and SpamAssassin,
   Sender Spam List Report    -  sent when a message triggers a Spam List,
   Sender SpamAssassin Report -  sent when a message triggers SpamAssassin.

 These can also be the filenames of rulesets.',
    'value' => ' %report-dir%/sender.spam.report.txt',
  ),
  'sendervirusreport' => 
  array (
    'external' => 'sendervirusreport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/sender.virus.report.txt',
    'name' => 'Sender Virus Report',
    'desc' => '',
    'value' => ' %report-dir%/sender.virus.report.txt',
  ),
  'sendmail' => 
  array (
    'external' => 'sendmail',
    'type' => 'command',
    'ruleset' => 'first',
    'default' => '/usr/sbin/sendmail',
    'name' => 'Sendmail',
    'desc' => ' Set how to invoke MTA when sending messages MailScanner has created
 (e.g. to sender/recipient saying "found a virus in your message")
 This can also be the filename of a ruleset.',
    'value' => ' /usr/lib/sendmail',
  ),
  'sendmail2' => 
  array (
    'external' => 'sendmail2',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '/usr/sbin/sendmail',
    'name' => 'Sendmail2',
    'desc' => ' Sendmail2 is provided for Exim users.
 It is the command used to attempt delivery of outgoing cleaned/disinfected
 messages.
 This is not usually required for sendmail.
 This can also be the filename of a ruleset.
For Exim users: Sendmail2 = /usr/sbin/exim -C /etc/exim/exim_send.conf
For sendmail users: Sendmail2 = /usr/lib/sendmail
Sendmail2 = /usr/sbin/sendmail -C /etc/exim/exim_send.conf',
    'value' => ' /usr/lib/sendmail',
  ),
  'attachimagename' => 
  array (
    'external' => 'signatureimagefilename',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '',
    'name' => 'Signature Image Filename',
    'desc' => ' When using an image in the signature, there are 2 filenames which need
 to be set. The first is the location in this server\'s filesystem of the
 image file itself. The second is the name of the image as it is stored in
 the attachment. The HTML version of the signature will refer to this
 second name in the HTML <img> tag.
 Note: the filename extension will be used as the MIME subtype, so a GIF
 image must end in ".gif" for example. (.jpg ==> "jpeg" as a special case)
 See "Attach Image To Signature" for notes on how to use this.',
    'value' => ' %report-dir%/sig.jpg',
  ),
  'silentviruses' => 
  array (
    'external' => 'silentviruses',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => 'HTML-IFrame All-Viruses',
    'name' => 'Silent Viruses',
    'desc' => ' Strings listed here will be searched for in the output of the virus scanners.
 It is used to list which viruses should be handled differently from other
 viruses. If a virus name is given here, then
 1) The sender will not be warned that he sent it
 2) No attempt at true disinfection will take place
    (but it will still be "cleaned" by removing the nasty attachments
     from the message)
 3) The recipient will not receive the message,
    unless the "Still Deliver Silent Viruses" option is set
 Other words that can be put in this list are the 5 special keywords
    HTML-IFrame   : inserting this will stop senders being warned about
                    HTML Iframe tags, when they are not allowed.
    HTML-Codebase : inserting this will stop senders being warned about
                    HTML Object Codebase/Data tags, when they are not allowed.
    HTML-Script   : inserting this will stop senders being warned about
                    HTML Script tags, when they are not allowed.
    HTML-Form     : inserting this will stop senders being warned about
                    HTML Form tags, when they are not allowed.
    Zip-Password  : inserting this will stop senders being warned about
                    password-protected zip files, when they are not allowed.
                    This keyword is not needed if you include All-Viruses.
    All-Viruses   : inserting this will stop senders being warned about
                    any virus, while still allowing you to warn senders
                    about HTML-based attacks. This includes Zip-Password
                    so you don\'t need to include both.

 The default of "All-Viruses" means that no senders of viruses will be
 notified (as the sender address is always forged these days anyway),
 but anyone who sends a message that is blocked for other reasons will
 still be notified.

 This can also be the filename of a ruleset.',
    'value' => ' HTML-IFrame All-Viruses',
  ),
  'sizesubjecttext' => 
  array (
    'external' => 'sizesubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Size}',
    'name' => 'Size Subject Text',
    'desc' => ' This is the text to add to the start of the subject if the
 "Size Modify Subject" option is set.
 You might want to change this so your users can see at a glance
 whether it just was just the message or attachment size that
 MailScanner rejected.
 This can also be the filename of a ruleset.',
    'value' => ' {Size}',
  ),
  'sophoside' => 
  array (
    'external' => 'sophosidedir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Sophos IDE Dir',
    'desc' => ' The directory (or a link to it) containing all the Sophos *.ide files.
 This is only used by the "sophossavi" virus scanner, and is irrelevant
 for all other scanners.',
    'value' => ' /opt/sophos-av/lib/sav',
  ),
  'sophoslib' => 
  array (
    'external' => 'sophoslibdir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Sophos Lib Dir',
    'desc' => ' The directory (or a link to it) containing all the Sophos *.so libraries.
 This is only used by the "sophossavi" virus scanner, and is irrelevant
 for all other scanners.',
    'value' => ' /opt/sophos-av/lib',
  ),
  'spamactions' => 
  array (
    'external' => 'spamactions',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'deliver header "X-Spam-Status: Yes"',
    'name' => 'Spam Actions',
    'desc' => ' This is a list of actions to take when a message is spam.
 It can be any combination of the following:
    deliver                 - deliver the message as normal
    delete                  - delete the message
    store                   - store the message in the (spam) quarantine
    store-nonmcp            - store the message in the non-MCP quarantine
    store-mcp               - store the message in the MCP quarantine
    store-nonspam           - store the message in the non-spam quarantine
    store-spam              - store the message in the spam quarantine
    store-<directory-path>  - store the message in the <directory-path>
    bounce                  - send a rejection message back to the sender
    forward user@domain.com - forward a copy of the message to user@domain.com
                              See the note below about the keywords that
                              can be used.
    striphtml               - convert all in-line HTML content to plain text.
                              You need to specify "deliver" as well for the
                              message to reach the original recipient.
    attachment              - Convert the original message into an attachment
                              of the message. This means the user has to take
                              an extra step to open the spam, and stops "web
                              bugs" very effectively.
    notify                  - Send the recipients a short notification that
                              spam addressed to them was not delivered. They
                              can then take action to request retrieval of
                              the original message if they think it was not
                              spam.
    header "name: value"    - Add the header
                                name: value
                              to the message. name must not contain any spaces.
                              The "value" may contain the magic keyword "_TO_"
                              anywhere in it. _TO_ will be replaced by a
                              comma-separated list of the original recipients
                              of the message. This is very useful if you just
                              forward the message to a new address and don\'t
                              use the "deliver" action, as otherwise the list
                              of the original recipients may be lost.
    custom(parameter)       - Call the CustomAction function in /usr/lib/Mail-
                              Scanner/MailScanner/CustomFunctions/CustomAction
                              .pm with the \'parameter\' passed in. This can be
                              used to implement any custom action you require.

 "forward" keywords
 ==================
 In an email address specified in the "forward" action, several keywords can
 be used which will be substituted with various properties of the message:
 _FROMUSER_   The left-hand side of the address of the sender.
 _FROMDOMAIN_ The right-hand side of the address of the sender.
 _TOUSER_     The left-hand side of each of the recipients in turn.
 _TODOMAIN_   The right-hand side of each of the recipients in turn.
 _DATE_       The date the message was received by MailScanner.
 _HOUR_       The hour the message was received by MailScanner.
 This means that you can forward messages to email addresses which show the
 original recipients of the message, which could be very useful when
 delivering into spam archive management systems.

 The default value I have set here enables Thunderbird to automatically
 handle spam when set to trust the "SpamAssassin" headers.

 This can also be the filename of a ruleset, in which case the filename
 must end in ".rule" or ".rules".
Spam Actions = store forward anonymous@ecs.soton.ac.uk',
    'value' => ' deliver header "X-Spam-Status: Yes"',
  ),
  'sacache' => 
  array (
    'external' => 'spamassassincachedatabasefile',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/var/spool/MailScanner/incoming/SpamAssassin.cache.db',
    'name' => 'SpamAssassin Cache Database File',
    'desc' => ' The SpamAssassin cache uses a database file which needs to be writable
 by the MailScanner "Run As User". This file will be created and setup for
 you automatically when MailScanner is started.
 Note: If you move the "Incoming Work Dir" then you should move this too.',
    'value' => ' /var/spool/MailScanner/incoming/SpamAssassin.cache.db',
  ),
  'cachetiming' => 
  array (
    'external' => 'spamassassincachetimings',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '1800,300,10800,172800,600',
    'name' => 'SpamAssassin Cache Timings',
    'desc' => ' Do not change this unless you absolutely have to, these numbers have
 been carefully calculated.
 They affect the length of time that different types of message are
 stored in the SpamAssassin cache which can be configured earlier in
 this file (look for "Cache").
 The numbers are all set in seconds. They are:
 1. Non-Spam cache lifetime                           = 30 minutes
 2. Spam (low scoring) cache lifetime                 = 5 minutes
 3. High-Scoring spam cache lifetime                  = 3 hours
 4. Viruses cache lifetime                            = 2 days
 5. How often to check the cache for expired messages = 10 minutes',
    'value' => ' 1800,300,10800,172800,600',
  ),
  'spamassassindefaultrulesdir' => 
  array (
    'external' => 'spamassassindefaultrulesdir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SpamAssassin Default Rules Dir',
    'desc' => ' The default rules are searched for here, and in prefix/share/spamassassin,
 /usr/local/share/spamassassin, /usr/share/spamassassin, and maybe others.
 If this is set then it adds to the list of places that are searched;
 otherwise it has no effect.
SpamAssassin Default Rules Dir = /opt/MailScanner/share/spamassassin',
    'value' => '',
  ),
  'spamassassininstallprefix' => 
  array (
    'external' => 'spamassassininstallprefix',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SpamAssassin Install Prefix',
    'desc' => ' This setting is useful if SpamAssassin is installed in an unusual place,
 e.g. /opt/MailScanner. The install prefix is used to find some fallback
 directories if neither of the following two settings work.
 If this is set then it adds to the list of places that are searched;
 otherwise it has no effect.
SpamAssassin Install Prefix = /opt/MailScanner',
    'value' => '',
  ),
  'spamassassinlocalrulesdir' => 
  array (
    'external' => 'spamassassinlocalrulesdir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SpamAssassin Local Rules Dir',
    'desc' => ' The site-local rules are searched for here, and in prefix/etc/spamassassin,
 prefix/etc/mail/spamassassin, /usr/local/etc/spamassassin, /etc/spamassassin,
 /etc/mail/spamassassin, and maybe others.
 Be careful of setting this: it may mean the spam.assassin.prefs.conf file
 is missed out, you will need to insert a soft-link with "ln -s" to link
 the file into mailscanner.cf in the new directory.
 If this is set then it replaces the list of places that are searched;
 otherwise it has no effect.
SpamAssassin Local Rules Dir = /etc/MailScanner/mail/spamassassin',
    'value' => '',
  ),
  'spamassassinlocalstatedir' => 
  array (
    'external' => 'spamassassinlocalstatedir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SpamAssassin Local State Dir',
    'desc' => ' The rules created by the "sa-update" tool are searched for here.
 This directory contains the 3.001001/updates_spamassassin_org
 directory structure beneath it.
 Only un-comment this setting once you have proved that the sa-update
 cron job has run successfully and has created a directory structure under
 the spamassassin directory within this one and has put some *.cf files in
 there. Otherwise it will ignore all your current rules!
 The default location may be /var/opt on Solaris systems.',
    'value' => ' # /var/lib/spamassassin',
  ),
  'saactions' => 
  array (
    'external' => 'spamassassinruleactions',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'SpamAssassin Rule Actions',
    'desc' => ' This next setting is very powerful. It allows you to adjust the list of
 actions taken on a message by adding or removing any action or actions,
 depending on what SpamAssassin rules it matched.
 It can be used to replace the functionality of MCP, but without the large
 processing overhead that involves.

 The setting consists of a comma-separated list of
 SA_RULENAME=>action,action,...
 pairs, where \'SA_RULENAME\' is the name of any SpamAssassin rule (or
 meta-rule), and \'action\' is the name of any of the actions listed above
 the \'Spam Actions\' configuration setting or the word "not-" preceding any
 of the action names.
 Preceding the action name with "not-" as in "not-deliver" or "not-forward
 user@domain.com" will cause the action to be removed from the list of
 actions that would normally be taken on this message.

 All of the keywords available in the "forward" action also work here.

 You can specify a comma-separated list of actions if you need more than 1
 action per rule.

 Example: Setting this to
 SpamAssassin Rule Actions = FROM_BOSS_WIFE=>not-forward secretary@domain.com
 would result in mail from the boss\'s wife not being forwarded to the boss\'s
 secretary, which would be useful if the non-spam actions for the message
 included forwarding to the boss\'s secretary.

 You can also trigger actions on the spam score of the message. You can
 compare the spam score with a number and cause this to trigger an action.
 For example, instead of a SA_RULENAME you can specify
 SpamScore>number or SpamScore>=number or SpamScore==number or
 SpamScore<number or SpamScore<=number
 where "number" is the threshold value you are comparing it against.
 So you could have a rule/action pair that looks like
                  SpamScore>25=>delete
 This would cause all messages with a total spam score of more than 25 to be
 deleted. You can use this to implement multiple levels of spam actions in
 addition to the normal spam actions and the high-scoring spam actions.

 Combining this with a ruleset makes it even more powerful, as different
 recipients and/or senders can have different sets of rules applied to them.

 This can also be the filename of a ruleset, in which case the filename
 must end in ".rule" or ".rules".',
    'value' => '',
  ),
  'spamassassinsiterulesdir' => 
  array (
    'external' => 'spamassassinsiterulesdir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SpamAssassin Site Rules Dir',
    'desc' => ' The site rules are searched for here.
 Normal location on most systems is /etc/mail/spamassassin.',
    'value' => ' /etc/mail/spamassassin',
  ),
  'spamassassintempdir' => 
  array (
    'external' => 'spamassassintemporarydir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/var/spool/MailScanner/incoming/SpamAssassin-Temp',
    'name' => 'SpamAssassin Temporary Dir',
    'desc' => ' SpamAssassin creates lots of temporary files as it works on messages.
 For speed, these should be created in a location mounted using tmpfs if
 you have it. MailScanner will attempt to mkdir it if necessary, so no
 special scripts are needed to set it up before running MailScanner.
 Note: If you move the "Incoming Work Dir" then you should move this too.',
    'value' => ' /var/spool/MailScanner/incoming/SpamAssassin-Temp',
  ),
  'spamassassintimeout' => 
  array (
    'external' => 'spamassassintimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '75',
    'name' => 'SpamAssassin Timeout',
    'desc' => ' If SpamAssassin takes longer than this (in seconds), the check is
 abandoned and the timeout noted.',
    'value' => ' 75',
  ),
  'satimeoutlen' => 
  array (
    'external' => 'spamassassintimeoutshistory',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '30',
    'name' => 'SpamAssassin Timeouts History',
    'desc' => ' The total number of SpamAssassin attempts during which "Max SpamAssassin
 Timeouts" will cause SpamAssassin to stop doing all network-based tests.
 If double the timeout value is reached (i.e. it continues to timeout at
 the same frequency as before) then it is marked as "unavailable".
 See the previous comment for more information.
 The default values of 10 and 20 mean that 10 timeouts in any sequence of
 20 attempts will trigger the behaviour described above, until the next
 periodic restart (see "Restart Every").',
    'value' => ' 30',
  ),
  'spamassassinuserstatedir' => 
  array (
    'external' => 'spamassassinuserstatedir',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SpamAssassin User State Dir',
    'desc' => ' The per-user files (bayes, auto-whitelist, user_prefs) are looked
 for here and in ~/.spamassassin/. Note the files are mutable.
 If this is unset then no extra places are searched for.
 If using Postfix, you probably want to set this as shown in the example
 line at the end of this comment, and do
      mkdir /var/spool/MailScanner/spamassassin
      chown postfix.postfix /var/spool/MailScanner/spamassassin
 NOTE: SpamAssassin is always called from MailScanner as the same user,
       and that is the "Run As" user specified above. So you can only
       have 1 set of "per-user" files, it\'s just that you might possibly
       need to modify this location.
       You should not normally need to set this at all.
SpamAssassin User State Dir = /var/spool/MailScanner/spamassassin',
    'value' => '',
  ),
  'spamdomainlist' => 
  array (
    'external' => 'spamdomainlist',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => '',
    'name' => 'Spam Domain List',
    'desc' => ' This is the list of spam domain blacklists which you are using
 (such as the "rfc-ignorant" domains). See the "Spam List Definitions"
 file for more information about what you can put here.
 This can also be the filename of a ruleset.',
    'value' => '',
  ),
  'spamheader' => 
  array (
    'external' => 'spamheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner-SpamCheck:',
    'name' => 'Spam Header',
    'desc' => ' Add this extra header to all messages found to be spam.
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner-SpamCheck:',
  ),
  'spamlist' => 
  array (
    'external' => 'spamlist',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '',
    'name' => 'Spam List',
    'desc' => ' This is the list of spam blacklists (RBLs) which you are using.
 See the "Spam List Definitions" file for more information about what
 you can put here.
 This can also be the filename of a ruleset.',
    'value' => ' # spamhaus-ZEN # You can un-comment this to enable them',
  ),
  'spamlistdefinitions' => 
  array (
    'external' => 'spamlistdefinitions',
    'type' => 'file',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/spam.lists.conf',
    'name' => 'Spam List Definitions',
    'desc' => ' This is the name of the file that translates the names of the "Spam List"
 values to the real DNS names of the spam blacklists.',
    'value' => ' %etc-dir%/spam.lists.conf',
  ),
  'normalrbls' => 
  array (
    'external' => 'spamliststobespam',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '1',
    'name' => 'Spam Lists To Be Spam',
    'desc' => ' If a message appears in at least this number of "Spam Lists" (as defined
 above), then the message will be treated as spam and so the "Spam
 Actions" will happen, unless the message reaches the levels for "High
 Scoring Spam". By default this is set to 1 to mimic the previous
 behaviour, which means that appearing in any "Spam Lists" will cause
 the message to be treated as spam.
 This can also be the filename of a ruleset.',
    'value' => ' 1',
  ),
  'highrbls' => 
  array (
    'external' => 'spamliststoreachhighscore',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '3',
    'name' => 'Spam Lists To Reach High Score',
    'desc' => ' If a message appears in at least this number of "Spam Lists" (as defined
 above), then the message will be treated as "High Scoring Spam" and so
 the "High Scoring Spam Actions" will happen. You probably want to set
 this to 2 if you are actually using this feature. 5 is high enough that
 it will never happen unless you use lots of "Spam Lists".
 This can also be the filename of a ruleset.',
    'value' => ' 3',
  ),
  'spamlisttimeout' => 
  array (
    'external' => 'spamlisttimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '10',
    'name' => 'Spam List Timeout',
    'desc' => ' If an individual "Spam List" or "Spam Domain List" check takes longer
 that this (in seconds), the check is abandoned and the timeout noted.',
    'value' => ' 10',
  ),
  'rbltimeoutlen' => 
  array (
    'external' => 'spamlisttimeoutshistory',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '10',
    'name' => 'Spam List Timeouts History',
    'desc' => ' The total number of Spam List attempts during which "Max Spam List Timeouts"
 will cause the spam list fo be marked as "unavailable". See the previous
 comment for more information.
 The default values of 5 and 10 mean that 5 timeouts in any sequence of 10
 attempts will cause the list to be marked as "unavailable" until the next
 periodic restart (see "Restart Every").',
    'value' => ' 10',
  ),
  'spamstarscharacter' => 
  array (
    'external' => 'spamscorecharacter',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => 's',
    'name' => 'Spam Score Character',
    'desc' => ' The character to use in the "Spam Score Header".
 Don\'t use: x as a score of 3 is "xxx" which the users will think is porn,
             as it will cause confusion with comments in procmail as well
              as MailScanner itself,
            * as it will cause confusion with pattern matches in procmail,
            . as it will cause confusion with pattern matches in procmail,
            ? as it will cause the users to think something went wrong.
 "s" is nice and safe and stands for "spam".',
    'value' => ' s',
  ),
  'spamstarsheader' => 
  array (
    'external' => 'spamscoreheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner-SpamScore:',
    'name' => 'Spam Score Header',
    'desc' => ' Add this extra header if "Spam Score" = yes. The header will
 contain 1 character for every point of the SpamAssassin score.',
    'value' => ' X-%org-name%-MailScanner-SpamScore:',
  ),
  'scoreformat' => 
  array (
    'external' => 'spamscorenumberformat',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '%d',
    'name' => 'Spam Score Number Format',
    'desc' => ' When putting the value of the spam score of a message into the headers,
 how do you want to format it. If you don\'t know how to use sprintf() or
 printf() in C, please *do not modify* this value. A few examples for you:
 %d     ==> 12
 %5.2f  ==> 12.34
 %05.1f ==> 012.3
 This can also be the filename of a ruleset.',
    'value' => ' %d',
  ),
  'spamsubjecttext' => 
  array (
    'external' => 'spamsubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Spam?}',
    'name' => 'Spam Subject Text',
    'desc' => ' This is the text to add to the start of the subject if the
 "Spam Modify Subject" option is set.
 The exact string "_SCORE_" will be replaced by the numeric
 SpamAssassin score.
 The exact string "_STARS_" will be replaced by a row of stars
 whose length is the SpamAssassin score.
 This can also be the filename of a ruleset.',
    'value' => ' {Spam?}',
  ),
  'spamvirusheader' => 
  array (
    'external' => 'spamvirusheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'X-MailScanner-SpamVirus-Report:',
    'name' => 'Spam-Virus Header',
    'desc' => ' Some virus scanners now use their signatures to detect spam as well as
 viruses. These "viruses" are called "spam-viruses". When they are found
 the following header will be added to your message before it is passed to
 SpamAssassin, listing all the "spam-viruses" that were found as a comma-
 separated list.
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner-SpamVirus-Report:',
  ),
  'sqlconfig' => 
  array (
    'external' => 'sqlconfig',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SQL Config',
    'desc' => ' This should be a valid SQL statement that has a single placeholder argument
 and must return two columns and one row per configuration setting.
 The placeholder will contain the hostname of the host requsting the data.
 The first column must return the \'internal\' representation of the setting
 and the second column must return the value that should be assigned.
 If the value contains \'foobar.customi[zs]e\' then the value is presumed to
 be a database ruleset and will cause the defined \'SQL Ruleset\' statement to
 be run and will use \'foobar\' as the ruleset name to retrieve the ruleset.

 This setting is required for all database functions to work; if it is not
 defined or the SQL is invalid then all database functions will be disabled.

 Exmaple: SQL Config = SELECT option, value FROM config WHERE host=?',
    'value' => '',
  ),
  'sqlquickpeek' => 
  array (
    'external' => 'sqlquickpeek',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SQL Quick Peek',
    'desc' => ' This should be a valid SQL statement that takes two placeholder arguments
 and returns a single row and column of data.  The first placeholder will
 contain the \'external\' variable representation of the MailScanner setting
 being looked-up and the second placeholder will contain the hostname of the
 host that is requesting the data.

 This setting is required for all database functions to work; if it is not
 defined or the SQL is invalid then all database functions will be disabled.

 Exmaple: SQL Quick Peek = SELECT value FROM config WHERE external = ? AND host = ?',
    'value' => '',
  ),
  'sqlruleset' => 
  array (
    'external' => 'sqlruleset',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SQL Ruleset',
    'desc' => ' This should be a valid SQL statement that has a single placeholder argument
 and must return two columns and one or more rows.  The first column must be
 a numeric starting at 1 and in ascending order and the second column should
 be the rule string.  The placeholder will contain the ruleset name.

 Example: SQL Ruleset = SELECT num, rule FROM ruleset WHERE rulesetname=? ORDER BY num ASC',
    'value' => '',
  ),
  'sqlserialnumber' => 
  array (
    'external' => 'sqlserialnumber',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SQL Serial Number',
    'desc' => ' This should be a valid SQL statement that returns a single row of data from
 your data source in integer format. This value is periodically checked every
 15 minutes and if it is numerically greater than the previously retrieved
 value then the MailScanner child will exit and reload its configuration.

 This setting is required for all database functions to work; if it is not
 defined or the SQL is invalid then all database functions will be disabled.

 Example:  SELECT value FROM config WHERE option=\'confserialnumber\'',
    'value' => '',
  ),
  'sqlspamassassinconfig' => 
  array (
    'external' => 'sqlspamassassinconfig',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'SQL SpamAssassin Config',
    'desc' => ' This should be a valid SQL statement that returns a single column and one
 or more rows.  Each row that is returned is pushed into an array and joined
 into a string separated by newlines and then passed into the SpamAssassin API
 using the {post_config_text} attribute. See the SpamAssassin API for details.
 The returned rows should be valid SpamAssassin configuration settings that
 will be processed by SpamAssassin after it has read all of normal configuration.
 Any errors will therefore be reported by SpamAssassin and will show up by
 running \'MailScanner --lint\' or \'MailScanner --debug-sa\'.

 Example:  SQL SpamAssassin Config = SELECT text FROM sa_config',
    'value' => '',
  ),
  'storedcontentmessage' => 
  array (
    'external' => 'storedbadcontentmessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/stored.content.message.txt',
    'name' => 'Stored Bad Content Message Report',
    'desc' => ' Set where to find the message text sent to users when one of their
 attachments has been deleted from a message and stored in the quarantine.
 These can also be the filenames of rulesets.',
    'value' => ' %report-dir%/stored.content.message.txt',
  ),
  'storedfilenamemessage' => 
  array (
    'external' => 'storedbadfilenamemessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/stored.filename.message.txt',
    'name' => 'Stored Bad Filename Message Report',
    'desc' => '',
    'value' => ' %report-dir%/stored.filename.message.txt',
  ),
  'storedsizemessage' => 
  array (
    'external' => 'storedsizemessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/stored.size.message.txt',
    'name' => 'Stored Size Message Report',
    'desc' => '',
    'value' => ' %report-dir%/stored.size.message.txt',
  ),
  'storedvirusmessage' => 
  array (
    'external' => 'storedvirusmessagereport',
    'type' => 'file',
    'ruleset' => 'first',
    'default' => '/usr/share/MailScanner/reports/en/stored.virus.message.txt',
    'name' => 'Stored Virus Message Report',
    'desc' => '',
    'value' => ' %report-dir%/stored.virus.message.txt',
  ),
  'logfacility' => 
  array (
    'external' => 'syslogfacility',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => 'mail',
    'name' => 'Syslog Facility',
    'desc' => ' This is the syslog "facility" name that MailScanner uses. If you don\'t
 know what a syslog facility name is, then either don\'t change this value
 or else go and read "man syslog.conf". The default value of "mail" will
 cause the MailScanner logs to go into the same place as all your other
 mail logs.',
    'value' => ' mail',
  ),
  'logsock' => 
  array (
    'external' => 'syslogsockettype',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '',
    'name' => 'Syslog Socket Type',
    'desc' => ' This is the syslog "socket type" that MailScanner uses. This should
 normally be left blank, and MailScanner will use the type appropriate
 for your operating system. The only people who may ever need to change
 this are some Solaris users who may want to set it to "native". Read
 "man Sys::Syslog" for more information. The default value depends on your
 operating system.
 This cannot be a ruleset, only a simple value.',
    'value' => '',
  ),
  'tnefexpander' => 
  array (
    'external' => 'tnefexpander',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/usr/bin/tnef --maxsize=100000000',
    'name' => 'TNEF Expander',
    'desc' => ' Where the MS-TNEF expander is installed.
 This is EITHER the full command (including maxsize option) that runs
 the external TNEF expander binary,
 OR the keyword "internal" which will make MailScanner use the Perl
 module that does the same job.
 They are both provided as I am unsure which one is faster and which
 one is capable of expanding more file formats (there are plenty!).

 The --maxsize option limits the maximum size that any expanded attachment
 may be. It helps protect against Denial Of Service attacks in TNEF files.
 This can also be the filename of a ruleset.
TNEF Expander  = internal',
    'value' => ' /usr/sbin/tnef --maxsize=100000000',
  ),
  'tneftimeout' => 
  array (
    'external' => 'tneftimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '120',
    'name' => 'TNEF Timeout',
    'desc' => ' The maximum length of time the TNEF Expander is allowed to run for 1 message.
 (in seconds)',
    'value' => ' 120',
  ),
  'mshmacnull' => 
  array (
    'external' => 'treatinvalidwatermarkswithnosenderasspam',
    'type' => 'other',
    'ruleset' => 'all',
    'default' => 'spam',
    'name' => 'Treat Invalid Watermarks With No Sender as Spam',
    'desc' => ' If the message has an invalid watermark and no sender address, then it
 is a delivery error (DSN) for a message which didn\'t come from us.
 Delivery errors have no sender address.
 So we probably want to treat it as spam, or high-scoring spam.
 This option can take one of 5 values:
         "delete",
         "spam",
         "high-scoring spam",
         "nothing" or
         a number greater than 0.
 If it is set to "delete", then the message is deleted and no further action
 is taken.
 If it is set to a number, then that is added to the message\'s spam score
 and it\'s spam status is updated accordingly.
 If you set it to "nothing" then there probably isn\'t much
 point in checking watermarks at all. But it could still be useful in
 rulesets and Custom Functions.
 This can also be the filename of a ruleset.',
    'value' => ' nothing',
  ),
  'unrarcommand' => 
  array (
    'external' => 'unrarcommand',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => '/usr/bin/unrar',
    'name' => 'Unrar Command',
    'desc' => ' Where the "unrar" command is installed.
 If you haven\'t got this command, look at www.rarlab.com.

 This is used for unpacking rar archives so that the contents can be
 checked for banned filenames and filetypes, and also that the
 archive can be tested to see if it is password-protected.
 Virus scanning the contents of rar archives is still left to the virus
 scanner, with one exception:
 If using the clavavmodule virus scanner, this adds external RAR checking
 to that scanner which is needed for archives which are RAR version 3.',
    'value' => ' /usr/bin/unrar',
  ),
  'unrartimeout' => 
  array (
    'external' => 'unrartimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '50',
    'name' => 'Unrar Timeout',
    'desc' => ' The maximum length of time the "unrar" command is allowed to run for 1
 RAR archive (in seconds)',
    'value' => ' 50',
  ),
  'unscannedheader' => 
  array (
    'external' => 'unscannedheadervalue',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'Not scanned: please contact your Internet E-Mail Service Provider for details',
    'name' => 'Unscanned Header Value',
    'desc' => ' This is the text used by the "Mark Unscanned Messages" option above.
 This can also be the filename of a ruleset.',
    'value' => ' Not scanned: please contact your Internet E-Mail Service Provider for details',
  ),
  'unzipmembers' => 
  array (
    'external' => 'unzipfilenames',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '*.txt *.ini *.log *.csv',
    'name' => 'Unzip Filenames',
    'desc' => ' The list of filename extensions that should be unpacked.
 This can also be the filename of a ruleset.',
    'value' => ' *.txt *.ini *.log *.csv',
  ),
  'unzipmaxsize' => 
  array (
    'external' => 'unzipmaximumfilesize',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '50000',
    'name' => 'Unzip Maximum File Size',
    'desc' => ' The maximum unpacked size of each file in an archive. Bigger than this, and
 the file will not be unpacked. Setting this value to 0 will disable this
 feature completely.
 This can also be the filename of a ruleset.',
    'value' => ' 50k',
  ),
  'unzipmaxmembers' => 
  array (
    'external' => 'unzipmaximumfilesperarchive',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '0',
    'name' => 'Unzip Maximum Files Per Archive',
    'desc' => ' MailScanner can automatically unpack small archives,
 so you don\'t have to go through several extra clicks to extract small
 files from automatically-generated emailed archives.

 This is the maximum number of files in each archive. If an archive contains
 more files than this, we do not try to unpack it at all.
 Set this value to 0 to disable this feature.
 This can also be the filename of a ruleset.',
    'value' => ' 0',
  ),
  'unzipmimetype' => 
  array (
    'external' => 'unzipmimetype',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'text/plain',
    'name' => 'Unzip MimeType',
    'desc' => ' The MIME type of the files unpacked from the archive.
 If you are using it for mostly text files, then use "text/plain".
 If you are using it for mostly binary files, then use
 "application/octet-stream".
 This can also be the filename of a ruleset.',
    'value' => ' text/plain',
  ),
  'spaminfected' => 
  array (
    'external' => 'virusnameswhicharespam',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => 'Sane*UNOFFICIAL',
    'name' => 'Virus Names Which Are Spam',
    'desc' => ' This defines which virus reports from your virus scanners are really the
 names of "spam-viruses" as described in the "Spam-Virus Header" section
 above. This is a space-separated list of strings which can contain "*"
 wildcards to mean "any string of characters", and which will match the
 whole name of the virus reported by your virus scanner. So for example
 "HTML/*" will match all virus names which start with the string "HTML/".
 The supplied example is suitable for F-Prot6 and the SaneSecurity
 databases for ClamAV. The test is case-sensitive.
 This cannot be a ruleset, it must be a simple value as described.',
    'value' => ' Sane*UNOFFICIAL HTML/* *Phish*',
  ),
  'virusscannerdefinitions' => 
  array (
    'external' => 'virusscannerdefinitions',
    'type' => 'file',
    'ruleset' => 'no',
    'default' => '/etc/MailScanner/virus.scanners.conf',
    'name' => 'Virus Scanner Definitions',
    'desc' => ' This is the name of the file that translates the names of the virus
 scanners into the commands that have to be run to do the actual scanning.',
    'value' => ' %etc-dir%/virus.scanners.conf',
  ),
  'virusscanners' => 
  array (
    'external' => 'virusscanners',
    'type' => 'other',
    'ruleset' => 'no',
    'default' => 'auto  # Space-separated list',
    'name' => 'Virus Scanners',
    'desc' => ' Which Virus Scanning package(s) to use:
 sophos    from www.sophos.com
 sophossavi (also from www.sophos.com, using the SAVI perl module)
 mcafee    from www.mcafee.com
 mcafee6   from www.mcafee.com (Version 6 and newer)
 command   from www.command.co.uk
 bitdefender from www.bitdefender.com
 drweb     from www.dials.ru/english/dsav_toolkit/drwebunix.htm
 kaspersky-4.5 from www.kaspersky.com (Version 4.5 and newer)
 kaspersky from www.kaspersky.com
 kavdaemonclient from www.kaspersky.com
 etrust    from http://www3.ca.com/Solutions/Product.asp?ID=156
 inoculate from www.cai.com/products/inoculateit.htm
 inoculan  from ftp.ca.com/pub/getbbs/linux.eng/inoctar.LINUX.Z
 nod32     for No32 before version 1.99 from www.nod32.com
 nod32-1.99 for Nod32 1.99 and later, from www.nod32.com
 f-secure  from www.f-secure.com
 f-prot    from www.f-prot.com
 f-prot-6  for F-Prot version 6 or later, from www.f-prot.com
 f-protd-6 for F-Prot version 6 or later "fpscand" daemon
 panda     from www.pandasoftware.com
 rav       from www.ravantivirus.com
 antivir   from www.antivir.de
 clamav    from www.clamav.net
 clamavmodule (also from www.clamav.net using the ClamAV perl module)
 clamd     (also from www.clamav.net using the clamd daemon)
           *Note: read the comments above the "Incoming Work Group" setting*,
           or
 trend     from www.trendmicro.com
 norman    from www.norman.de
 css       from www.symantec.com
 avg       from www.grisoft.com
 vexira    from www.centralcommand.com
 symscanengine from www.symantec.com (Symantec Scan Engine, not CSS)
 avast     from www.avast.com
 avastd    (also from www.avast.com and relies on avastd to be configured
           [read \'man avastd.conf\'] and running)
 esets     from www.eset.com
 vba32     from www.anti-virus.by/en/
 generic   One you wrote: edit the generic-wrapper and generic-autoupdate
           to fit your own needs. The output spec is in generic-wrapper, or
 none      No virus scanning at all.

 Note for McAfee users: do not use any symlinks with McAfee at all. It is
                        very strange but may not detect all viruses when
                        started from a symlink or scanning a directory path
                        including symlinks.

 Note: If you want to use multiple virus scanners, then this should be a
       space-separated list of virus scanners. For example:
       Virus Scanners = sophos f-prot mcafee

 Note: Make sure that you check that the base installation directory in the
       3rd column of virus.scanners.conf matches the location you have
       installed each of your virus scanners. The supplied
       virus.scanners.conf file assumes the default installation locations
       recommended by each of the virus scanner installation guides.

 Note: If you specify "auto" then MailScanner will search for all the
       scanners you have installed and will use all of them. If you really
       want none, then specify "none".

 This *cannot* be the filename of a ruleset.',
    'value' => ' auto',
  ),
  'virusscannertimeout' => 
  array (
    'external' => 'virusscannertimeout',
    'type' => 'number',
    'ruleset' => 'no',
    'default' => '300',
    'name' => 'Virus Scanner Timeout',
    'desc' => ' The maximum length of time the commercial virus scanner is allowed to run
 for 1 batch of messages (in seconds).',
    'value' => ' 300',
  ),
  'virussubjecttext' => 
  array (
    'external' => 'virussubjecttext',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => '{Virus?}',
    'name' => 'Virus Subject Text',
    'desc' => ' This is the text to add to the start of the subject if the
 "Virus Modify Subject" option is set.
 This can also be the filename of a ruleset.',
    'value' => ' {Virus?}',
  ),
  'mshmacheader' => 
  array (
    'external' => 'watermarkheader',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'MailScanner-NULL-Check:',
    'name' => 'Watermark Header',
    'desc' => ' This sets the name of the Watermark header. Good to make sure this is
 customised for your site, as you don\'t want to be reading other people\'s
 watermarks.
 This can also be the filename of a ruleset.',
    'value' => ' X-%org-name%-MailScanner-Watermark:',
  ),
  'mshmacvalid' => 
  array (
    'external' => 'watermarklifetime',
    'type' => 'number',
    'ruleset' => 'first',
    'default' => '604800',
    'name' => 'Watermark Lifetime',
    'desc' => ' This sets the lifetime of a watermark. Set it to the maximum length of
 time that you want to allow for delivery errors to be delivered.
 Most sites set their delivery timeouts to less than 7 days, so that is
 a reasonable value to use.
 This time is measured in seconds. 7 days = 604800 seconds.
 This can also be the filename of a ruleset.',
    'value' => ' 604800',
  ),
  'mshmac' => 
  array (
    'external' => 'watermarksecret',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'Watermark-secret',
    'name' => 'Watermark Secret',
    'desc' => ' This is the secret key used in the watermark calculations to ensure
 that the watermark can\'t be spoofed. It should be set to the same value
 on all the MailScanners in your organisation.

 Note: YOU SHOULD CHANGE THIS TO SOMETHING SECRET!

 Thi can also be the filename of a ruleset.',
    'value' => ' %org-name%-Secret',
  ),
  'webbugurl' => 
  array (
    'external' => 'webbugreplacement',
    'type' => 'other',
    'ruleset' => 'first',
    'default' => 'https://s3.amazonaws.com/msv4/images/spacer.gif',
    'name' => 'Web Bug Replacement',
    'desc' => ' When a web bug is found, what image do you want to replace it with?
 By replacing it with a real image, the page layout still works properly,
 so the formatting and layout of the message is correct.
 The following is a harmless untracked 1x1 pixel transparent image.
 If this is not specified, the the old value of "MailScannerWebBug" is used,
 which of course is not an image and may well upset layout of the email.
 This can also be the filename of a ruleset.',
    'value' => ' https://s3.amazonaws.com/msv4/images/spacer.gif',
  ),
  'addenvfrom' => 
  array (
    'external' => 'addenvelopefromheader',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Add Envelope From Header',
    'desc' => ' Do you want to add the Envelope-From: header?
 This is very useful for tracking where spam came from as it
 contains the envelope sender address.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'addenvto' => 
  array (
    'external' => 'addenvelopetoheader',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Add Envelope To Header',
    'desc' => ' Do you want to add the Envelope-To: header?
 This can be useful for tracking spam destinations, but should be
 used with care due to possible privacy concerns with the use of
 Bcc: headers by users.
 Note also that this information can be added conditionally by using
 the "_TO_" word in a "header" action for Spam Actions, High Scoring
 Spam Actions, Non-Spam Actions and SpamAssassin Rule Actions.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'addtextofdoc' => 
  array (
    'external' => 'addtextofdoc',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Add Text Of Doc',
    'desc' => ' Do you want to add the plain text contents of Microsoft Word documents?
 This feature uses the "antiword" program. It is switched off by default, as it 
 causes a slight performance hit.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'addmshmac' => 
  array (
    'external' => 'addwatermark',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Add Watermark',
    'desc' => ' Do you want to add a watermark to each email message?
 Setting this enables delivery error messages to be identified as yours
 so you want to see them. Delivery error messages without valid watermarks
 are treated as spam (or whatever you set below), as you probably don\'t
 want to see them. Spammers can send vast quantities of spam claiming to
 come from you so that you get all the delivery errors (known as a "joe-job"
 attack).
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'allowexternal' => 
  array (
    'external' => 'allowexternalmessagebodies',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow External Message Bodies',
    'desc' => ' Do you want to allow messages whose body is stored somewhere else on the
 internet, which is downloaded separately by the user\'s email package?
 There is no way to guarantee that the file fetched by the user\'s email
 package is free from viruses, as MailScanner never sees it.
 This feature is dangerous as it can allow viruses to be fetched from
 other Internet sites by a user\'s email package. The user would just
 think it was a normal email attachment and would have been scanned by
 MailScanner.
 It is only currently supported by Netscape 6 anyway, and the only people
 who use it are the IETF. So I would strongly advise leaving this switched off.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'allowformtags' => 
  array (
    'external' => 'allowformtags',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => 'convert',
    'values' => 
    array (
      'convert' => 'disarm',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow Form Tags',
    'desc' => ' Do you want to allow <Form> tags in email messages? This is a bad idea
 as these are used as scams to pursuade people to part with credit card
 information and other personal data.
 Value: yes     => Allow these tags to be in the message
        no      => Ban messages containing these tags
        disarm  => Allow these tags, but stop these tags from working
                   Note: Disarming can be defeated, it is not 100% safe!
 This can also be the filename of a ruleset.',
    'value' => ' disarm',
  ),
  'allowiframetags' => 
  array (
    'external' => 'allowiframetags',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => 'convert',
    'values' => 
    array (
      'convert' => 'disarm',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow IFrame Tags',
    'desc' => ' Do you want to allow <IFrame> tags in email messages? This is not a good
 idea as it allows various Microsoft Outlook security vulnerabilities to
 remain unprotected, but if you have a load of mailing lists sending them,
 then you will want to allow them to keep your users happy.
 Value: yes     => Allow these tags to be in the message
        no      => Ban messages containing these tags
        disarm  => Allow these tags, but stop these tags from working
 This can also be the filename of a ruleset, so you can allow them from
 known mailing lists but ban them from everywhere else.',
    'value' => ' disarm',
  ),
  'allowmultsigs' => 
  array (
    'external' => 'allowmultiplehtmlsignatures',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow Multiple HTML Signatures',
    'desc' => ' This option can be used to stop any duplication of en email signature
 appearing in the HTML of an email message. It looks for the "alt"
 attribute in the <img> tag specifying the image to be inserted in the
 HTML signature. If you want to use this option without inserting an image
 into the signature, simply specify an <img> tag without a "src" attribute.

 If the "alt" tag appears, and contains the word "MailScanner" and the
 word "Signature" and the %org-name% you specified at the top of this file,
 then the message is considered to already be signed. If this option is
 also set to "no", then it will not be signed again. Multiple image
 signatures at the bottom of a message can make the message very large and
 ugly once it has been replied to a couple of times.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'allowobjecttags' => 
  array (
    'external' => 'allowobjectcodebasetags',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => 'convert',
    'values' => 
    array (
      'convert' => 'disarm',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow Object Codebase Tags',
    'desc' => ' Do you want to allow <Object Codebase=...> or <Object Data=...> tags
 in email messages?
 This is a bad idea as it leaves you unprotected against various
 Microsoft-specific security vulnerabilities. But if your users demand
 it, you can do it.
 Value: yes     => Allow these tags to be in the message
        no      => Ban messages containing these tags
        disarm  => Allow these tags, but stop these tags from working
 This can also be the filename of a ruleset, so you can allow them just
 for specific users or domains.',
    'value' => ' disarm',
  ),
  'allowpartial' => 
  array (
    'external' => 'allowpartialmessages',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow Partial Messages',
    'desc' => ' Do you want to allow partial messages, which only contain a fraction of
 the attachments, not the whole thing? There is absolutely no way to
 scan these "partial messages" properly for viruses, as MailScanner never
 sees all of the attachment at the same time. Enabling this option can
 allow viruses through. You have been warned.
 This can also be the filename of a ruleset so you can, for example, allow
 them in outgoing mail but not in incoming mail.',
    'value' => ' no',
  ),
  'allowpasszips' => 
  array (
    'external' => 'allowpasswordprotectedarchives',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow Password-Protected Archives',
    'desc' => ' Should archives which contain any password-protected files be allowed?
 Leaving this set to "no" is a good way of protecting against all the
 protected zip files used by viruses at the moment.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'allowscripttags' => 
  array (
    'external' => 'allowscripttags',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => 'convert',
    'values' => 
    array (
      'convert' => 'disarm',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow Script Tags',
    'desc' => ' Do you want to allow <Script> tags in email messages? This is a bad idea
 as these are used to exploit vulnerabilities in email applications and
 web browsers.
 Value: yes     => Allow these tags to be in the message
        no      => Ban messages containing these tags
        disarm  => Allow these tags, but stop these tags from working
                   Note: Disarming can be defeated, it is not 100% safe!
 This can also be the filename of a ruleset.',
    'value' => ' disarm',
  ),
  'allowwebbugtags' => 
  array (
    'external' => 'allowwebbugs',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => 'convert',
    'values' => 
    array (
      'convert' => 'disarm',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Allow WebBugs',
    'desc' => ' Do you want to allow <Img> tags with very small images in email messages?
 This is a bad idea as these are used as \'web bugs\' to find out if a message
 has been read. It is not dangerous, it is just used to make you give away
 information.
 Value: yes     => Allow these tags to be in the message
        disarm  => Allow these tags, but stop these tags from working
                   Note: Disarming can be defeated, it is not 100% safe!
 Note: You cannot block messages containing web bugs as their detection
       is very vulnerable to false alarms.
 This can also be the filename of a ruleset.',
    'value' => ' disarm',
  ),
  'phishingnumbers' => 
  array (
    'external' => 'alsofindnumericphishing',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Also Find Numeric Phishing',
    'desc' => ' While detecting "Phishing" attacks, do you also want to point out links
 to numeric IP addresses. Genuine links to totally numeric IP addresses
 are very rare, so this option is set to "yes" by default. If a numeric
 IP address is found in a link, the same phishing warning message is used
 as in the Find Phishing Fraud option above.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'includemcpheader' => 
  array (
    'external' => 'alwaysincludemcpreport',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Always Include MCP Report',
    'desc' => '',
    'value' => ' no',
  ),
  'includespamheader' => 
  array (
    'external' => 'alwaysincludespamassassinreport',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Always Include SpamAssassin Report',
    'desc' => ' Do you want to always include the Spam Report in the SpamCheck
 header, even if the message wasn\'t spam?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'lastlookup' => 
  array (
    'external' => 'alwayslookeduplast',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Always Looked Up Last',
    'desc' => ' This option is intended for people who want to log more information
 about messages than what is put in syslog. It is intended to be used
 with a Custom Function which has the side-effect of logging information,
 perhaps to an SQL database, or any other processing you want to do
 after each message is processed.
 Its value is completely ignored, it is purely there to have side
 effects.
 If you want to use it, read CustomConfig.pm.',
    'value' => ' no',
  ),
  'lastafterbatch' => 
  array (
    'external' => 'alwayslookeduplastafterbatch',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Always Looked Up Last After Batch',
    'desc' => ' This option is intended for people who want to log per-batch information.
 This is evaluated after the "Always Looked Up Last" configuration option
 for each message in the batch. This is looked up once for the entire batch.
 Its value is completely ignored, it is purely there to have side effects.
 If you want to use it, read CustomConfig.pm.',
    'value' => ' no',
  ),
  'attachimagetohtmlonly' => 
  array (
    'external' => 'attachimagetohtmlmessageonly',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Attach Image To HTML Message Only',
    'desc' => ' Normally, you would only want to attach the image to messages with an
 HTML part, as plain text messages clearly cannot display an image.
 However, if you find some other use for this feature, you may want to
 attach an image to a message which is just text.
 See "Attach Image To Signature" for notes on how to use this.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'attachimage' => 
  array (
    'external' => 'attachimagetosignature',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Attach Image To Signature',
    'desc' => ' If you are using HTML signatures, you can embed an image in the signature.
 For the filename(s) of the image, see the settings "Signature Image
 Filename" and "Signature Image <img> Filename".
 In your HTML, you must refer to the image with an HTML tag that looks like:
     <img alt="MailScanner Signature" src="cid:signature.jpg">
 where "signature.jpg" is the name of the image set in the
 "Signature Image <img> Filename" setting above. If used correctly, Mail-
 Scanner will notice if the image is already present and not add it again.
 
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'syntaxcheck' => 
  array (
    'external' => 'automaticsyntaxcheck',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Automatic Syntax Check',
    'desc' => ' Do you want to automatically do a syntax check of the configuration files
 when MailScanner is started up? It will still start up, regardless, but it
 will print plenty of errors and warnings if anything important is wrong in
 your setup, instead of just logging it to your system\'s mail logs. It does
 slightly slow down the startup of MailScanner, of course, but that is only
 done once and so it does not really matter.
 This makes it easier for novice users.
 This cannot be a ruleset, only a simple value.',
    'value' => ' yes',
  ),
  'blockencrypted' => 
  array (
    'external' => 'blockencryptedmessages',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Block Encrypted Messages',
    'desc' => ' Should encrypted messages be blocked?
 This is useful if you are wary about your users sending encrypted
 messages to your competition.
 This can be a ruleset so you can block encrypted message to certain domains.',
    'value' => ' no',
  ),
  'blockunencrypted' => 
  array (
    'external' => 'blockunencryptedmessages',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Block Unencrypted Messages',
    'desc' => ' Should unencrypted messages be blocked?
 This could be used to ensure all your users send messages outside your
 company encrypted to avoid snooping of mail to your business partners.
 This can be a ruleset so you can just check mail to certain users/domains.',
    'value' => ' no',
  ),
  'bouncemcpasattachment' => 
  array (
    'external' => 'bouncemcpasattachment',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Bounce MCP As Attachment',
    'desc' => '',
    'value' => ' no',
  ),
  'bouncespamasattachment' => 
  array (
    'external' => 'bouncespamasattachment',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Bounce Spam As Attachment',
    'desc' => ' When you bounce a spam message back to the sender, do you want to
 encapsulate it in another message, rather like the "attachment" option
 when delivering spam to the original recipient?
 NOTE: If you enable this option, be sure to whitelist your local server
       ie. 127.0.0.1 as otherwise the spam bounce message will be detected
       as spam again, which will cause another spam bounce and so on
       until your mail queues fill up and your server crashes!
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'usesacache' => 
  array (
    'external' => 'cachespamassassinresults',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Cache SpamAssassin Results',
    'desc' => ' Many naive spammers send out the same message to lots of people.
 These messages are very likely to have roughly the same SpamAssassin score.
 For extra speed, cache the SpamAssassin results for the messages
 being processed so that you only call SpamAssassin once for all of the
 messages.
 If you set this to "no" then the entire SpamAssassin Cache Database File
 is not used, along with its requirement for SQLite.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'checkppafilenames' => 
  array (
    'external' => 'checkfilenamesinpasswordprotectedarchives',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Check Filenames In Password-Protected Archives',
    'desc' => ' Normally, you can still get the filenames out of a password-protected
 archive, despite the encryption. So by default filename checks are still
 done on these files. However, some people want to suppress this checking
 as they allow a few people to receive password-protected archives that
 contain things such as .exe\'s as part of their business needs. This option
 can be used to suppress filename checks inside password-protected archives.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'checksaifonspamlist' => 
  array (
    'external' => 'checkspamassassinifonspamlist',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Check SpamAssassin If On Spam List',
    'desc' => ' If the message sender is on any of the Spam Lists, do you still want
 to do the SpamAssassin checks? Setting this to "no" will reduce the load
 on your server, but will stop the High Scoring Spam Actions from ever
 happening.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'checkmshmacskip' => 
  array (
    'external' => 'checkwatermarkstoskipspamchecks',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Check Watermarks To Skip Spam Checks',
    'desc' => ' Enable this feature if you have more then one Mailscanner installation
 (or you have a trust relationship with another Mailscanner user). An
 example would be a secondary MX with MailScanner installed which relays
 to the primary MX for delivery. For this to work you need to use the
 same value for "Watermark Header", and have the same "Watermark Secret".

 This could be achieved by using a ruleset.

 This feature skips Spam Checks if the Watermark is trusted. The trust
 only works between servers so will not apply to replies to emails.

 If the Watermark has expired or is invalid then the message is processed
 as normal.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'checkmshmac' => 
  array (
    'external' => 'checkwatermarkswithnosender',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Check Watermarks With No Sender',
    'desc' => ' Do you want to check watermarks?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'clamavspam' => 
  array (
    'external' => 'clamavfullmessagescan',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'ClamAV Full Message Scan',
    'desc' => ' There are now sets of signatures available from places such as
 www.sanesecurity.co.uk which use ClamAV to detect spam. Some of these
 signatures rely on being passed the whole message as one file. By setting
 this option to "yes", each entire message is written out to the scanning
 area, thus enabling these signatures to work reliably.
 It has a slight speed impact but is worth it for the extra spam-spotting
 ability.

 This option cannot be the filename of a ruleset, it must be "yes" or "no".',
    'value' => ' yes',
  ),
  'clamdusethreads' => 
  array (
    'external' => 'clamdusethreads',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Clamd Use Threads',
    'desc' => '',
    'value' => ' no',
  ),
  'contentmodifysubject' => 
  array (
    'external' => 'contentmodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Content Modify Subject',
    'desc' => ' If an attachment triggered a content check, but there was nothing
 else wrong with the message, do you want to modify the subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This makes filtering in Outlook very easy.
 This can also be the filename of a ruleset.',
    'value' => ' start',
  ),
  'stripdangeroustags' => 
  array (
    'external' => 'convertdangeroushtmltotext',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Convert Dangerous HTML To Text',
    'desc' => ' This option interacts with the "Allow ... Tags" options above like this:

 Allow...Tags    Convert Danger...    Action Taken on HTML Message
 ============    =================    ============================
    no              no                Blocked
    no              yes               Blocked
    disarm          no                Specified HTML tags disarmed
    disarm          yes               Specified HTML tags disarmed
    yes             no                Nothing, allowed to pass
    yes             yes               All HTML tags stripped

 If an "Allow ... Tags = yes" is triggered by a message, and this
 "Convert Dangerous HTML To Text" is set to "yes", then the HTML
 message will be converted to plain text.  This makes the HTML
 harmless, while still allowing your users to see the text content
 of the messages.  Note that all graphical content will be removed.

 This can also be the filename of a ruleset, so you can make this apply
 only to specific users or domains.',
    'value' => ' no',
  ),
  'htmltotext' => 
  array (
    'external' => 'converthtmltotext',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Convert HTML To Text',
    'desc' => ' Do you want to convert all HTML messages into plain text?
 This is very useful for users who are children or are easily offended
 by nasty things like pornographic spam.
 This can also be the filename of a ruleset, so you can switch this
 feature on and off for particular users or domains.',
    'value' => ' no',
  ),
  'dangerscan' => 
  array (
    'external' => 'dangerouscontentscanning',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Dangerous Content Scanning',
    'desc' => ' Do you want to scan the messages for potentially dangerous content?
 Setting this to "no" will disable all the content-based checks except
 Virus Scanning, Allow Partial Messages and Allow External Message Bodies.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'debug' => 
  array (
    'external' => 'debug',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Debug',
    'desc' => ' Set Debug to "yes" to stop it running as a daemon and just process
 one batch of messages and then exit.',
    'value' => ' no',
  ),
  'debugspamassassin' => 
  array (
    'external' => 'debugspamassassin',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Debug SpamAssassin',
    'desc' => ' Do you want to debug SpamAssassin from within MailScanner?',
    'value' => ' no',
  ),
  'mcpblacklistedishigh' => 
  array (
    'external' => 'definitemcpishighscoring',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Definite MCP Is High Scoring',
    'desc' => '',
    'value' => ' no',
  ),
  'blacklistedishigh' => 
  array (
    'external' => 'definitespamishighscoring',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Definite Spam Is High Scoring',
    'desc' => ' Setting this to yes means that spam found in the blacklist is treated
 as "High Scoring Spam" in the "Spam Actions" section below. Setting it
 to no means that it will be treated as "normal" spam.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'delivercleanedmessages' => 
  array (
    'external' => 'delivercleanedmessages',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Deliver Cleaned Messages',
    'desc' => ' Do you want to deliver messages once they have been cleaned of any
 viruses?
 By making this a ruleset, you can re-create the "Deliver From Local"
 facility of previous versions.',
    'value' => ' yes',
  ),
  'deliverdisinfected' => 
  array (
    'external' => 'deliverdisinfectedfiles',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Deliver Disinfected Files',
    'desc' => ' Should I attempt to disinfect infected attachments and then deliver
 the clean ones. "Disinfection" involves removing viruses from files
 (such as removing macro viruses from documents). "Cleaning" is the
 replacement of infected attachments with "VirusWarning.txt" text
 attachments.
 Less than 1% of viruses in the wild can be successfully disinfected,
 as macro viruses are now a rare occurrence. So the default has been
 changed to "no" as it gives a significant performance improvement.

 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'deliverinbackground' => 
  array (
    'external' => 'deliverinbackground',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Deliver In Background',
    'desc' => ' When attempting delivery of outgoing messages, should we do it in the
 background or wait for it to complete? The danger of doing it in the
 background is that the machine load goes ever upwards while all the
 slow sendmail processes run to completion. However, running it in the
 foreground may cause the mail server to run too slowly.',
    'value' => ' yes',
  ),
  'deliverunparsabletnef' => 
  array (
    'external' => 'deliverunparsabletnef',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Deliver Unparsable TNEF',
    'desc' => ' Some versions of Microsoft Outlook generate unparsable Rich Text
 format attachments. Do we want to deliver these bad attachments anyway?
 Setting this to yes introduces the slight risk of a virus getting through,
 but if you have a lot of troubled Outlook users you might need to do this.
 We are working on a replacement for the TNEF decoder.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'deliverymethod' => 
  array (
    'external' => 'deliverymethod',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'batch',
    'values' => 
    array (
      'queue' => 'queue',
      'batch' => 'batch',
    ),
    'name' => 'Delivery Method',
    'desc' => ' Attempt immediate delivery of messages, or just place them in the outgoing
 queue for the MTA to deliver when it wants to?
      batch -- attempt delivery of messages, in batches of up to 20 at once.
      queue -- just place them in the queue and let the MTA find them.
 This can also be the filename of a ruleset. For example, you could use a
 ruleset here so that messages coming to you are immediately delivered,
 while messages going to any other site are just placed in the queue in
 case the remote delivery is very slow.',
    'value' => ' batch',
  ),
  'mcpdetail' => 
  array (
    'external' => 'detailedmcpreport',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Detailed MCP Report',
    'desc' => '',
    'value' => ' yes',
  ),
  'spamdetail' => 
  array (
    'external' => 'detailedspamreport',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Detailed Spam Report',
    'desc' => ' Do you want the full spam report, or just a simple "spam / not spam" report?',
    'value' => ' yes',
  ),
  'disarmmodifysubject' => 
  array (
    'external' => 'disarmedmodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Disarmed Modify Subject',
    'desc' => ' If HTML tags in the message were "disarmed" by using the HTML "Allow"
 options above with the "disarm" settings, do you want to modify the
 subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This can also be the filename of a ruleset.',
    'value' => ' start',
  ),
  'enablespambounce' => 
  array (
    'external' => 'enablespambounce',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Enable Spam Bounce',
    'desc' => ' You can use this ruleset to enable the "bounce" Spam Action.
 You must *only* enable this for mail from sites with which you have
 agreed to bounce possible spam. Use it on low-scoring spam only (<10)
 and only to your regular customers for use in the rare case that a
 message is mis-tagged as spam when it shouldn\'t have been.
 Beware that many sites will automatically delete the bounce messages
 created by using this option unless you have agreed this with them in
 advance.
 If you enable this, be prepared to handle the irate responses from
 people to whom you are essentially sending more spam!',
    'value' => ' %rules-dir%/bounce.rules',
  ),
  'expandtnef' => 
  array (
    'external' => 'expandtnef',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Expand TNEF',
    'desc' => ' Expand TNEF attachments using an external program (or a Perl module)?
 This should be "yes" unless the scanner you are using (Sophos, McAfee) has
 the facility built-in. However, if you set it to "no", then the filenames
 within the TNEF attachment will not be checked against the filename rules.',
    'value' => ' yes',
  ),
  'namemodifysubject' => 
  array (
    'external' => 'filenamemodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Filename Modify Subject',
    'desc' => ' If an attachment triggered a filename check, but there was nothing
 else wrong with the message, do you want to modify the subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This makes filtering in Outlook very easy.
 This can also be the filename of a ruleset.',
    'value' => ' start',
  ),
  'findarchivesbycontent' => 
  array (
    'external' => 'findarchivesbycontent',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Find Archives By Content',
    'desc' => ' Find zip archives by filename or by file contents?
 Finding them by content is a far more reliable way of finding them, but
 it does mean that you cannot tell your users to avoid zip file checking
 by renaming the file from ".zip" to "_zip" and tricks like that.
 Only set this to no (i.e. check by filename only) if you don\'t want to
 reliably check the contents of zip files. Note this does not affect
 virus checking, but it will affect all the other checks done on the contents
 of the zip file.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'findphishing' => 
  array (
    'external' => 'findphishingfraud',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Find Phishing Fraud',
    'desc' => ' Do you want to check for "Phishing" attacks?
 These are attacks that look like a genuine email message from your bank,
 which contain a link to click on to take you to the web site where you
 will be asked to type in personal information such as your account number
 or credit card details.
 Except it is not the real bank\'s web site at all, it is a very good copy
 of it run by thieves who want to steal your personal information or
 credit card details.
 These can be spotted because the real address of the link in the message
 is not the same as the text that appears to be the link.
 Note: This does cause extra load, particularly on systems receiving lots
       of spam such as secondary MX hosts.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'lookforuu' => 
  array (
    'external' => 'finduuencodedfiles',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Find UU-Encoded Files',
    'desc' => ' A few viruses store their infected data in UU-encoded files, to try to
 catch out virus scanners. This rarely succeeds at all.
 Setting this option to yes means that you can apply filename and filetype
 checks to the contents of UU-encoded files. This may occasionally be
 useful, in which case you should set to yes.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'hideworkdir' => 
  array (
    'external' => 'hideincomingworkdir',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Hide Incoming Work Dir',
    'desc' => ' Hide the directory path from all virus scanner reports sent to users.
 The extra directory paths give away information about your setup, and
 tend to just confuse users.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'hideworkdirinnotice' => 
  array (
    'external' => 'hideincomingworkdirinnotices',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Hide Incoming Work Dir in Notices',
    'desc' => ' Hide the directory path from all the system administrator notices.
 The extra directory paths give away information about your setup, and
 tend to just confuse users but are still useful for local sys admins.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'phishinghighlight' => 
  array (
    'external' => 'highlightphishingfraud',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Highlight Phishing Fraud',
    'desc' => ' If a phishing fraud is detected, do you want to highlight the tag with
 a message stating that the link may be to a fraudulent web site.
 This can also be the filename of a ruleeset.',
    'value' => ' yes',
  ),
  'highmcpmodifysubject' => 
  array (
    'external' => 'highscoringmcpmodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'High Scoring MCP Modify Subject',
    'desc' => '',
    'value' => ' start',
  ),
  'highspammodifysubject' => 
  array (
    'external' => 'highscoringspammodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'High Scoring Spam Modify Subject',
    'desc' => ' This is just like the "Spam Modify Subject" option above, except that
 it applies when the score from SpamAssassin is higher than the
 "High SpamAssassin Score" value.
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This can also be the filename of a ruleset.',
    'value' => ' start',
  ),
  'sadecodebins' => 
  array (
    'external' => 'includebinaryattachmentsinspamassassin',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Include Binary Attachments In SpamAssassin',
    'desc' => ' Normally, SpamAssassin skips over all non-text attachments and does not
 scan them for indications that the message is spam.
 This setting over-rides that behaviour, telling SpamAssassin to scan all
 attachments regardless of type. This can be very useful for spotting rude
 and derogatory content in Microsoft Word documents, for example.
 However, it does slightly slow SpamAssassin and so is disabled by default.
 Setting this to "yes" will have no effect without a small patch to the
 SpamAssassin code. You can fetch the patch for your version of SpamAssassin
 from "http://www.mailscanner.info/mcp.htmlpatches". That web page will
 explain in detail how to apply the patch.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'showscanner' => 
  array (
    'external' => 'includescannernameinreports',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Include Scanner Name In Reports',
    'desc' => ' Include the name of the virus scanner in each of the scanner reports.
 This also includes the translation of "MailScanner" in each of the report
 lines resulting from one of MailScanner\'s own checks such as filename,
 filetype or dangerous HTML content. To change the name "MailScanner", look
 in reports/...../languages.conf.

 Very useful if you use several virus scanners, but a bad idea if you
 don\'t want to let your customers know which scanners you use.',
    'value' => ' yes',
  ),
  'mcplistsascores' => 
  array (
    'external' => 'includescoresinmcpreport',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Include Scores In MCP Report',
    'desc' => '',
    'value' => ' no',
  ),
  'listsascores' => 
  array (
    'external' => 'includescoresinspamassassinreport',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Include Scores In SpamAssassin Report',
    'desc' => ' Do you want to include the numerical scores in the detailed SpamAssassin
 report, or just list the names of the scores',
    'value' => ' yes',
  ),
  'mcpblacklist' => 
  array (
    'external' => 'isdefinitelymcp',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Is Definitely MCP',
    'desc' => '',
    'value' => ' no',
  ),
  'mcpwhitelist' => 
  array (
    'external' => 'isdefinitelynotmcp',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Is Definitely Not MCP',
    'desc' => '',
    'value' => ' no',
  ),
  'spamwhitelist' => 
  array (
    'external' => 'isdefinitelynotspam',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Is Definitely Not Spam',
    'desc' => ' Spam Whitelist:
 Make this point to a ruleset, and anything in that ruleset whose value
 is "yes" will *never* be marked as spam.
 The whitelist check is done before the blacklist check. If anyone whitelists
 a message, then all recipients get the message. If no-one has whitelisted it,
 then the blacklist is checked.
 This setting over-rides the "Is Definitely Spam" setting.
 This can also be the filename of a ruleset.
Is Definitely Not Spam = no',
    'value' => ' %rules-dir%/spam.whitelist.rules',
  ),
  'spamblacklist' => 
  array (
    'external' => 'isdefinitelyspam',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Is Definitely Spam',
    'desc' => ' Spam Blacklist:
 Make this point to a ruleset, and anything in that ruleset whose value
 is "yes" will *always* be marked as spam.
 This value can be over-ridden by the "Is Definitely Not Spam" setting.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'keepspamarchiveclean' => 
  array (
    'external' => 'keepspamandmcparchiveclean',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Keep Spam And MCP Archive Clean',
    'desc' => ' Do you want to stop any virus-infected spam getting into the spam or MCP
 archives? If you have a system where users can release messages from the
 spam or MCP archives, then you probably want to stop them being able to
 release any infected messages, so set this to yes.
 It is set to no by default as it causes a small hit in performance, and
 many people don\'t allow users to access the spam quarantine, so don\'t
 need it.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'loghtmltags' => 
  array (
    'external' => 'logdangeroushtmltags',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Dangerous HTML Tags',
    'desc' => ' Log all occurrences of HTML tags found in messages, that can be blocked.
 This will help you build up your whitelist of message sources for which
 particular HTML tags should be allowed, such as mail from newsletters
 and daily cartoon strips.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'logdelivery' => 
  array (
    'external' => 'logdeliveryandnondelivery',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Delivery And Non-Delivery',
    'desc' => ' Do you want to log all messages that are delivered and not delivered
 to the original recipients. Note that this log output will include
 the Subject: of the original email, so is switched off by default.
 In some countries, particularly the EU, it may well be illegal to log
 the Subject: of email messages.',
    'value' => ' no',
  ),
  'logmcp' => 
  array (
    'external' => 'logmcp',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log MCP',
    'desc' => '',
    'value' => ' no',
  ),
  'lognonspam' => 
  array (
    'external' => 'lognonspam',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Non Spam',
    'desc' => ' Do you want all non-spam to be logged? Useful if you want to see
 all the SpamAssassin reports of mail that was marked as non-spam.
 Note: It will generate a lot of log traffic.',
    'value' => ' no',
  ),
  'logpermittedfilemimetypes' => 
  array (
    'external' => 'logpermittedfilemimetypes',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Permitted File MIME Types',
    'desc' => ' Log all the filenames that are allowed by the MIME types set in Filetype
 Rules, or just the MIME tyes that are denied?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'logpermittedfilenames' => 
  array (
    'external' => 'logpermittedfilenames',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Permitted Filenames',
    'desc' => ' Log all the filenames that are allowed by the Filename Rules, or just
 the filenames that are denied?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'logpermittedfiletypes' => 
  array (
    'external' => 'logpermittedfiletypes',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Permitted Filetypes',
    'desc' => ' Log all the filenames that are allowed by the Filetype Rules, or just
 the filetypes that are denied?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'logsilentviruses' => 
  array (
    'external' => 'logsilentviruses',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Silent Viruses',
    'desc' => ' Log all occurrences of "Silent Viruses" as defined above?
 This can only be a simple yes/no value, not a ruleset.',
    'value' => ' no',
  ),
  'logspam' => 
  array (
    'external' => 'logspam',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Spam',
    'desc' => ' Do you want all spam to be logged? Useful if you want to gather
 spam statistics from your logs, but can increase the system load quite
 a bit if you get a lot of spam.',
    'value' => ' no',
  ),
  'logsaactions' => 
  array (
    'external' => 'logspamassassinruleactions',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log SpamAssassin Rule Actions',
    'desc' => ' Log all actions from the "SpamAssassin Rule Actions" setting?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'logspeed' => 
  array (
    'external' => 'logspeed',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Log Speed',
    'desc' => ' Do you want to log the processing speed for each section of the code
 for a batch? This can be very useful for diagnosing speed problems,
 particularly in spam checking.',
    'value' => ' no',
  ),
  'markinfectedmessages' => 
  array (
    'external' => 'markinfectedmessages',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Mark Infected Messages',
    'desc' => ' Add the "Inline HTML Warning" or "Inline Text Warning" to the top of
 messages that have had attachments removed from them?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'signunscannedmessages' => 
  array (
    'external' => 'markunscannedmessages',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Mark Unscanned Messages',
    'desc' => ' When a message is to not be virus-scanned (which may happen depending
 upon the setting of "Virus Scanning", especially if it is a ruleset),
 do you want to add the header advising the users to get their email
 virus-scanned by you?
 Very good for advertising your MailScanning service and encouraging
 users to give you some more money and sign up to virus scanning.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'mcpchecks' => 
  array (
    'external' => 'mcpchecks',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'MCP Checks',
    'desc' => '',
    'value' => ' no',
  ),
  'mcpmodifysubject' => 
  array (
    'external' => 'mcpmodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'MCP Modify Subject',
    'desc' => '',
    'value' => ' start',
  ),
  'assumeisdir' => 
  array (
    'external' => 'missingmailarchiveis',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'directory',
      0 => 'file',
    ),
    'name' => 'Missing Mail Archive Is',
    'desc' => ' If a location specified in "Archive Mail" is not found, should it assume
 that the location is a file or a directory name?
 Before this option was added, it was always assumed to be a directory.
 However, if the _FROMUSER_, _FROMDOMAIN_, _TOUSER_, _TODOMAIN_, _DATE_
 or _HOUR_ tokens are used in the name of the location, it might be
 useful to store the messages in an mbox file containing the address of
 the recipient.

 This can also be the filename of a ruleset.',
    'value' => ' directory',
  ),
  'multipleheaders' => 
  array (
    'external' => 'multipleheaders',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'append',
    'values' => 
    array (
      'add' => 'add',
      'replace' => 'replace',
      'append' => 'append',
    ),
    'name' => 'Multiple Headers',
    'desc' => ' What to do when you get several MailScanner headers in one message,
 from multiple MailScanner servers. Values are
      "append"  : Append the new data to the existing header
      "add"     : Add a new header
      "replace" : Replace the old data with the new data
 Default is "append"
 This can also be the filename of a ruleset.',
    'value' => ' append',
  ),
  'noticefullheaders' => 
  array (
    'external' => 'noticesincludefullheaders',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Notices Include Full Headers',
    'desc' => ' Include the full headers of each message in the notices sent to the local
 system administrators?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'warnsenders' => 
  array (
    'external' => 'notifysenders',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Notify Senders',
    'desc' => ' Do you want to notify the people who sent you messages containing
 viruses or badly-named filenames?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'warnnamesenders' => 
  array (
    'external' => 'notifysendersofblockedfilenamesorfiletypes',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Notify Senders Of Blocked Filenames Or Filetypes',
    'desc' => ' *If* "Notify Senders" is set to yes, do you want to notify people
 who sent you messages containing attachments that are blocked due to
 their filename or file contents?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'warnsizesenders' => 
  array (
    'external' => 'notifysendersofblockedsizeattachments',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Notify Senders Of Blocked Size Attachments',
    'desc' => ' *If* "Notify Senders" is set to yes, do you want to notify people
 who sent you messages containing attachments that are blocked due to
 being too small or too large?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'warnothersenders' => 
  array (
    'external' => 'notifysendersofotherblockedcontent',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Notify Senders Of Other Blocked Content',
    'desc' => ' *If* "Notify Senders" is set to yes, do you want to notify people
 who sent you messages containing other blocked content, such as
 partial messages or messages with external bodies?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'warnvirussenders' => 
  array (
    'external' => 'notifysendersofviruses',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Notify Senders Of Viruses',
    'desc' => ' *If* "Notify Senders" is set to yes, do you want to notify people
 who sent you messages containing viruses?
 The default value has been changed to "no" as most viruses now fake
 sender addresses and therefore should be on the "Silent Viruses" list.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'tagphishingsubject' => 
  array (
    'external' => 'phishingmodifysubject',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Phishing Modify Subject',
    'desc' => ' If a potential phishing attack is found in the message, do you want to
 modify the subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'newheadersattop' => 
  array (
    'external' => 'placenewheadersattopofmessage',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Place New Headers At Top Of Message',
    'desc' => ' Some people prefer that message headers are added in strict order with
 the newest headers at the top and the oldest headers at the bottom.
 This is also required if you receive a message which is authenticated by
 DKIM, and you are forwarding that message onto somewhere else, and want
 not to break the DKIM signature.
 **Note**: To avoid breaking DKIM signatures, you *must* also set
   Multiple Headers = add
 So if some of your users forward mail from PayPal, Ebay or Yahoo! to
 accounts stored on Gmail or Googlemail, then you need to set this to "yes"
 and "Multiple Headers = add" to avoid breaking the DKIM signature.
 It may be worth using a ruleset to just apply this to messages sent by
 the companies mentioned above.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'quarantineinfections' => 
  array (
    'external' => 'quarantineinfections',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Quarantine Infections',
    'desc' => ' Do you want to store copies of the infected attachments and messages?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'quarantinemodifiedbody' => 
  array (
    'external' => 'quarantinemodifiedbody',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Quarantine Modified Body',
    'desc' => ' Do you want to store copies of messages which have been disarmed by
 having their HTML modified at all?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'quarantinesilent' => 
  array (
    'external' => 'quarantinesilentviruses',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Quarantine Silent Viruses',
    'desc' => ' There is no point quarantining most viruses these days as the infected
 messages contain no useful content, so if you set this to "no" then no
 infections listed in your "Silent Viruses" setting will be quarantined,
 even if you have chosen to quarantine infections in general. This is
 currently set to "yes" so the behaviour is the same as it was in
 previous versions.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'quarantinewholemessage' => 
  array (
    'external' => 'quarantinewholemessage',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Quarantine Whole Message',
    'desc' => ' Do you want to quarantine the original *entire* message as well as
 just the infected attachments?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'storeentireasdfqf' => 
  array (
    'external' => 'quarantinewholemessagesasqueuefiles',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Quarantine Whole Messages As Queue Files',
    'desc' => ' When you quarantine an entire message, do you want to store it as
 raw mail queue files (so you can easily send them onto users) or
 as human-readable files (header then body in 1 file)?',
    'value' => ' no',
  ),
  'rejectmessage' => 
  array (
    'external' => 'rejectmessage',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Reject Message',
    'desc' => ' You may not want to receive mail from certain addresses and/or to certain
 addresses. If so, you can do this with your email transport (sendmail,
 Postfix, etc) but that will just send a one-line message which is not
 helpful to the user sending the message.
 If this is set to yes, then the message set by the "Rejection Report"
 will be sent instead, and the incoming message will be deleted.
 If you want to store a copy of the original incoming message then use the
 "Archive Mail" setting to archive a copy of it.
 The purpose of this option is to set it to be a ruleset, so that you
 can reject messages from a few offending addresses where you need to  send
 a polite reply instead of just a brief 1-line rejection message.',
    'value' => ' no',
  ),
  'runinforeground' => 
  array (
    'external' => 'runinforeground',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Run In Foreground',
    'desc' => ' Set Run In Foreground to "yes" if you want MailScanner to operate
 normally in foreground (and not as a background daemon).
 Use this if you are controlling the execution of MailScanner
 with a tool like DJB\'s \'supervise\' (see http://cr.yp.to/daemontools.html).',
    'value' => ' no',
  ),
  'scanmail' => 
  array (
    'external' => 'scanmessages',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      2 => 'virus',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Scan Messages',
    'desc' => ' If this is set to "yes", then email messages passing through MailScanner
 will be processed and checked, and all the other options in this file
 will be used to control what checks are made on the message.

 If this is set to "no", then email messages will NOT be processed or
 checked *at all*, and so any viruses or other problems will be ignored.

 If this is set to "virus", then email messages will only be scanned for
 viruses and *nothing* else.

 The purpose of this option is to set it to be a ruleset, so that you
 can skip all scanning of mail destined for some of your users/customers
 and still scan all the rest.
 A sample ruleset would look like this:
   To:       bad.customer.com  no
   From:     ignore.domain.com no
   From:     my.domain.com     virus
   FromOrTo: default           yes
 That will scan all mail except mail to bad.customer.com and mail from
 ignore.domain.com. To set this up, put the 3 lines above into a file
 called /etc/MailScanner/rules/scan.messages.rules and set the next line to
 Scan Messages = %rules-dir%/scan.messages.rules
 This can also be the filename of a ruleset (as illustrated above).',
    'value' => ' yes',
  ),
  'scannedmodifysubject' => 
  array (
    'external' => 'scannedmodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Scanned Modify Subject',
    'desc' => ' When the message has been scanned but no other subject line changes
 have happened, do you want modify the subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line, or
      yes   = Add text to the end of the subject line.
 This makes very good advertising of your MailScanning service.
 This can also be the filename of a ruleset.',
    'value' => ' no # end',
  ),
  'sendnotices' => 
  array (
    'external' => 'sendnotices',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Send Notices',
    'desc' => ' Notify the local system administrators ("Notices To") when any infections
 are found?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'signcleanmessages' => 
  array (
    'external' => 'signcleanmessages',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Sign Clean Messages',
    'desc' => ' Add the "Inline HTML Signature" or "Inline Text Signature" to the end
 of uninfected messages?
 If you add your own signature in your email application, and include the
 magic token "_SIGNATURE_" in your email message, the signature will be
 inserted just there, rather than at the end of the message.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'signalreadyscanned' => 
  array (
    'external' => 'signmessagesalreadyprocessed',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Sign Messages Already Processed',
    'desc' => ' If this is "no", then (as far as possible) messages which have already
 been processed by another MailScanner server will not have the clean
 signature added to the message. This prevents messages getting many
 copies of the signature as they flow through your site.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'sizemodifysubject' => 
  array (
    'external' => 'sizemodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Size Modify Subject',
    'desc' => ' If an attachment or the entire message triggered a size check, but
 there was nothing else wrong with the message, do you want to modify
 the subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This makes filtering in Outlook very easy.
 This can also be the filename of a ruleset.',
    'value' => ' start',
  ),
  'spamassassinautowhitelist' => 
  array (
    'external' => 'spamassassinautowhitelist',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'SpamAssassin Auto Whitelist',
    'desc' => ' Set this option to "yes" to enable the automatic whitelisting functions
 available within SpamAssassin. This will cause addresses from which you
 get real mail, to be marked so that it will never incorrectly spam-tag
 messages from those addresses.
 To disable whitelisting, you must set "use_auto_whitelist 0" in your
 spam.assassin.prefs.conf file as well as set this to no.',
    'value' => ' yes',
  ),
  'spamchecks' => 
  array (
    'external' => 'spamchecks',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Spam Checks',
    'desc' => ' Do you want to check messages to see if they are spam?
 Note: If you switch this off then *no* spam checks will be done at all.
       This includes both MailScanner\'s own checks and SpamAssassin.
       If you want to just disable the "Spam List" feature then set
       "Spam List =" (i.e. an empty list) in the setting below.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'spammodifysubject' => 
  array (
    'external' => 'spammodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Spam Modify Subject',
    'desc' => ' If the message is spam, do you want to modify the subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This makes filtering in Outlook very easy.
 This can also be the filename of a ruleset.',
    'value' => ' start',
  ),
  'spamstars' => 
  array (
    'external' => 'spamscore',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Spam Score',
    'desc' => ' Do you want to include the "Spam Score" header. This shows 1 character
 (Spam Score Character) for every point of the SpamAssassin score. This
 makes it very easy for users to be able to filter their mail using
 whatever SpamAssassin threshold they want. For example, they just look
 for "sssss" for every message whose score is > 5, for example.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'spamscorenotstars' => 
  array (
    'external' => 'spamscorenumberinsteadofstars',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'SpamScore Number Instead Of Stars',
    'desc' => ' If this option is set to yes, you will get a spam-score header saying just
 the value of the spam score, instead of the row of characters representing
 the score.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'spliteximspool' => 
  array (
    'external' => 'spliteximspool',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Split Exim Spool',
    'desc' => ' Are you using Exim with split spool directories? If you don\'t understand
 this, the answer is probably "no". Refer to the Exim documentation for
 more information about split spool directories.',
    'value' => ' no',
  ),
  'sqldebug' => 
  array (
    'external' => 'sqldebug',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'SQL Debug',
    'desc' => ' If enabled; this will log lots of debugging output to STDERR and to syslog
 to help pinpoint any errors in the returned database values and will show
 exactly what is being processed as the data is being loaded.',
    'value' => ' no',
  ),
  'deliversilent' => 
  array (
    'external' => 'stilldeliversilentviruses',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Still Deliver Silent Viruses',
    'desc' => ' Still deliver (after cleaning) messages that contained viruses listed
 in the above option ("Silent Viruses") to the recipient?
 Setting this to "yes" is good when you are testing everything, and
 because it shows management that MailScanner is protecting them,
 but it is bad because they have to filter/delete all the incoming virus
 warnings.

 Note: Once you have deployed this into "production" use, you should set
 Note: this option to "no" so you don\'t bombard thousands of people with
 Note: useless messages they don\'t want!

 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'unpackole' => 
  array (
    'external' => 'unpackmicrosoftdocuments',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Unpack Microsoft Documents',
    'desc' => ' Do you want to unpack Microsoft "OLE" documents, such as *.doc, *.xls
 and *.ppt documents? This will extract any files which have been hidden
 by being embedded in these documents.
 There are one or two minor bugs in the third-party code that does the
 processing of these files, so it can cause MailScanner to hang in very
 rare cases.
 ClamAV has its own OLE unpacking code, so you can safely switch this off
 if you just rely on ClamAV for your virus-scanning. Note that this will,
 however, disabled all lfilename and filetype checking of embedded files.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'gsscanner' => 
  array (
    'external' => 'usecustomspamscanner',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Use Custom Spam Scanner',
    'desc' => ' Use the Custom Spam Scanner. This is code you will have to write yourself,
 a function called "GenericSpamScanner" stored in the file
 MailScanner/lib/MailScanner/CustomFunctions/GenericSpamScanner.pm
 It will be passed
  $IP      - the numeric IP address of the system on the remote end
             of the SMTP connections
  $From    - the address of the envelope sender of the message
  $To      - a perl reference to the envelope recipients of the message
  $Message - a perl reference to the list of line of the message
 A sample function is given in the correct file in the distribution.
 This sample function also includes code to show you how to make it run
 an external program to produce a spam score.
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
  'usedefaultswithmanyrecips' => 
  array (
    'external' => 'usedefaultruleswithmultiplerecipients',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Use Default Rules With Multiple Recipients',
    'desc' => ' When trying to work out the value of configuration parameters which are
 using a ruleset, this controls the behaviour when a rule is checking the
 "To:" addresses.
 If this option is set to "yes", then the following happens when checking
 the ruleset:
   a) 1 recipient. Same behaviour as normal.
   b) Several recipients, but all in the same domain (domain.com for example).
      The rules are checked for one that matches the string "*@domain.com".
   c) Several recipients, not all in the same domain.
      The rules are checked for one that matches the string "*@*".

 If this option is set to "no", then some rules will use the result they
 get from the first matching rule for any of the recipients of a message,
 so the exact value cannot be predicted for messages with more than 1
 recipient.

 This value *cannot* be the filename of a ruleset.',
    'value' => ' no',
  ),
  'usespamassassin' => 
  array (
    'external' => 'usespamassassin',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Use SpamAssassin',
    'desc' => ' Do you want to find spam using the "SpamAssassin" package?
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'strictphishing' => 
  array (
    'external' => 'usestricterphishingnet',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Use Stricter Phishing Net',
    'desc' => ' If this is set to yes, then most of the URL in a link must match the
 destination address it claims to take you to. This is the default as it is
 a much stronger test and is very hard to maliciously avoid.
 If this is set to no, then just the company name and country (and any
 names between the two, dependent on the specific country) must match.
 This is not as strict as it will not protect you against internal
 malicious sites based within the company being abused. For example, it would
 not find www.nasty.company-name.co.uk pretending to be
 www.nice.company-name.co.uk. But it will still detect most phishing attacks
 of the type www.nasty.co.jp versus www.nice.co.jp.
 Depending on the country code it knows how many levels of domain need to
 be checked.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'replacetnef' => 
  array (
    'external' => 'usetnefcontents',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '2',
    'values' => 
    array (
      2 => 'replace',
      1 => 'add',
      0 => 'no',
    ),
    'name' => 'Use TNEF Contents',
    'desc' => ' When the TNEF (winmail.dat) attachments are expanded, should the
 attachments contained in there be added to the list of attachments in
 the message?
 If you set this to "add" or "replace" then recipients of messages sent
 in "Outlook Rich Text Format" (TNEF) will be able to read the attachments
 if they are not using Microsoft Outlook.

 no      => Leave winmail.dat TNEF attachments alone.
 add     => Add the contents of winmail.dat as extra attachments, but also
            still include the winmail.dat file itself. This will result in
            TNEF messages being doubled in size.
 replace => Replace the winmail.dat TNEF attachment with the files it
            contains, and delete the original winmail.dat file itself.
            This means the message stays the same size, but is usable by
            non-Outlook recipients.

 This can also be the filename of a ruleset.',
    'value' => ' replace',
  ),
  'usewatermarking' => 
  array (
    'external' => 'usewatermarking',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Use Watermarking',
    'desc' => ' Do you want to use the watermarking features at all?
 Setting this to "no" will disable the whole of this section.',
    'value' => ' no',
  ),
  'virusmodifysubject' => 
  array (
    'external' => 'virusmodifysubject',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => 'start',
    'values' => 
    array (
      'end' => 'end',
      'start' => 'start',
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Virus Modify Subject',
    'desc' => ' If the message contained a virus, do you want to modify the subject line?
 This can be 1 of 4 values:
      no    = Do not modify the subject line, or
      start = Add text to the start of the subject line, or
      yes   = Add text to the start of the subject line, or
      end   = Add text to the end of the subject line.
 This makes filtering in Outlook very easy.
 This can also be the filename of a ruleset.',
    'value' => ' start',
  ),
  'virusscan' => 
  array (
    'external' => 'virusscanning',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Virus Scanning',
    'desc' => ' Do you want to scan email for viruses?
 A few people don\'t have a virus scanner licence and so want to disable
 all the virus scanning.
 If you use a ruleset for this setting, then the mail will be scanned if
 *any* of the rules match (except the default). That way unscanned mail
 never reaches a user who is having their mail virus-scanned.

 If you want to be able to switch scanning on/off for different users or
 different domains, set this to the filename of a ruleset.
 This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'bayeswait' => 
  array (
    'external' => 'waitduringbayesrebuild',
    'type' => 'yesno',
    'ruleset' => 'no',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Wait During Bayes Rebuild',
    'desc' => ' The Bayesian database rebuild and expiry may take a 2 or 3 minutes
 to complete. During this time you can either wait, or simply
 disable SpamAssassin checks until it has completed.',
    'value' => ' no',
  ),
  'warningisattachment' => 
  array (
    'external' => 'warningisattachment',
    'type' => 'yesno',
    'ruleset' => 'first',
    'default' => '1',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Warning Is Attachment',
    'desc' => ' When a virus or attachment is replaced by a plain-text warning,
 should the warning be in an attachment? If "no" then it will be
 placed in-line. This can also be the filename of a ruleset.',
    'value' => ' yes',
  ),
  'zipattachments' => 
  array (
    'external' => 'zipattachments',
    'type' => 'yesno',
    'ruleset' => 'all',
    'default' => '0',
    'values' => 
    array (
      1 => 'yes',
      0 => 'no',
    ),
    'name' => 'Zip Attachments',
    'desc' => ' Should the attachments be compressed and put into a single zip file?
 This can also be the filename of a ruleset.',
    'value' => ' no',
  ),
);
?>