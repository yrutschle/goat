#! /usr/bin/perl -w

# Goat: Gentil Organisateur et Administrateur de Tournois
# Copyright (C) 2006-2018  Yves Rutschle
# 
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more
# details.
# 
# The full text for the General Public License is here:
# http://www.gnu.org/licenses/gpl.html

use strict;

=head1 NAME

mail_out -- goat's e-mail sender

=head1 SYNOPSIS

The old command line interface:

 mail_out [--mail-in-illegal <rcpt>,<file>]
         [--issue-challenge <black>,<white>,<handi>,<limit date>]
         [--remind-challenge <p1>,<p2>,<handi>,<final_date>]
         [--ask-results <p1>,<p2>]
         [--player-unknown <p1>]
         [--notify-schedule <b>,<w>,<handi>,<date>,<location>,<setter>]
         [--coming-up <b>,<w>,<handi>,<date>,<location>,<setter>]
         [--baddate <rcpt>,<date_str>]
         [--pastdate <rcpt>,<date_str>]
         [--give-results <p1>,<p2>,<reporter>,<winner>]
         [--badcolour <rcpt>,<colour_str>]
         [--attach <attachement>]

         [--no-send]

New interface:

 my $mail_out = new MailOut;
 my $mail_test = new MailOut 
                        testing => 1,
                        no_send => 1;
 $mail_out->mail-in-illegal(<rcpt>, <file>);
 [...]

=head1 DESCRIPTION

Mail_out groups all of Goat's outgoing e-mail messages. It
provides abstract messages, instanciates them with templates
(which can be easily translated), and manages the actual
e-mail sending, either through the local MTA or through the
SMTP configured through I<GoatConfig.pm>.

=cut

package MailOut;

use Getopt::Long;
use Pod::Usage;
use MIME::Entity;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;
use Data::ICal;
use Data::UUID;
use DateTime;  # package libdatetime-perl
use DateTime::Format::ICal; 
use Data::ICal::Entry::Event;
use Template;
use POSIX;
use Try::Tiny;
use Data::Dumper;

use GoatConfig;
use GoatLib;


my $LOGFILE = "$LOG_DIR/mail_out.log";

# record a line in a log file.
my ($logfile);
open $logfile, ">> $LOGFILE" or die "$LOGFILE: $!\n";
sub record {
    foreach (@_) {
        print $logfile (gmtime).": $_\n";
    }
}

my $tt = Template->new({ 
        INCLUDE_PATH => "$TEMPLATE_DIR",
    });

# Testing: to make some normally random things non-random
# No_send: to prevent sending mail
my ($testing, $no_send); 


# This class is a singleton, which is "pattern-speak" for
# "it's evolved from something that was a standalone program
# and there is currently no point in making all the global
# variables into instance variables. Sorry."
sub new {
    my ($class, %opts) = @_;

    $testing = 1 if ($opts{testing});
    $no_send = 1 if ($opts{no_send});

    my %o;  # Later, this should contain object settings (logfile, testing, and so on)
    return bless \%o, $class;
}

=head2 OPTIONS

=over 4

=item --mail-in-illegal <rcpt>,<file>

Called from mail_in on an illegal or unknwon command. 

=item --remind-challenge <black,white,handicap,final_date>

Remind players who haven't scheduled their game yet to do
so.

B<final_date> is UTC UNIX date.

=item --ask-results <black,white,date>

Ask players who had scheduled their game at I<date> that
they need to publish their results.

=item --player-unknown <address>

Notifies I<address> that that address is unknown. (Game
schedules and results must be sent from the e-mail address
that Goat knows about).

=item --issue-challenge <black,white,handicap,limit date>

Sends players their pairing.

=item --notify-schedule <black,white,handicap,date,location,setter>

Notify players that I<setter> has scheduled the game to take
place on I<date> in I<location>

=item --deadline <round,date>

Notify organiser that tournament round I<round> is to finish
on I<date> (UNIX timestamp), with an ICS attached.

=item --coming-up <black,white,handicap,date,location>

Notify players that their game is scheduled to take
place on I<date> (soon) in I<location>

=item --baddate <rcpt,date>

Notify I<rcpt> that I<date> is invalid.

=item --pastdate <rcpt,date>

Notify I<rcpt> that I<date> is already past.

=item --give-results <black,white,result,reporter>

Notify the players that I<reporter> has reported the result
of the game.

=item --badcolour <rcpt,colour>

Notify I<rcpt> that I<colour> is not a valid color.

=cut

# A lot of actions simply result in expanding a specific
# e-mail template with appropriate parameters, then sending
# it to some recipients. So we define the properties for
# each action (template, params and so on), then one
# function (process_action) does the same job for each
# template, then we instanciate one method for each
# template.
#
# Methods expect template data to be passed as hash, e.g.:
# $o->mail_in_illegal( rcpt => $to, file => $path );
# (this calls process_action("mail_in_illegal", rcpt => $to [...])
#
# 'param_names' are no longer used, we keep them for
# documentation (maybe we could validate the method was
# called with appropriate parameters)
# - if 'date' exists turns it to string (with time)
# - if 'dateonly' exists turn it to string (no time)
# - if 'postprocess' exists it gets called just before
# sending expanding the template, which allows to customise
# parameters for specific actions.
# - 'mailto' contains the target email addresses coming
# from the named parameters or configuration.
# - 'attach' is a MIME::Entity initialisation hashref used to attach to the
# mail, if it exists.
my %template_methods = (
    'mail_in_illegal'         => {
        param_names => [qw/rcpt file/],
        template => "badcmd.tt",
        mailto => [qw/rcpt/],
    },

    'remind_challenge'        => {
        param_names => [qw/black white handi dateonly/],
        template => "organise.tt",
        mailto => [qw/black white/],
    },

    'ask_result'              => {
        param_names => [qw/p1 p2 date/],
        template => "ask_result.tt",
        mailto => [qw/p1 p2/],
    },

    'player_unknown'          => {
        param_names => [qw/p1/],
       template => "unknown_address.tt",
        mailto => [qw/p1/],
    },

    'issue_challenge'         => {
        param_names => [qw/black white handi dateonly/],
        template => "pairing.tt",
        mailto => [qw/black white/],
    },

    'notify_schedule'         => {
        param_names => [qw/ black white handi time location setter/],
        postprocess => sub {
            my ($data) = @_;

            # Make string for mail subject and body,
            # localised to tournament timezone (could be
            # extended to a user-defined timezone)
            $data->{date} = utc2str $data->{time};

            # Create ICS using UTC (marked by 'Z' at the end)
            my $dtstart = DateTime::Format::ICal->format_datetime(DateTime->from_epoch(epoch => $data->{time}));
            my $dtend = DateTime::Format::ICal->format_datetime(DateTime->from_epoch(epoch => $data->{time} + 2 * 3600));
            my $ical = Data::ICal->new();
            my $ug = Data::UUID->new();
            my $event = Data::ICal::Entry::Event->new();
            $event->add_properties(
                summary => $TOURNAMENT_NAME,
                description => <<EOF,
noir: $data->{black}
blanc: $data->{white}
handicap: $data->{handi}
EOF
                dtstart => $dtstart,
                dtend => $dtend,
                location => $data->{location},
                uid => $ug->to_string($ug->create()),
            );
            if ($testing) {
                # Give variable / random fields fixed values
                $ical->add_properties(prodid => "Goat test suite");
                $event->add_properties(uid => "00000000-0000-0000-HELL-0WORLD000000");
            }
            $ical->add_entry($event);
            $data->{attach} = {
                Type => 'text/calendar',
                Encoding => 'base64',
                Data => $ical->as_string, # encoding is done in sendmail
            };
        },
        template => "scheduled.tt",
        mailto => [qw/black white/],
    },

    'deadline' => {
        param_names => [qw/ round time /],
        postprocess => sub {
            my ($data) = @_;

            $data->{date} = utc2str $data->{time};
            $data->{date} =~ s/ \d\d:\d\d//; # Keep date only

            # Create ICS for end of round
            my $dt = DateTime::Format::ICal->format_datetime(
                DateTime->from_epoch(epoch => $data->{time}));
            # format_datetime doesn't seem to produce  all-day event, so remove time spec
            # manually
            $dt =~ s/T.*//;
            my $ical = Data::ICal->new();
            my $ug = Data::UUID->new();
            my $event = Data::ICal::Entry::Event->new();
            my $desc = "$TOURNAMENT_NAME: end round $data->{round}";
            $event->add_properties(
                summary => $desc,
                description => $desc,
                dtstart => $dt,
                dtend => $dt,
                location => $data->{location},
                uid => $ug->to_string($ug->create()),
            );
            if ($testing) {
                # Give variable / random fields fixed values
                $ical->add_properties(prodid => "Goat test suite");
                $event->add_properties(uid => "00000000-0000-0000-HELL-0WORLD000000");
            }
            $ical->add_entry($event);
            $data->{attach} = {
                Type => 'text/calendar',
                Encoding => 'base64',
                Data => $ical->as_string, # encoding is done in sendmail
            };
        },
        template => "deadline.tt",
        mailto => [qw/ admin_address /],
    },

    'coming_up'               => {
        param_names => [qw/black white handi date location/],
        template => "game_reminder.tt",
        mailto => [qw/black white/],
    },

    'baddate'                 => {
        param_names => [qw/p1 date_str/],
        template => "baddate.tt",
        mailto => [qw/p1/],
    },

    'pastdate'                => {
        param_names => [qw/p1 date_str/],
        template => "pastdate.tt",
        mailto => [qw/p1/],
    },

    'give_results'            => {
        param_names => [qw/black white result player/],
        template => "results.tt",
        postprocess => sub {
            my ($data) = @_;
            $data->{winner} = $data->{result} eq 'black' ?  $data->{black} : $data->{white};
        },
        mailto => [qw/black white/],
    },

    'badcolour'               => {
        param_names => [qw/p1 colour/],
        template => "badcolour.tt",
        mailto => [qw/p1/],
    },

    'send_pairings'           => {
        param_names => [qw/pairings round/],
        template => "pairings.tt",
    },

    'send_results'           => {
        param_names => [qw/round tou/],
        mailto => [qw/admin_address rating_manager/],
        template => "send_results.tt",
    },

    'send_unplayed'          => {
        param_names => [qw/old_round new_round/],
        template => "unplayed.tt",
    },

);

# Given an action name, fill in common fields and send
# expanded template by mail
# Parameters are a hash of names that get expanded in the
# templates.
# Recipients are FFGPlayers listed in 'mailto' as parameters (e.g. 'black',
# corresponding to the hash keys) or if 'mailto' exists in parameters use that
# instead (as an arrayref)
sub process_action {
    my ($action_name, %data) = @_;
    $data{date} = utc2str $data{date} if exists $data{date};
    $data{dateonly} = utc2str $data{dateonly}, "%A %d %B %Y" if exists $data{dateonly};

    # Import all configuration into template substitutions
    map { $data{$_} = $CFG->{$_} } keys %$CFG;

    my %action = %{$template_methods{$action_name}};
    my @to;
    if (exists $data{mailto}) {
        @to = sort map {$_->email} @{$data{mailto}};
    } else {
       @to = sort map {$data{$_}} @{$action{mailto}};
   }
    # copy mail to admin adress
    if (defined $ADMIN_FORWARD and $ADMIN_FORWARD eq 'yes') {
        push @to, $ADMIN_ADDRESS;
    }
    $action{postprocess}->(\%data) if exists $action{postprocess};
    sendmail(\@to, $action{template}, \%data);
}


# Now instanciate one method for each action
# Each method simply calls process_action() with the action
# name as first parameter
foreach my $method (keys %template_methods) {
    my $subs;
    $subs .= qq(
       sub $method {
           my (\$o, \@p) = \@_;
           return process_action(\"$method\", \@p);
       }
    );
    eval $subs;
}


# Process template, create message with attachements and send mail to one or
# several recipients:
# sendmail ['bob@foo.com', 'joe@bar.com'], $template, # \%data;
sub sendmail {
    my ($r_to, $template, $r_data) = @_;

    my $body;

    # Mails are encoded in UTF-8 (see charset below) so encode all strings to
    # UTF. We also get references here for attachment objects, so don't encode
    # those.
    foreach my $k (keys %$r_data) {
        $r_data->{$k} = Encode::encode('UTF-8', $r_data->{$k}) unless ref $r_data->{$k};
    }

    $tt->process($template, $r_data, \$body) or die $tt->error;

    # Remove header lines
    $body =~ s/^(.*?)\n\n//s;
    my $hdrs = $1;
    my %hdr;
    foreach my $hdr (split /\n/, $hdrs) {
        $hdr =~ /(.*?): (.*)/;
        $hdr{lc $1} = $2;
    } 

    $r_to = [$r_to] unless ref $r_to;

    map { $_ = Encode::encode('UTF-8', $_) } @$r_to;

    my %mime_parms =  (
        'From' => $GOAT_ADDRESS,
        'Return-Path' => $GOAT_ADDRESS,
        'X-Loop' => $GOAT_ADDRESS,
        'To' => (join ',', @$r_to),
        'Subject' => $hdr{subject},
        'Type' => 'multipart/mixed',
    );
    if ($testing) {
        # When testing, make MIME marker deterministic, and
        # remove library version number
        $mime_parms{Boundary} = "---testing42ftwtesting";
        $mime_parms{'X-Mailer'} = "MIME-Tools with no version";
    }

    my $msg = MIME::Entity->build(%mime_parms);
    $msg->attach(
        'Charset' => 'UTF-8',
        'Data' => $body,
    );

    if (exists $r_data->{attach}) {
        $r_data->{attach}->{Data} = Encode::encode('UTF-8', $r_data->{attach}->{Data});
        $r_data->{attach}->{Charset} = 'UTF-8';

        $msg->attach(%{$r_data->{attach}});
    }

    # If more than 3 recipients, send mails one by one (avoids being labelled
    # spammer by Free.fr). Otherwise, just one mail, so e-mails for challenges
    # contain all the relevant addresses for players.
    if (@$r_to > 3) {
        foreach my $rcpt (@$r_to) {
            $msg->head->set("To", $rcpt);
            sendmsg($msg);
        }
    } else {
        sendmsg($msg);
    }
}


# Passes a MIME::Entity to the SMTP server (or the console, when testing)
sub sendmsg {
    my ($msg) = @_;

    if ($no_send) {
        # The mail is already encoded; we don't want PerlIO to convert it to
        # 'locale' as that would become unportable
        binmode STDOUT, ':raw';

        # MIME::Entity does not output headers in a
        # deterministic order. We care when we test, so
        # output the headers separately and sorted
        # alphabetically
        print join "\n", sort split /\n/, $msg->header_as_string;

        print $msg->body_as_string;

        # Set back to locale for further console output
        binmode STDOUT, ":utf8";
        return;
    } 

    # Happy debugger warning: this code is never tested by
    # the test suite, because we don't want it to *actually*
    # send e-mail. This means one must be extra careful when
    # editing it, and that it'll appear as not covered
    # during test (because, well, it isn't).

    # If SMTP is set up, use it
    if (exists $CFG->{smtp_server}) {
        my %opts = (
            host => $CFG->{smtp_server},
            ssl => 'starttls',
            sasl_username => $CFG->{smtp_user},
            sasl_password => $CFG->{smtp_passwd},
        );
        $opts{ssl_options} = { SSL_ca_file => $CFG->{smtp_root_ca} } if exists $CFG->{smtp_root_ca};
        my $smtp = Email::Sender::Transport::SMTP->new(%opts);
        die "no transport\n" unless defined $smtp;
        try {
            Email::Sender::Simple->send($msg, { transport => $smtp });
        } catch {
            record "Sender error: $_\n";
        }
    } else {
        # Otherwise, use sendmail or whatever the system
        # will find appropriate
        $msg->send;
    }

    my $to = $msg->head->get("To");
    my $subject = $msg->head->get("Subject");
    record("$to: $subject");
}


1;

