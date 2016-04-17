package GoGame;

use strict;
use locale;

use FFGPlayer;

=head1 DESCRIPTION

GoGame contains all the information about a Go Game played in a tournament:
players, handicaps, date of the game, result... and so on. Obviously not
everything might be defined (e.g. result might be undefined if the game hasn't
be played yet).

=cut

=head2 The state machine

Each game is considered like a state machine.  The following
states apply:

=over 4

=item undef

Nothing is known about the game: the players haven't been
notified.

=item challenged

The players have been notified of the game. Parameter: date
of the challenge (to allow for reminders).

=item scheduled

The players have replied to schedule the game, and specified
a location and date. Parameter: date of the game (to not
bother them anymore and ask them for the results after the
game)

=item finished

The game has been played and the result is known. Parameter:
who won? (black|white)

=item canceled

The game has been canceled for some reason. (? Is it useful
to keep track of it then?)

=back

=head2 Attributes of the object

=over 4

=item black

FFGPlayer object of the black player

=item white 

FFGPlayer object of the black player

=item state

(one of the values specified above)

=item handicap

Handicap at which the game is to be player

=item challenge_date

=item scheduled_date

=item reminder_date

The dates are GMT, seconds from 1970. reminder_date corresponds to the date of
the last reminder sent to the players about that game: before the game, when
was the last reminder about organising the game sent; after the game, when was
the last reminder about sending in the results sent.

=item location

Location for a scheduled game.

=item result

Who won the game (black or white).

=item rated

True if the game is to be submitted to a rating system. (Typically, we don't
want games that haven't been played to count towards the rating system).

=item submitted

True if the game was submitted to the rating system. This is to keep track of
what has already be submitted and ease partial submissions.

=item sgf

Path to the SGF file of the finished game, if any.

=cut

BEGIN {
    my $subs;
    foreach my $data ( qw/challenge_date scheduled_date reminder_date location result rated submitted sgf/ ) {
        $subs .= qq{
            sub $data {
                defined \$_[1] ? \$_[0]->{$data} = \$_[1] : \$_[0]->{$data};
            }
        }
    }
    eval $subs;
}

################################################################################
# CONSTANTS

# Constant for the various status-es (these aren't parameters,
# don't change them)
use constant UNDEF => 'undef';
use constant CHALLENGED => 'challenged';
use constant SCHEDULED  => 'scheduled';
use constant FINISHED   => 'finished';
use constant CANCELED   => 'canceled';

################################################################################
# Special accessors

sub status {
    my ($obj, $s) = @_;
    $obj->{status} = UNDEF if not defined $obj->{status};
    $s ? $obj->{status} = $s : $obj->{status};
}

sub handicap {
    my ($obj, $s) = @_;
    $obj->{handicap} = 0 if not defined $obj->{handicap};
    defined $s ? $obj->{handicap} = $s : $obj->{handicap};
}

sub black {
    my ($obj, $r) = @_;
    $obj->{black}->{FFGPlayer} = $r if $r;
    $obj->{black}->{FFGPlayer};
}

sub white {
    my ($obj, $r) = @_;
    $obj->{white}->{FFGPlayer} = $r if $r;
    $obj->{white}->{FFGPlayer};
}

#################################################################################

# Change status to 'challenged': challenge mail has been sent
# in: Date the challenge was sent
sub challenged {
    my ($obj, $date) = @_;

    $obj->status(CHALLENGED);
    $obj->challenge_date($date);
}

# Change status to 'scheduled': a player has scheduled the game
sub scheduled {
    my ($obj, $date, $location) = @_;
    
    $obj->status(SCHEDULED);
    $obj->scheduled_date($date);
    $obj->location($location);
    $obj->reminder_date($date); # Don't pester until after the game
}

# Change status to finished and set result
sub finished {
    my ($obj, $res) = @_;

    $obj->status(FINISHED);
    $obj->result($res);
}

sub cancel {
    my ($obj, $res) = @_;

    $obj->status(CANCELED);
}

sub is_challenge_sent {
    $_[0]->status eq CHALLENGED;
}

sub is_scheduled {
    $_[0]->status eq SCHEDULED;
}

sub is_finished {
    $_[0]->status eq FINISHED;
}

sub is_canceled {
    $_[0]->status eq CANCELED;
}

sub new {
    my ($class, $black, $white, $handi) = @_;

    my (%h, $obj);
    $obj = \%h;
    bless $obj, $class;

    $obj->handicap($handi);
    $obj->black($black);
    $obj->white($white);
    $obj->rated(1);
    $obj->reminder_date(0);

    return $obj;
}

=item text_status

Returns a multi-line description of the game's status.

Options:
        summary: Only print player names and handicap

=cut
sub text_status {
    my ($game, %opts) = @_;

    my ($black, $white, $c_date, $s_date, $location, $result,
        $state, $handicap);
    $black = $game->black->fulladdress;
    $white = $game->white->fulladdress;
    $result = "\t";
    if ($game->result) {
        $result = $game->result;
        $result = "($result)" unless $game->rated;
        $result = "winner: $result";
    }
    $state = $game->status;
    $handicap = $game->handicap;
    $location = $game->location ? $game->location : "\t";

    if (defined $game->challenge_date) {
        $c_date = "Challenge sent ".gmtime $game->challenge_date;
    } else {
        $c_date = "Challenge not sent";
    }

    if (defined $game->scheduled_date) {
        $s_date = "Scheduled for ".(gmtime $game->scheduled_date)." at $location";
    } else {
        $s_date = "Not scheduled";
    }

    if ($opts{summary}) {
        return <<"EOF";
$black\t$white\t($handicap)\t$result
EOF

    }

    return <<"EOF";
$state: $black	$white	($handicap stones) $result 
                $c_date
                $s_date

EOF

}

1;
