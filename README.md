![Build](https://github.com/MailScanner/v5/workflows/Build/badge.svg?branch=master)
![Version](https://img.shields.io/github/v/release/MailScanner/v5)
![License](https://img.shields.io/github/license/MailScanner/v5)
![Bugs](https://img.shields.io/github/issues/MailScanner/v5/bug?color=red)
![Enhancements](https://img.shields.io/github/issues/MailScanner/v5/enhancement?color=blue)
![Questions](https://img.shields.io/github/issues/MailScanner/v5/question?color=green)

# Welcome to MailScanner!

March 03, 2023

MailScanner Team <https://www.mailscanner.info>

MailScanner is an open source email gateway that processes email for
spam, viruses, phishing, and other malicious content. MailScanner 
leverages other open source software such as ClamAV and 
Spamassassin. MailScanner will run on any NIX platform and includes
install packages for popular distributions such as Redhat, Debian, and
SUSE in addition to any generic NIX package.

Info:       https://www.mailscanner.info

Release:    https://www.mailscanner.info/downloads

Github:     https://github.com/MailScanner/v5

Manual:     https://s3.amazonaws.com/msv5/docs/ms-admin-guide.pdf

Milter:     https://github.com/MailScanner/v5/blob/master/doc/MailScanner%20Milter%20Guide.pdf

Support:    http://lists.mailscanner.info/mailman/listinfo/mailscanner

## Install/Update

Redhat-based
```
           rpm -ivh|-Uvh MailScanner-5.x.x-x.rhel.noarch.rpm
           /usr/sbin/ms-configure [--update]
```
Debian-based
```
           dpkg -i MailScanner-5.x.x.x-x.noarch.deb
           /usr/sbin/ms-configure [--update]
```
SuSE-based
```
           rpm -ivh|-Uvh MailScanner-5.x.x.x-x.suse.noarch.rpm
           /usr/sbin/ms-configure [--update]
```
Other *nix
```
           tar -xvzf MailScanner-5.x.x-x.nix.tar.gz
           ./install.sh
```

## MTA Guides:

  sendmail - https://www.mailscanner.info/sendmail
  
  postfix  - https://www.mailscanner.info/postfix
  
  exim     - https://www.mailscanner.info/exim


## Setup:

  Edit /etc/MailScanner/defaults and set options
  
  Edit /etc/MailScanner/MailScanner.conf and set options
  
  service mailscanner start


## NIX:

For generic NIX systems, create a symlink for controlling the start/stop/restart
of the program to scripts in:

  /usr/lib/MailScanner/init, or
  /usr/lib/MailScanner/systemd
  
  * This is not required for RHEL, CentOS, Debian, Ubuntu, SUSE
  * Use appropriate package install for these instead of this one

## File Locations:

  /etc/MailScanner
  
  /usr/share/MailScanner
  
  /usr/lib/MailScanner
