#! /usr/bin/perl -w

# Test script that sends an example of all possible e-mails
# to one address. This allows to see what formatting looks
# like in real e-mail clients.

# Usage :
# t/send_all rcpt@example.net
#
# It will create e-mail files under t/tmp/maildir, which can then be copied to
# a Maildir /new directory and observed with normal e-mail clients.

use strict;

$ENV{PATH} = "$ENV{PATH}:../";
$ENV{PERL5LIB} = "$ENV{PERL5LIB}:../";

use GoatConfig;
use GoatLib;
use Tournament;
use MailOut;

my $dirname = "maildir";
`rm -rf $dirname`;
mkdir "$dirname" or die "Could not create `$dirname` directory\n";

my $mailer = new MailOut( send_to_dir => "$dirname" );

$mailer->mail_in_illegal(
    rcpt => "try\@example.org",
    contents => "Some illegal e-mail");

my $Tournament = load Tournament $TOURNAMENT_FILE;
my @players = $Tournament->players;
my $black = shift @players;
my $white = shift @players;

$mailer->remind_challenge(
    black => $black->fulladdress, 
    white => $white->fulladdress, 
    handi => 42, 
    dateonly => time);

$mailer->ask_result(
    p1 => $black->fulladdress,
    p2 => $white->fulladdress,
    date => time);

$mailer->player_unknown(
    p1 => "unknown\@example.com"
);

$mailer->issue_challenge(
    black => $black->fulladdress, 
    white => $white->fulladdress, 
    handi => 42, 
    dateonly => time);

$mailer->notify_schedule(
    black => $black->fulladdress, 
    white => $white->fulladdress, 
    handi => 42, 
    time => time,
    location => "Wonderland",
    setter => "setter\@example.net");

$mailer->deadline(
    round => 42,
    time => time);

$mailer->coming_up(
    black => $black->fulladdress, 
    white => $white->fulladdress, 
    handi => 42, 
    date => time,
    location => "Wonderland");

$mailer->baddate(
    p1 => "badsetter\@example.org");

$mailer->pastdate(
    p1 => "badsetter\@example.org");

$mailer->give_results(
    black => $black->fulladdress, 
    white => $white->fulladdress, 
    result => 'white',
    player => $white->fulladdress);

$mailer->badcolour(
    p1 => "badsetter\@example.org");

$mailer->send_pairings(
    mailto => [ $white ],
    pairings => $Tournament->curr_round->pairings_as_text,
    bye => "no play <angry\@example.com>",
    round => $Tournament->round_number,
    dateonly => $Tournament->curr_round->final_date);


my $round = $Tournament->curr_round->number ;
my $tou = $Tournament->tou( round => $round );
$mailer->send_results(
    round => $round,
    attach => {
        Charset => 'ISO-8859-1',
        Type => 'text/plain',
        Filename => "round$round.tou",
        Data => $tou,
    },
);


$mailer->send_unplayed(
        mailto => [ $white ],
        old_round => 1,
        new_round => 7,
    );


