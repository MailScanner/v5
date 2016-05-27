#
#   MailScanner - SMTP Email Processor
#   Copyright (C) 2002  Julian Field
#
#   $Id: ConfigDefs.pl 5062 2010-11-09 21:56:06Z sysjkf $
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

1;

__DATA__
########################################################################
#
# Go through the entire source code, checking wherever any variable is
# used. Ensure they are used in a way that matches their spec.
#
########################################################################

#
# Translation between Internal and External keyword names.
# This lets me use nice brief names internally, and set the
# config file options to names that mean something.
#
# Format:
#    Internal = External
#

[Translation,Translation]

AFilenameRules                  = ArchivesFilenameRules
AFiletypeRules                  = ArchivesFiletypeRules
aallowfilenames                 = ArchivesAllowFilenames
adenyfilemimetypes              = ArchivesDenyFileMIMETypes
adenyfiletypes                  = ArchivesDenyFiletypes
aallowfilemimetypes             = ArchivesAllowFileMIMETypes
aallowfiletypes                 = ArchivesAllowFiletypes
adenyfilenames                  = ArchivesDenyFilenames
addenvfrom			= AddEnvelopeFromHeader
addenvto			= AddEnvelopeToHeader
addmshmac			= AddWatermark
AllowObjectTags			= AllowObjectCodebaseTags
AllowExternal			= AllowExternalMessageBodies
allowmultsigs			= AllowMultipleHTMLSignatures
AllowPartial			= AllowPartialMessages
allowpasszips			= AllowPasswordProtectedArchives
AllowWebBugTags			= AllowWebBugs
assumeisdir			= MissingMailArchiveIs
attachimage			= AttachImageToSignature
attachimagename			= SignatureImageFilename
attachimageinternalname		= SignatureImageImgFilename
attachimagetohtmlonly		= AttachImageToHTMLMessageOnly
AttachmentCharset		= AttachmentEncodingCharset
AttachZipMinSize		= AttachmentsMinTotalSizeToZip
AttachZipName			= AttachmentsZipFilename
AttachZipIgnore			= AttachmentExtensionsNotToZip
bayesrebuild			= RebuildBayesEvery
bayeswait			= WaitDuringBayesRebuild
blacklistedishigh		= definitespamishighscoring
BlockEncrypted			= BlockEncryptedMessages
BlockUnencrypted		= BlockUnencryptedMessages
cachetiming			= SpamAssassinCacheTimings
checkmshmac			= CheckWatermarksWithNoSender
checkmshmacskip			= CheckWatermarksToSkipSpamChecks
checkppafilenames		= CheckFilenamesInPasswordProtectedArchives
CheckSAIfOnSpamList		= checkspamassassinifonspamlist
children			= maxchildren
clamavmaxreclevel		= clamavmodulemaximumrecursionlevel
clamavmaxfiles			= clamavmodulemaximumfiles
clamavmaxfilesize		= clamavmodulemaximumfilesize
clamavmaxratio			= clamavmodulemaximumcompressionratio
clamavspam			= ClamAVFullMessageScan
clamwatchfiles			= monitorsforclamavupdates
cleanheader			= cleanheadervalue
contentmodifysubject		= contentmodifysubject
contentsubjecttext		= contentsubjecttext
criticalqueuesize		= maxnormalqueuesize
dangerscan			= dangerouscontentscanning
deletedcontentmessage		= deletedbadcontentmessagereport
deletedfilenamemessage		= deletedbadfilenamemessagereport
deletedsizemessage		= deletedsizemessagereport
deletedvirusmessage		= deletedvirusmessagereport
deliverdisinfected		= deliverdisinfectedfiles
deliversilent			= stilldeliversilentviruses
dirtyheader			= infectedheadervalue
disarmmodifysubject		= disarmedmodifysubject
disarmsubjecttext		= disarmedsubjecttext
disinfectedheader		= disinfectedheadervalue
disinfectedreporttext		= disinfectedreport
envfromheader			= EnvelopeFromHeader
envtoheader			= EnvelopeToHeader
findphishing			= FindPhishingFraud
fprotd6port			= FpscandPort
getipfromheader			= ReadIPAddressFromReceivedHeader
gsscanner			= UseCustomSpamScanner
gstimeout			= CustomSpamScannerTimeout
gstimeoutlen			= CustomSpamScannertimeouthistory
hamactions                      = nonspamactions
hideworkdir			= hideincomingworkdir
hideworkdirinnotice		= hideincomingworkdirinnotices
highrbls                        = spamliststoreachhighscore
highscorespamactions		= highscoringspamactions
highscoremcpactions		= highscoringmcpactions
highmcpmodifysubject		= highscoringmcpmodifysubject
highspammodifysubject		= highscoringspammodifysubject
highmcpsubjecttext		= highscoringmcpsubjecttext
highspamsubjecttext		= highscoringspamsubjecttext
htmltotext			= converthtmltotext
includespamheader		= alwaysincludespamassassinreport
includemcpheader		= alwaysincludemcpreport
infoheader			= informationheader
infovalue			= informationheadervalue
insistpasszips			= ArchivesMustBePasswordProtected
inlinehtmlsig			= inlinehtmlsignature
inlinehtmlwarning		= inlinehtmlwarning
inlinetextsig			= inlinetextsignature
inlinetextwarning		= inlinetextwarning
inqueuedir			= incomingqueuedir
ipverheader			= ipprotocolversionheader
isareply			= dontsignhtmlifheadersexist
keepspamarchiveclean		= keepspamandmcparchiveclean
lastafterbatch			= alwayslookeduplastafterbatch
lastlookup			= alwayslookeduplast
listsascores                    = includescoresinspamassassinreport
logdelivery			= logdeliveryandnondelivery
loghtmltags			= logdangeroushtmltags
logfacility			= syslogfacility
logsaactions			= logspamassassinruleactions
logsock				= syslogsockettype
lookforuu			= finduuencodedfiles
maxattachmentsize		= maximumattachmentsize
maxdirtybytes			= maxunsafebytesperscan
maxdirtymessages		= maxunsafemessagesperscan
maxgssize			= maxcustomspamscannersize
maxgstimeouts			= maxcustomspamscannertimeouts
maxmessagesize			= maximummessagesize
maxparts			= maximumattachmentspermessage
maxunscannedbytes		= maxunscannedbytesperscan
maxunscannedmessages		= maxunscannedmessagesperscan
maxzipdepth			= maximumarchivedepth
minattachmentsize		= minimumattachmentsize
minstars			= minimumstarsifonspamlist
mshmac				= WatermarkSecret
mshmacheader			= WatermarkHeader
mshmacnull			= TreatInvalidWatermarksWithNoSenderAsSpam
mshmacvalid			= WatermarkLifetime
namemodifysubject		= filenamemodifysubject
namesubjecttext			= filenamesubjecttext
newheadersattop			= placenewheadersattopofmessage
noisyviruses			= nonforgingviruses
normalrbls                      = spamliststobespam
nosenderprecedence		= nevernotifysendersofprecedence
noticefullheaders		= noticesincludefullheaders
noticerecipient			= noticesto
phishingblacklist		= phishingbadsitesfile
phishinghighlight		= highlightphishingfraud
phishingnumbers			= alsofindnumericphishing
phishingsubjecttag		= phishingsubjecttext
phishingwhitelist		= phishingsafesitesfile
outqueuedir			= outgoingqueuedir
procdbattempts			= maximumprocessingattempts
procdbname			= processingattemptsdatabase
quarantinesilent		= quarantinesilentviruses
quarantineuser			= quarantineuser
quarantinegroup			= quarantinegroup
quarantineperms			= quarantinepermissions
rbltimeoutlen			= spamlisttimeoutshistory
usesacache			= cachespamassassinresults
saactions			= spamassassinruleactions
sadecodebins			= IncludeBinaryAttachmentsInSpamAssassin
satimeoutlen			= spamassassintimeoutshistory
removeheaders			= removetheseheaders
replacetnef			= usetnefcontents
reqspamassassinscore		= requiredspamassassinscore
sacache				= spamassassincachedatabasefile
saviwatchfiles                  = monitorsforsophosupdates
scanmail			= scanmessages
scoreformat			= spamscorenumberformat
secondlevellist                 = countrysubdomainslist
sendercontentreport		= senderbadcontentreport
# JKF 19/12/2007 senderpasswordreport		= senderbadpasswordprotectedarchivereport
senderfilenamereport		= senderbadfilenamereport
senderrblspamreport		= senderspamlistreport
sendersaspamreport		= senderspamassassinreport
sendersamcpreport		= sendermcpreport
sendersizereport		= sendersizereport
senderbothspamreport		= senderspamreport
showscanner			= includescannernameinreports
signalreadyscanned		= signmessagesalreadyprocessed
signunscannedmessages		= markunscannedmessages
sophosallowederrors		= allowedsophoserrormessages
sophoside			= sophosidedir
sophoslib			= sophoslibdir
spamblacklist			= isdefinitelyspam
spamdetail			= detailedspamreport
mcpmodifysubject		= mcpmodifysubject
sizemodifysubject		= sizemodifysubject
sizesubjecttext			= sizesubjecttext
spamassassintempdir		= spamassassintemporarydir
spaminfected			= VirusNamesWhichAreSpam
spammodifysubject		= spammodifysubject
spamscorenotstars		= spamscorenumberinsteadofstars
spamstars			= spamscore
spamstarscharacter		= spamscorecharacter
spamstarsheader			= spamscoreheader
spamwhitelist			= isdefinitelynotspam
storedcontentmessage		= storedbadcontentmessagereport
storedfilenamemessage		= storedbadfilenamemessagereport
storedsizemessage		= storedsizemessagereport
storedvirusmessage		= storedvirusmessagereport
storeentireasdfqf		= quarantinewholemessagesasqueuefiles
strictphishing                  = usestricterphishingnet
stripdangeroustags		= convertdangeroushtmltotext
mcpblacklist			= isdefinitelymcp
mcpblacklistedishigh		= definitemcpishighscoring
mcpdetail			= detailedmcpreport
mcplistsascores			= includescoresinmcpreport
mcpreqspamassassinscore		= mcprequiredspamassassinscore
mcpwhitelist			= isdefinitelynotmcp
syntaxcheck			= automaticsyntaxcheck
unpackole			= UnpackMicrosoftDocuments
unscannedheader			= unscannedheadervalue
usedefaultswithmanyrecips       = usedefaultruleswithmultiplerecipients
tagphishingsubject		= phishingmodifysubject
unzipmaxmembers			= UnzipMaximumFilesPerArchive
unzipmaxsize			= UnzipMaximumFileSize
unzipmembers			= UnzipFilenames
unzipmimetype			= UnzipMimeType
#virusbeforespammcp		= virusscanningbeforespamormcp
virusmodifysubject		= virusmodifysubject
virusscan			= virusscanning
warnsenders			= notifysenders
warnvirussenders		= notifysendersofviruses
warnnamesenders			= notifysendersofblockedfilenamesorfiletypes
warnsizesenders                 = notifysendersofblockedsizeattachments
warnothersenders		= notifysendersofotherblockedcontent
# JKF 19/12/2007 warnpasswordsenders		= notifysendersofblockedpasswordprotectedarchives
webbugurl			= webbugreplacement
webbugblacklist			= knownwebbugservers
webbugwhitelist			= ignoredwebbugfilenames
whitelistmaxrecips		= ignorespamwhitelistifrecipientsexceed
workuser			= incomingworkuser
workgroup			= incomingworkgroup
workperms			= incomingworkpermissions


#
# Simple variables which can only have a single value, no rules allowed.
#

# These can be any of the words given, with the corresponding value stored.
# Format is	<Keyword Name>
#		<Default internal value>
#	      [ <External name> <Internal store value ] ...
#
[Simple,YesNo]
bayeswait		0	no	0	yes	1
clamavspam		0	no	0	yes	1
debug			0	no	0	yes	1
debugspamassassin	0	no	0	yes	1
deliverinbackground	1	no	0	yes	1
logdelivery		0	no	0	yes	1
lognonspam		0	no	0	yes	1
logsaactions		0	no	0	yes	1
logsilentviruses	0	no	0	yes	1
logspam			0	no	0	yes	1
logspeed		0	no	0	yes	1
logmcp			0	no	0	yes	1
expandtnef		1	no	0	yes	1
runinforeground		0	no	0	yes	1
showscanner		1	no	0	yes	1
spamassassinautowhitelist 1	no	0	yes	1
spliteximspool		0	no	0	yes	1
storeentireasdfqf	0	no	0	yes	1
syntaxcheck		1	no	0	yes	1
usedefaultswithmanyrecips	0	no	0	yes	1
#virusbeforespammcp	0	no	0	yes	1
SQLDebug		0	no	0	yes	1

# These should be checked for dir existence
[Simple,Dir]
incomingworkdir		/var/spool/MailScanner/incoming
lockfiledir		/var/lock/subsys

# Check the first word of these for file existence
[Simple,File]
PhishingWhitelist	/etc/MailScanner/phishing.safe.sites.conf
PhishingBlacklist	/etc/MailScanner/phishing.bad.sites.conf
pidfile			/var/run/MailScanner.pid
SecondLevelList         /etc/MailScanner/country.domains.conf
spamassassinprefsfile	/etc/MailScanner/spamassassin.conf
SpamListDefinitions	/etc/MailScanner/spam.lists.conf
mcpspamassassinprefsfile /etc/MailScanner/mcp/mcp.spamassassin.conf
VirusScannerDefinitions	/etc/MailScanner/virus.scanners.conf

# Check these to ensure they are just numbers
[Simple,Number]
AntiwordTimeout			50
BayesRebuild			0
Children			5
clamavmaxreclevel               8
clamavmaxfiles                  1000
clamavmaxfilesize               10000000
clamavmaxratio                  250
ClamdPort 3310
CriticalQueueSize		800
FileTimeout			20
fprotd6port			10200
GSTimeout			20
GSTimeoutLen			20
GunzipTimeout			50
MaxUnscannedBytes		100000000
MaxUnscannedMessages		30
MaxDirtyBytes			50000000
MaxDirtyMessages		30
MaxGSSize			20000
MaxGSTimeouts			10
MaxSpamAssassinTimeouts		10
ProcDBAttempts			6
QueueScanInterval		6
RBLTimeoutLen			10
RestartEvery			14400
SATimeoutLen			30
SpamListTimeout			10
SpamAssassinTimeout		75
VirusScannerTimeout		300
MCPMaxSpamAssassinTimeouts	20
MCPSpamAssassinTimeout		10
TNEFTimeout			120
UnrarTimeout			50
WhitelistMaxRecips		20
# For Qmail users
qmailhashdirectorynumber	23
qmailintdhashnumber		1

# These are all the other strings I haven't categorised.
# inqueuedir is here as it can be a glob (if it contains a * or a ?) or a
# filename containing a list of directories.
[Simple,Other]
cachetiming		1800,300,10800,172800,600
ClamWatchFiles		/var/lib/clamav/*.cvd
CustomFunctionsDir	/usr/share/MailScanner/perl/custom
FileCommand		/usr/bin/file
FirstCheck		mcp
getipfromheader		0
GunzipCommand		/bin/gunzip
inqueuedir		/var/spool/mqueue.in
LDAPbase
LDAPserver
LDAPsite
# LockType *must not* have a static default
LockType
LogFacility		mail
LogSock		
MailScannerVersionNumber	1.0.0
MaxSpamAssassinSize		30000
MinimumCodeStatus	supported
MTA			sendmail
ProcDBName		/var/spool/MailScanner/incoming/Processing.db
QuarantineUser
QuarantineGroup
QuarantinePerms		0660
RunAsUser		0
RunAsGroup		0
SACache			/var/spool/MailScanner/incoming/SpamAssassin.cache.db
SAVIWatchFiles		/opt/sophos-av/lib/sav/*.ide
SophosAllowedErrors	
sophoside		
sophoslib		
spamassassintempdir	/var/spool/MailScanner/incoming/SpamAssassin-Temp
SpamAssassinUserStateDir
SpamAssassinSiteRulesDir
SpamAssassinLocalRulesDir	
SpamAssassinLocalStateDir	
SpamAssassinDefaultRulesDir	
SpamAssassinInstallPrefix	
SpamInfected		Sane*UNOFFICIAL
SpamStarsCharacter	s
MCPMaxSpamAssassinSize		100000
MCPSpamAssassinUserStateDir
MCPSpamAssassinLocalRulesDir	/etc/MailScanner/mcp
MCPSpamAssassinDefaultRulesDir	/etc/MailScanner/mcp
MCPSpamAssassinInstallPrefix	/etc/MailScanner/mcp
TNEFExpander		/usr/bin/tnef --maxsize=100000000
UnrarCommand		/usr/bin/unrar
VirusScanners		auto  # Space-separated list
WorkUser
WorkGroup
WorkPerms		0660
DBDSN
DBUsername
DBPassword
SQLSerialNumber
SQLQuickPeek
SQLConfig
SQLRuleset
SQLSpamAssassinConfig

#
# These variables match on any rule matching From:, else anything for To:
#

[First,YesNo]
AddTextOfDoc		0	no	0	yes	1
AllowExternal		0	no	0	yes	1
AllowPartial		0	no	0	yes	1
ArchivePublicKeys	0	no	0	yes	1
blacklistedishigh	0	no	0	yes	1
bouncemcpasattachment	0	no	0	yes	1
bouncespamasattachment	0	no	0	yes	1
CheckSAIfOnSpamList	1	no	0	yes	1
ContentModifySubject	start	no	0	yes	1	start	start	end	end
DeliverDisinfected	0	no	0	yes	1
DeliverSilent		0	no	0	yes	1
deliverunparsabletnef	0	no	0	yes	1
deliverymethod		batch	batch	batch	queue	queue
DisarmModifySubject	start	no	0	yes	1	start	start	end	end
EnableSpamBounce	0	no	0	yes	1
findarchivesbycontent	1	no	0	yes	1
gsscanner		0	no	0	yes	1
HideWorkDir		1	no	0	yes	1
HideWorkDirInNotice	0	no	0	yes	1
HighMCPModifySubject	start	no	0	yes	1	start	start	end	end
HighSpamModifySubject	start	no	0	yes	1	start	start	end	end
IncludeSpamHeader	0	no	0	yes	1
IncludeMCPHeader	0	no	0	yes	1
KeepSpamArchiveClean	0	no	0	yes	1
LastAfterBatch		0	no	0	yes	1
LastLookup		0	no	0	yes	1
ListSAScores		1	no	0	yes	1
#LoadSpamAssassin	0	no	0	yes	1
LogHTMLTags		0	no	0	yes	1
LogPermittedFilenames	0	no	0	yes	1
LogPermittedFiletypes	0	no	0	yes	1
LogPermittedFileMimetypes	0	no	0	yes	1
LookForUU		0	no	0	yes	1
MultipleHeaders		append	append	append	replace	replace	add	add
NameModifySubject	start	no	0	yes	1	start	start	end	end
NoticeFullHeaders	1	no	0	yes	1
RejectMessage		0	no	0	yes	1
ScannedModifySubject	0	no	0	yes	1	start	start	end	end
SendNotices		1	no	0	yes	1
SignAlreadyScanned	0	no	0	yes	1
SignCleanMessages	1	no	0	yes	1
SignUnscannedMessages	1	no	0	yes	1
SizeModifySubject	start	no	0	yes	1	start	start	end	end
SpamBlacklist		0	no	0	yes	1
SpamDetail		1	no	0	yes	1
SpamChecks		1	no	0	yes	1
MCPModifySubject	start	no	0	yes	1	start	start	end	end
SpamModifySubject	start	no	0	yes	1	start	start	end	end
SpamScoreNotStars	0	no	0	yes	1
SpamWhitelist		0	no	0	yes	1
StripDangerousTags	0	no	0	yes	1
MCPBlacklist		0	no	0	yes	1
MCPblacklistedishigh	0	no	0	yes	1
MCPChecks		0	no	0	yes	1
MCPDetail		1	no	0	yes	1
MCPListSAScores		0	no	0	yes	1
MCPWhitelist		0	no	0	yes	1
UnpackOle		1	no	0	yes	1
UseSACache		1	no	0	yes	1
VirusModifySubject	start	no	0	yes	1	start	start	end	end
warningisattachment	1	no	0	yes	1
WarnSenders		1	no	0	yes	1
WarnVirusSenders	0	no	0	yes	1
WarnNameSenders		1	no	0	yes	1
WarnSizeSenders		0	no	0	yes	1
WarnOtherSenders	1	no	0	yes	1
# JKF 19/12/2007 WarnPasswordSenders    1       no      0       yes     1

[First,File]
DeletedContentMessage	/usr/share/MailScanner/reports/en/deleted.content.message.txt
DeletedFilenameMessage	/usr/share/MailScanner/reports/en/deleted.filename.message.txt
DeletedSizeMessage	/usr/share/MailScanner/reports/en/deleted.size.message.txt
DeletedVirusMessage	/usr/share/MailScanner/reports/en/deleted.virus.message.txt
DisinfectedReportText	/usr/share/MailScanner/reports/en/disinfected.report.txt
inlinehtmlsig		/usr/share/MailScanner/reports/en/inline.sig.html
inlinehtmlwarning	/usr/share/MailScanner/reports/en/inline.warning.html
inlinespamwarning	/usr/share/MailScanner/reports/en/inline.spam.warning.txt
inlinetextsig		/usr/share/MailScanner/reports/en/inline.sig.txt
inlinetextwarning	/usr/share/MailScanner/reports/en/inline.warning.txt
languagestrings		
recipientmcpreport	/usr/share/MailScanner/reports/en/recipient.mcp.report.txt
recipientspamreport	/usr/share/MailScanner/reports/en/recipient.spam.report.txt
rejectionreport		/usr/share/MailScanner/reports/en/message.rejection.report.txt
sendercontentreport 	/usr/share/MailScanner/reports/en/sender.content.report.txt
# JKF 19/12/2007 senderpasswordreport   /usr/share/MailScanner/reports/en/sender.password.report.txt
sendererrorreport 	/usr/share/MailScanner/reports/en/sender.error.report.txt
senderfilenamereport	/usr/share/MailScanner/reports/en/sender.filename.report.txt
SenderRBLSpamReport	/usr/share/MailScanner/reports/en/sender.spam.rbl.report.txt
SenderSASpamReport	/usr/share/MailScanner/reports/en/sender.spam.sa.report.txt
SenderSAMCPReport	/usr/share/MailScanner/reports/en/sender.mcp.report.txt
SenderSizeReport	/usr/share/MailScanner/reports/en/sender.size.report.txt
SenderBothSpamReport	/usr/share/MailScanner/reports/en/sender.spam.report.txt
sendervirusreport 	/usr/share/MailScanner/reports/en/sender.virus.report.txt
StoredContentMessage	/usr/share/MailScanner/reports/en/stored.content.message.txt
StoredFilenameMessage	/usr/share/MailScanner/reports/en/stored.filename.message.txt
StoredSizeMessage	/usr/share/MailScanner/reports/en/stored.size.message.txt
StoredVirusMessage	/usr/share/MailScanner/reports/en/stored.virus.message.txt

[First,Command]
Sendmail		/usr/sbin/sendmail

[First,Dir]
OutQueueDir			/var/spool/mqueue
PublicKeyArchiveDir		#/var/spool/MailScanner/keys
quarantinedir			/var/spool/MailScanner/quarantine

[First,Number]
AttachZipMinSize		100000
HighRBLs			3
HighSpamAssassinScore		10
MaxAttachmentSize		-1
MaxMessageSize			0
MaxParts			200
MaxSpamCheckSize		150000
MaxSpamListTimeouts		7
MaxZipDepth			2
MCPErrorScore			1
MCPHighSpamAssassinScore	10
MCPReqSpamAssassinScore		1
MinAttachmentSize		-1
MinStars			0
mshmacvalid			604800
NormalRBLs			1
ReqSpamAssassinScore		6
unzipmaxmembers			0
unzipmaxsize			50000

[First,Other]
Antiword			/usr/bin/antiword -f
ArchivesAre			zip rar ole
AttachmentCharset		ISO-8859-1
attachimageinternalname
attachimagename
AttachmentWarningFilename	VirusWarning.txt
AttachZipName			MessageAttachments.zip
cleanheader			Found to be clean
ContentSubjectText		{Dangerous Content?}
DefaultRenamePattern		__FILENAME__.disarmed
dirtyheader			Found to be infected
DisarmSubjectText		{Disarmed}
DisinfectedHeader		Disinfected
EnvFromHeader			X-MailScanner-Envelope-From:
EnvToHeader			X-MailScanner-Envelope-To:
HighMCPSubjectText		{MCP?}
HighSpamSubjectText		{Spam?}
Hostname			the MailScanner
IDHeader			X-MailScanner-ID:
InfoHeader			
InfoValue			Please contact an administrator for more information
IPVerHeader			
LocalPostmaster			postmaster
MailHeader			X-MailScanner:
mshmac				Watermark-secret
mshmacheader			MailScanner-NULL-Check:
NameSubjectText			{Filename?}
NoticesFrom			MailScanner
NoticeSignature			-- \nMailScanner\nEmail Processor\nwww.mailscanner.info
PhishingSubjectTag		{Fraud?}
ScannedSubjectText		{Scanned}
ScoreFormat			%d
Sendmail2			/usr/sbin/sendmail
SpamHeader			X-MailScanner-SpamCheck:
SpamList
SpamVirusHeader			X-MailScanner-SpamVirus-Report:
MCPSubjectText			{MCP?}
SpamSubjectText			{Spam?}
SpamStarsHeader			X-MailScanner-SpamScore:
MCPHeader			X-MailScanner-MCPCheck:
UnscannedHeader			Not scanned: please contact your administrator for details
VirusSubjectText		{Virus?}
WebBugURL			https://s3.amazonaws.com/msv5/images/spacer.gif
HamActions		deliver header "X-Spam-Status: No"
SpamActions		deliver header "X-Spam-Status: Yes"
HighScoreSpamActions	deliver header "X-Spam-Status: Yes"
NonMCPActions		deliver
MCPActions		deliver
HighScoreMCPActions	deliver
SizeSubjectText		{Size}
unzipmembers		*.txt *.ini *.log *.csv
unzipmimetype		text/plain

[All,YesNo]
AddEnvFrom		1	no	0	yes	1
AddEnvTo		0	no	0	yes	1
addmshmac		1	no	0	yes	1
AllowIFrameTags		convert	no	0	yes	1	disarm	convert
AllowFormTags		convert	no	0	yes	1	disarm	convert
allowmultsigs		0	no	0	yes	1
AllowObjectTags		convert	no	0	yes	1	disarm	convert
AllowScriptTags		convert	no	0	yes	1	disarm	convert
AllowPassZips		0	no	0	yes	1
AllowWebBugTags		convert	no	0	yes	1	disarm	convert
assumeisdir		1	file	0	directory	1
attachimage		0	no	0	yes	1
attachimagetohtmlonly	1	no	0	yes	1
BlockEncrypted		0	no	0	yes	1
BlockUnencrypted	0	no	0	yes	1
checkppafilenames	1	no	0	yes	1
checkmshmac		1	no	0	yes	1
checkmshmacskip		1	no	0	yes	1
ClamdUseThreads		0	no	0	yes	1
DangerScan		1	no	0	yes	1
DeliverCleanedMessages	1	no	0	yes	1
FindPhishing		1	no	0	yes	1
markinfectedmessages	1	no	0	yes	1
PhishingHighlight	1	no	0	yes	1
HtmlToText		0	no	0	yes	1
InsistPassZips		0	no	0	yes	1
NewHeadersAtTop		0	no	0	yes	1
PhishingNumbers		1	no	0	yes	1
QuarantineInfections	1	no	0	yes	1
QuarantineModifiedBody	0	no	0	yes	1
QuarantineSilent	0	no	0	yes	1
QuarantineWholeMessage	0	no	0	yes	1
ReplaceTNEF		2	no	0	add	1	replace	2
sadecodebins		0	no	0	yes	1
ScanMail		1	no	0	yes	1	virus	2
SpamStars		1	no	0	yes	1
StrictPhishing          1       no      0       yes     1
TagPhishingSubject	0	no	0 	yes	1	start	start	end	end
MCPUseSpamAssassin	1	no	0	yes	1
UseSpamAssassin		1	no	0	yes	1
UseWatermarking		1	no	0	yes	1
VirusScan		1	no	0	yes	1
ZipAttachments		0	no	0	yes	1

[All,File]
#FilenameRules		/etc/MailScanner/filename.rules.conf

[All,Other]
# This is the other stuff that came up in the search that I haven't
# figured out what to do with yet...
aallowfilenames
adenyfilemimetypes
adenyfiletypes
aallowfilemimetypes
aallowfiletypes
adenyfilenames
afilenamerules
afiletyperules
ArchiveMail
AttachZipIgnore			.zip .rar .gz .tgz .mpg .mpe .mpeg .mp3 .rpm
ClamdLockFile
ClamdSocket 127.0.0.1
FilenameRules		
FiletypeRules		
isareply
mshmacnull			spam
NoisyViruses			Joke/ OF97/ WM97/ W97M/ eicar
NoSenderPrecedence		list bulk
NoticeRecipient			postmaster
RemoveHeaders			X-Mozilla-Status: X-Mozilla-Status2:
SilentViruses			HTML-IFrame All-Viruses
SpamDomainList			
webbugblacklist
webbugwhitelist
allowfilenames
denyfilemimetypes
denyfiletypes
allowfilemimetypes
allowfiletypes
denyfilenames
saactions

