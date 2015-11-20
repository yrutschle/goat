package Round;

use strict;
use locale;

use GoGame;
use XML::Structured; # Installed from CPAN

=head1 DESCRIPTION

Round contains all the information about a round played in a tournament:
list of games, dates, and so on.

=cut

# For XML storage
my $round_dtd = [
'Round' => 
        'number',
        [GoGame->dtd],
];

# Returns the DTD for this object
sub dtd {
    $round_dtd;
}

BEGIN {
    my $subs;
    foreach my $data ( qw/GoGame number final_date/ ) {
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

1;
