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
        apt-get install libtime-modules-perl libemail-filter-perl libemail-valid-perl libdatetime-perl libdatetime-locale-perl libhtml-table-perl libdatetime-timezone-perl libdevel-cover-perl libtemplate-perl libmime-tools-perl libemail-reply-perl libemail-sender-perl libyaml-perl libdata-ical-perl libdatetime-format-ical-perl libdata-uuid-perl libparse-recdescent-perl libcgi-pm-perl libmail-imapclient-perl
        cpan Algorithm::Pair::Best2
        cpan Games::Go::SGF
```

Check out `GoatConfig.pm` for configuration options.

Goat is called in 2 ways: on receiving a mail that contains
a command; and regularly, to send out reminders.

Mail reception
==============

There are two strategies to get mail to Goat: On Unix, get
the MTA to deliver directly to a Goat local user; or in
general, get Goat to monitor an IMAP mailbox.

Local forward file
------------------

This method will only work on a Unix system that receives
the e-mail directly, where the local MTA (Exim, Postfix,
...) is set up to use local `.forward` files.

Create a `goat` user account. Copy all the files of this
archive to the home directory of the 'goat' user, for
example in a `goat` directory, then create a `.forward`
file that contains:

```
| /home/goat/frontend
```

Then we create the frontend script that will set up
environment variables for Goat upon reception of an e-mail.

The 'frontend' script will set up two environment variables:
`GOAT_DIR`, which should contain the path to the Goat code
`WORK_DIR`, which contains the path to the work files
(tournament file, html exports etc), then call
`$GOAT_DIR/mail_in`. 

E.g.: my `/home/goat/frontend`:

```
#! /bin/sh

# These environment variables are used by goat
export GOAT_DIR=/home/goat/curr
export WORK_DIR=/home/goat

$GOAT_DIR/mail_in
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

Set up `WORK_DIR` and `GOAT_DIR` environment variables as above,
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
0/15 * * *      /home/goat/imap_frontend --once
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
0 0 * * *       /home/goat/curr/goat >> /home/goat/log/cron
```

Now goat will run once a day to send out reminders if
needed. 

Other commands
==============

You can register users with the `register` script.  You can
use Goat's built-in pairing algorithm using the `pair`
script (all these scripts are self-documented: 
```
<script> --help
```
 will hopefully give you all the information you
need.)

To create a single game, use `add_game`.
To remove a single game, use `del_game`.

Same goes with `add_player` and `del_player`. In general all
these only apply to the current round.

