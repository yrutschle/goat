package Round;

use strict;
use locale;

use GoatLib;
use GoGame;

=head1 DESCRIPTION

Round contains all the information about a round played in a tournament:
list of games, dates, and so on.

=cut

BEGIN {
    my $subs;
    foreach my $data ( qw/GoGame number final_date bye/ ) {
        $subs .= qq{
            sub $data {
                \$_[1] ? \$_[0]->{$data} = \$_[1] : \$_[0]->{$data};
            }
        }
    }
    eval $subs;
}

=item games

Returns a list of all the games in the round.

=cut
sub games {
    @{$_[0]->GoGame};
}

sub new {
    my ($class, $num, @games) = @_;
    my (%h, $obj);
    $obj = \%h;
    bless $obj, $class;

    $obj->GoGame([]);
    $obj->number($num);

    push @{$obj->GoGame}, @games;

    return $obj;
}

sub add_game {
    my ($obj, $g) = @_;

    warn "Adding something that's not a game\n" unless $g->isa('GoGame');

    push @{$obj->GoGame}, $g;
}

sub del_game {
    my ($obj, $game) = @_;

    my @games = grep { $_ ne $game } @{$obj->GoGame};
    $obj->GoGame( \@games );
}

sub pairings_as_text {
    my ($obj) = @_;

    my $out;

    my @players = map { $_->white, $_->black } $obj->games;
    my $round_num = $obj->number;

    # Find the longest name+address
    my $max_name_length = (sort { $a <=> $b } map { length $_->fulladdress } @players)[-1];
    $max_name_length += 7; # For the club label

    $out = "[Round $round_num]\n";

    my $b_label = "Noir";
    my $w_label = "Blanc";
    my $h_label = "Handicap";
    my $bheader = "| $b_label". " " x ($max_name_length + 1 - length $b_label);
    my $wheader = "| $w_label". " " x ($max_name_length - length $w_label);
    my $header = $bheader . $wheader .  "| $h_label\n";
    $out .= $header;
    $out .= ("|" . "." x (-1 + length $bheader)) . 
            ("|" . "." x (-1 + length $wheader)) . 
            ("|" . "." x (2 + length $h_label)) . "\n";

    foreach my $game ($obj->games) {
        my $black = $game->black;
        my $white = $game->white;
        my $handi = $game->handicap;
        # Print out a formated line
        my $bt = $black->fulladdress . " (".$black->club.")";
        my $wt = $white->fulladdress . " (".$white->club.")";
        my $bl = length $bt;
        my $wl = length $wt;
        $out .= "| $bt" . " " x ($max_name_length - $bl) . " | " . 
        $wt . " " x($max_name_length - $wl) . "| $handi\n";

    }

    return $out;
}

1;
