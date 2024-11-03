GOAT
====

`GOAT` is a long-term tournament organisation assistant,
currently targeted at Go tournaments.

It'll help you manage registrations, pairing, sending
reminder e-mails, collecting and processing results.


```
% perldoc goat
```

should answer most of your questions. See below for install
tips and additionnal support scripts.

LICENSE
=======

Copyright (C) 2006-2018  Yves Rutschle

This program is free software; you can redistribute it
and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE.  See the GNU General Public License for more
details.

The full text for the General Public License is here:
http://www.gnu.org/licenses/gpl.html


HOW TO INSTALL
==============

Install the dependencies:

```
        apt-get install libtime-parsedate-perl libemail-filter-perl libemail-valid-perl libdatetime-perl libdatetime-locale-perl libhtml-table-perl libdatetime-timezone-perl libdevel-cover-perl libtemplate-perl libmime-tools-perl libemail-reply-perl libemail-sender-perl libyaml-perl libdata-ical-perl libdatetime-format-ical-perl libdata-uuid-perl libparse-recdescent-perl libcgi-pm-perl libmail-imapclient-perl libtext-multimarkdown-perl
        cpan Algorithm::Pair::Best2
```

The test suite will probably require the `en_US.UTF-8`
locale to be installed, which is done with `dpkg-reconfigure locales`.


Copy the Goat files to the install directory (e.g.
`/opt/goat`). Add that directory to $PATH (so the system finds
the various scripts) and to $PERL5LIB (so the scripts find
the libraries).

Then create a work directory. Copy the installation's
`example.cfg` as `goat.cfg` and edit that file (at least the
directories).  If you plan to run several tournaments in the
same directory, you can do that by creating several config
files; just make sure to specify one `tournament_file` per
tournament in the configuration; then you can specify which
tournament to work on with the `--file` option which is
available on all command line programs. If you don't specify
any, the programs will pick `goat.cfg` as default: if you're
running several tournaments, it's a good idea to have no
file called that so you always have to specify which
tournament to work on.

Add the install directory to $PATH and to $PERL5LIB so the
system finds the binaries, and the binaries find the
libraries, e.g.:

```
export PATH=$PATH:/opt/goat
export PERL5LIB=/opt/goat
```

Goat is called in 2 ways: on receiving a mail that contains
a command; and regularly, to send out reminders.

Mail reception
==============

There are two strategies to get mail to Goat: On Unix, get
the MTA to deliver directly to a Goat local user; or in
general (Unix or others), get Goat to monitor an IMAP
mailbox.

Local forward file
------------------

This method will only work on a Unix system that receives
the e-mail directly, where the local MTA (Exim, Postfix,
...) is set up to use local `.forward` files.

Create a `goat` user account, then create a `.forward`
file that contains:

```
| /home/goat/frontend
```

Then we create the frontend script that will set up
environment variables for Goat upon reception of an e-mail.

The `frontend` script will set up two environment variables:
`PATH` and `PERL5LIB`, then call `mail_in`. 

E.g.: my `/home/goat/frontend`:

```
#! /bin/sh

export PATH=$PATH:/opt/goat
export PERL5LIB=/opt/goat

mail_in
```

(and set it as executable)

Now all e-mail received by the goat user is processed by
goat.

Usually in this setting Goat can send e-mail using the
available local `sendmail` command so you don't need to set
up SMTP.

IMAP Client
-----------

The other way to receive e-mail is by setting up a standard
IMAP account. This incurrs a wee overhead compared to the
previous solution, but should let you run Goat with almost
any e-mail provider including Gmail.

Set up `PATH` and `PERL5LIB` environment variables as above,
before starting `imap_frontend` so probably in your
`.bashrc`.

Set up the IMAP and SMTP settings in the `goat.cfg` configuration file,
then simply run:

```
imap_frontend
```

This will monitor the mailbox, and whenever a new mail
arrives, it'll feed it to `mail_in` which processes Goat
commands.

If you don't want to have a process running all the time,
you can also run it regularly in a crontab and request to
exit after one poll:

```
PATH=$PATH:/opt/goat
PERL5LIB=/opt/goat
0/15 * * *      imap_frontend --once
```

This will check e-mail every 15 minutes.

Usually if you're receiving e-mail through IMAP, you also
need to send e-mail through the corresponding SMTP server,
so you'll need to set up the corresponding setting in
`goat.cfg`.


Crontab
=======

We also need to call Goat regularly to send out reminders.
Add a crontab entry for the goat user:

```
PATH=$PATH:/opt/goat
PERL5LIB=/opt/goat
0 0 * * *       goat >> /var/log/goat/cron
```

Now goat will run once a day to send out reminders if
needed. 

Other commands
==============

You can manage users with the `gplayer` script.  You can
use Goat's built-in pairing algorithm using the `pair`
script (all these scripts are self-documented: 
```
<script> --help
```
 will hopefully give you all the information you
need.)

To create a single game, use `add_game`.
To remove a single game, use `del_game`.

In general all these only apply to the current round.

