package Tournament;

use strict;
use locale;
use English;

use Encode;
use Round;
use Mail::Address;
use GoatLib;
use GoatConfig;
use File::Copy;
use File::Basename;
use URI::Escape;
use Fcntl ':flock';

=head1 DESCRIPTION

Round contains all the information about a tournament:
List of rounds, dates, and so on.

This is designed to easily translate into a FFG .TOU tournament result file, even though maybe not everything makes sense (e.g. 'date' doesn't make sense for Toulouse's permanent tournament).

=cut

use vars qw/@attributes/;

BEGIN {
    @attributes = qw/date prog time size komi round_number Round ffgplayers filename/;
    my $subs;
    foreach my $data ( @attributes ) {
        $subs .= qq{
            sub $data {
                \$_[1] ? \$_[0]->{$data} = \$_[1] : \$_[0]->{$data};
            }
        }
    }
    eval $subs;
}

=over 4

=item Tournament->new( time => 60, komi => 7.5 );

Creates a new object, optionally set attributes

=cut
sub new {
    my ($class, %opts) = @_;
    my (%h, $obj);
    $obj = \%h;
    bless $obj, $class;

    $obj->ffgplayers([]);
    $obj->Round([]);
    foreach (@attributes) {
        $obj->{$_} = $opts{$_} if exists $opts{$_};
    }
    $obj->{prog} = 'goatlib'; # No accessor for this one

    return $obj;
}

# Accessor to constants
sub name {
    return $TOURNAMENT_NAME;
}

sub city {
    return $TOURNAMENT_CITY;
}

sub ech_url {
    return $TOURNAMENT_ECHELLE;
}

sub ech_file {
    my ($o) = @_;
    return basename $o->ech_url;
}

# Locking is done by creating a .lock file.
# There is still a race condition between the existence check and the creation
# of the file. It's still way better not locking, and for some reason flock()
# doesn't want to work here.
sub lock {
    my ($o, $file) = @_;

    my $lock = "$file.lock";
    while (-e $lock) {
        sleep 1;
    }
    open my $tmp, "> $lock" or die "$lock: $!\n";
    print $tmp "$$\n";
}

sub unlock {
    my ($o) = @_;
    my $file = $o->filename;
    return unless $file;
    my $lock = "$file.lock";
    unlink $lock;
}

# Always unlock the file when releasing the object
sub DESTROY {
    my ($t) = @_;
    $t->unlock;
}


=item Tournament->load($filename)

Loads the filename, which must contain a YAML version of a Tournament
object, and returns a Tournament.

=cut
sub load {
    my ($class, $tournament_fn) = @_;

    die "Tournament database `$tournament_fn` not found or unwritable\n" unless -w $tournament_fn;

    $class->lock($tournament_fn);

    my $f;
    local $/; undef $/;
    open $f, "$tournament_fn" or die "$tournament_fn: $!\n";
    my $data = <$f>;
    close $f;
    my $VAR1;
    local $YAML::LoadBlessed = 1;
    my $t = YAML::Load($data);

    # pick the highest round number if there are any
    $t->round_number( $t->Round->[-1]->number ) 
        if (scalar @{$t->Round});

    $t->filename($tournament_fn);
    return $t;
}



=item Tournament->save($filename)

Writes the tournament object to the file, which will be erased if necessary.

=cut

# Following a disk-full incident, we're extra careful: write to a temp file,
# check the contents of the temp file are OK, then move over the final file.
sub save {
    my ($obj, $tournament_fn) = @_;

    my ($data_in, $data_out);

    $data_out = YAML::Dump($obj);

    open my $f, "> $tournament_fn.tmp" or die "$tournament_fn.tmp: $!\n";
    print $f $data_out;
    close $f;

    # Check that reading again ends up with the same result
    open $f, "$tournament_fn.tmp" or die "reading $tournament_fn.tmp: $!\n";
    undef $/;
    $data_in = <$f>;
    close $f;
    die "error writing $tournament_fn.tmp\n" if ($data_in ne $data_out);

    move("$tournament_fn.tmp", $tournament_fn) or die "saving tournament file failed: $!\n";
}

=item Tournament->curr_round()

Returns a reference to the current Round object.

=cut
sub curr_round {
    my ($obj) = @_;

    # round_number 0 indicates there are no rounds in the tournament
    return undef unless $obj->round_number;

    $obj->Round->[$obj->round_number];
}


=item Tournament->add_round($round_number, $RoundObject)

Adds a Round object, with number $round_number.

=cut
sub add_round {
    my ($obj, $idx, $r) = @_;

    warn "Adding something that is not a Round\n" unless $r->isa('Round');

    # Extend array if necessary (for XML output)
    for ((scalar @{$obj->Round}) .. ($idx - 1)) {
        $obj->Round->[$_] = {};
    }

    $obj->Round->[$idx] = $r;

    $obj->round_number($idx);
}

=item $tournament->players

Returns a list of registered players (which may or may not play in any given round)

=cut
sub players {
    @{$_[0]->ffgplayers};
}

=item $tournament->unplayed

Returns a list of players who haven't played their game in the current round

=cut
sub unplayed {
    my ($obj) = @_;

    my @out;
    foreach my $game ($obj->curr_round->games) {
        unless ($game->is_finished or $game->is_canceled) {
            push @out, $game->white, $game->black;
        }
    }
    return @out;
}

=item $tournament->unlicensed

Returns a list of players who don't have a valid license

=cut
sub unlicensed {
    my ($obj) = @_;

    return grep { ! $_->is_licensed($TOURNAMENT_LICENSES) } $obj->players;
}

=head2 $tournament->find_game_by_email

Searches for a game in the tournament in which the specified
player is involved.

In: e-mail address of a player
Out: Reference to a GoGame object, or undef if not found

=cut
sub find_game_by_email {
    my ($tournament, $player) = @_;

    die "Not a tournament" unless $tournament->isa('Tournament');

    $player = (Mail::Address->parse($player))[0];

    foreach my $game ($tournament->curr_round->games) {
        for my $p ($game->black, $game->white) {
            my $addr = (Mail::Address->parse($p->email))[0];
            
            # Some domains mix case in the addresses they
            # send. I don't think that's actually
            # RFC-compliant, but we have to live with it, so
            # comparison is made after lowcasing
            # everything.
            if (lc $addr->address eq lc $player->address) {
                return $game;
            }
        }
    }
    return undef;
}

=head2 find_player_by_email

Searches for a player in the tournament

In: e-mail address of a player
Out: Reference to a FFGPlayer, or undef if not found

=cut
sub find_player_by_email {
    my ($tournament, $email) = @_;

    $email = (Mail::Address->parse($email))[0];

    foreach my $player ($tournament->players) {
        my $addr = (Mail::Address->parse($player->email))[0];

        return $player if (lc $addr->address eq lc $email->address);
    }

    return undef;
}


=item $tournament->add_player($p)

Adds a FFGPlayer

=cut
sub add_player {
    push @{$_[0]->ffgplayers}, $_[1];
}

=item $tournament->del_player($p)

Removes a FFGPlayer. You must check that player isn't used first.

=cut
sub del_player {
    my ($tournament, $player) = @_;

    my @players2 = grep { $_ ne $player } $tournament->players;
    $tournament->ffgplayers(\@players2);
}

=item $tournament->rounds

Returns a list of rounds

=cut
sub rounds {
    # there are uninitialised hashes in Round, remove them
    grep { ref $_ eq 'Round' } @{$_[0]->Round};
}


=item uniq_players @list

Given a list of player objects, return only one occurence of each based on
their identifyier.

=cut
sub uniq_players {
    my (@l) = @_;

    my (%seen, @out);
    foreach (@l) {
        push @out, $_ unless $seen{$_->id}++;
    }
    return @out;
}

=item tou_header $T, $rounds;

Returns the header for a .TOU file corresponding to the Tournament object $T,
including rounds specified by $rounds.

=cut
sub tou_header {
    my ($obj, $rounds) = @_;
    my ($date, $prog, $time, $size, $komi) =
       ($obj->date, $obj->prog, $obj->time, $obj->size, $obj->komi);

    # If date not set, pick first round's start date
    if (not defined $date and defined $rounds) {
        my $first_round = (split /,/, $rounds)[0];
        my $r = $obj->Round->[$first_round];
        if (defined $r) {
            my $start_date = $r->start_date;
            my ($d,$m,$y) = (localtime($start_date))[3,4,5];
            $m++; $y += 1900;
            $date = sprintf "%02d/%02d/%04d", $d,$m,$y;
        }
    }

    # If date still not set, pick today as default.
    if (not defined $date) {
        my ($d,$m,$y) = (localtime(&main::my_time))[3,4,5];
        $m++; $y += 1900;
        $date = sprintf "%02d/%02d/%04d", $d,$m,$y;
    }

    my $name = $obj->name;
    my $city = $obj->city;
    
    # Add round numbers to comment field
    $name.= " - Ronde $rounds"  if defined $rounds;

    return <<EOF;
;name=$name
;date=$date
;vill=$city
;comm=$name
;prog=$prog
;time=$time+b
;ta=80
;size=$size
;komi=$komi
;
;Num Nom Pr&eacute;nom               Niv Licence Club
EOF
}

=item tou_results \%opts, \@players, \@rounds

Given a list of players and a list of rounds, returns the .TOU output for these
players and those rounds.

Options: 'submitting' => mark games as 'submitted'. These games will no longer
be output.

=cut
sub tou_results{
    my ($obj, $r_opts, $r_p, $r_r) = @_;
    my @players = sort { $b->level <=> $a->level} @$r_p;
    my @rounds = @$r_r;
    my $submitting = $r_opts->{submitting};

    my ($black, $white, $out);

    # Build a player_id=>index hash of players
    my %player; 
    my $i = 1;
    foreach my $p (@players) {
        $player{$p->id} = $i++;
    }

    foreach my $i (1..@players) {
        my $p = $players[$i-1];

        my $game_str = "";
        round:
        foreach my $r (@rounds)  {
            foreach my $g ($r->games) {
                # Does $p play in this game?
                $black = $p->id eq $g->black->id;
                $white = $p->id eq $g->white->id;
                next unless $black or $white;

                $g->submitted(1) if $submitting;

                # Yes -- create the corresponding text in $game
                my $game;
                # $oppid is the player id of opponent
                my $oppid = $p->id eq $g->black->id ?  $g->white->id: $g->black->id;
                # Opponent might not be in the list if they played in no
                # unsubmitted games
                if (defined $g->result and defined $player{$oppid}) {
                    $game .= ' ' if $player{$oppid} < 10;
                    $game .= $player{$oppid};
                    $game .= (not defined $g->result) ? '?' :
                    (not $g->rated ) ? '=' :
                    (($g->result eq 'black') and $black) ? '+' :
                    (($g->result eq 'white') and $white) ? '+' :
                    '-';
                    $game .= $black ? 'b' : 'w';
                    $game .= $g->handicap;
                    $game .= ' 'x(8-length $game);
                } else {
                    $game = " 0=     ";
                }
                $game_str .= $game;
                next round;
            }
            $game_str .= " 0=     ";
        }
        $ACCUMULATOR = "";
        formline(<<'END', $player{$p->id}, $p->familyname." ".$p->givenname, $p->stones, $p->license, $p->club, $game_str);
@>>> @<<<<<<<<<<<<<<<<<<<<<<< @>> @<<<<<< @<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END

        $out .= $ACCUMULATOR;
    }
    return $out;
}

=item Tournament->check_unsubmited()

Check rounds for played, rated, unsubmitted games and warn if that exists

=cut
sub check_unsubmitted {
    my ($obj) = @_;

    foreach my $round (@{$obj->Round}) {
        next unless ref $round eq 'Round';

        foreach my $g ($round->games) {
            warn "WARNING: Unsubmitted game ".$g->black->id."/".$g->white->id." in round ".$round->number. "\n" if $g->rated and defined $g->result and not $g->submitted;
        }
    }
}


=item Tournament->tou( [full => 1], [submitted => 1], [round => n] )

Returns the status of the tournament as a .TOU file
(http://ffg.jeudego.org/echelle/format_res.php)

By default, only the current round is returned. The round number can be
specified by passing 'round => n', or a full status with all the rounds can be
printed with 'full => 1' (careful: if registration levels have changed, you may
not know about it as the .TOU format does not support that).

=cut
sub tou {
    my ($obj, %opts) = @_;

    my @rounds = (exists $opts{full}) ?  
                        $obj->rounds : 
                        (@{$obj->Round}[ exists $opts{round} ? split /\s*,\s*/, $opts{round} : -1 ]);

    $obj->check_unsubmitted(@rounds);

    # Retrieve all players that played rated games not yet submitted in these rounds
    my @players = uniq_players map { $_->white, $_->black } 
                  grep { $_->rated }
                  grep {defined $_->result and (exists $opts{submitted} or not $_->submitted)} 
                  map { $_->games } @rounds;

    my $str = $obj->tou_header(exists $opts{full}? undef : join ', ', map {$_->number} @rounds);

    $str .= $obj->tou_results(\%opts, \@players, \@rounds);

    return $str;
}

# Returns the tournament as a HTML string
# Options:
# Output only specific round
# as_HTML( round => 3 );

use CGI qw/:standard/;
use HTML::Table;  # apt-get install libhtml-table-perl

sub as_HTML {
    my ($obj, %opts) = @_;

    my $tname = $obj->name;

    my $html = 
    start_html(
        -title => $tname,
        -encoding => 'UTF-8',
    ), h1($tname);

    $html .= "<h1>".$tname."</h1><h2>Inscrits</h2>";

    # Player list
    my $table = new HTML::Table(-cols=>3, -border=>1);
    $table->addRow('Nom', 'Pr&eacute;nom', 'Niveau', 'Club');
    foreach my $player 
    (
        sort {$a->sortname cmp $b->sortname} $obj->players
    ) {
        $table->addRow(
            $player->familyname,
            $player->givenname,
            $player->level . '(' . $player->stones . ')',
            $player->club
        );
    }
    $html .= $table;

    my $index_url = $INDEX_URL;

    foreach my $round (@{$obj->Round}) {
        next unless ref $round eq 'Round';

        my $round_num = $round->number;
        $html .= "<h2>Appariements pour la ronde $round_num</h2>\n".a({href=>$index_url}, "Retour aux r&egrave;gles<br>");
        $table = new HTML::Table (-cols=>4, -border=>1 );
        $table->addRow('Blanc', 'Noir', 'Handicap', 'R&eacute;sultat', 'SGF');
        foreach my $game ($round->games) {
            my $result = $game->result // 0;
            $result = 'NC' unless $result;
            $result = "($result)" unless $game->rated;
            my $white_level = $game->white->register_level($round_num) || $game->white->level || "NC";
            my $black_level = $game->black->register_level($round_num) || $game->black->level || "NC";
            my $sgf = uri_escape Encode::encode('UTF-8', $game->sgf) // 0;
            $table->addRow(
                $game->white->fullname." ($white_level) ".$game->white->club,
                $game->black->fullname." ($black_level) ".$game->black->club,
                $game->handicap,
                $result,
                $sgf ?  a({href=> "/wgo_cgi/wgo.cgi?sgf=$sgf"}, 'SGF') : "",
            );
            $table->setCellBGColor($table->getTableRows,
                { 
                    "white" => 1,
                    "black" => 2,
                }->{$result}
                , "Green");
            $table->setRowBGColor($table->getTableRows, "Gray") if $game->is_canceled;
        }
        $html .= $table;
        $html .= "<p>Joueur en passe: ".$round->bye->fullname if defined $round->bye;
        $html .= "<p>Fin de ronde: ".  utc2str($round->final_date) . "</p>\n";
    }

    # Score table
    $table = new HTML::Table(-cols => 3, -border=> 1);
    $table->addRow('Nom', 'Score', 'SOS');
    foreach ($obj->score) {
        $table->addRow(@$_);
    }
    $html .= "<h2>Score</h2>".a({href=>$index_url}, 'Retour aux r&egrave;gles<br>').$table;

    $html .= a({href=>$index_url}, 'Retour'), end_html();

    return Encode::encode('UTF-8', $html);
}

=item score

Returns an ordered list of players along with their score and SOS. First player
wins.

=cut
sub score {
    my ($obj) = @_;
    my (%score, %sos);

    # Get all games in the tournament (don't really care about rounds here)
    my @games = map { $_->games } $obj->rounds;

    # Compute direct wins
    foreach my $game (@games) {
        my $black = $game->black->fullname;
        my $white = $game->white->fullname;

        $score{$white} ||= 0;
        $score{$black} ||= 0;

        if ($game->is_finished and defined $game->result) {
            if ($game->result eq 'white') {
                $score{$white}++;
            } elsif ($game->result eq 'black') {
                $score{$black}++;
            }
        }
    }

    # Compute SOS
    foreach my $player (keys %score) {
        my $sos = 0;
        foreach my $game (@games) {
            my $black = $game->black->fullname;
            my $white = $game->white->fullname;

            if ($player eq $black) {
                $sos += $score{$white};
            } elsif ($player eq $white) {
                $sos += $score{$black};
            }
        }
        $sos{$player} = $sos;
    }

    return sort { ($b->[1] <=> $a->[1]) or ($b->[2] <=> $a->[2]) } map { [$_, $score{$_}, $sos{$_} ] } sort keys %score;
}


# Download echelle file from ffg site -- if filename already
# exists, delete it
sub download_echelle {
    my ($t) = @_;

    return 1 if defined $CFG->{testing};

    my $url = ech_url();
    die "tournament_echelle not defined\n" unless defined $url;
    my $file = $t->ech_file();

    unlink $file;
    `wget $TOURNAMENT_ECHELLE`;
    return -r $file;
}


# Update players' level, name, clubs, license, ...
sub update_fields {
    my ($tournament, %all_players) = @_;
    foreach my $player ($tournament->players) {
        if (not exists $all_players{$player->id}) {
            warn $player->fullname . " not found in echelle file -- skipping\n";
            next;
        }

        my $ech_p = $all_players{$player->id};

        if ($ech_p->fullname ne $player->fullname) {
            warn "Updating name from ".$player->fullname." to ".$ech_p->fullname."\n";
            $player->givenname($ech_p->givenname);
            $player->familyname($ech_p->familyname);
        }
        if ($ech_p->level != $player->level) {
            warn $player->fullname.": changing from ".$player->level." to ".$ech_p->level."\n";
            $player->level($ech_p->level);

        }
        if ($ech_p->club ne $player->club) {
            warn $player->fullname.": updating club from ".$player->club." to ".$ech_p->club."\n";
            $player->club($ech_p->club);
        }
        if ($ech_p->license ne $player->license) {
            warn $player->fullname.": updating license from ".$player->license." to ".$ech_p->license."\n";
            $player->license($ech_p->license);
        }
        if ($ech_p->status ne $player->status) {
            warn $player->fullname.": license status changed to:". $ech_p->status."\n";
            $player->status($ech_p->status);
        }
        if (not $player->is_licensed($TOURNAMENT_LICENSES)) {
            warn $player->fullname.": player is not licensed.\n";
            warn $player->fullname.": player license: ".$player->status." (".$player->status_text.") is not allowed.\n"; 
        }
    }
}

# Download a new echelle and update all player fields if there is a tournament
use FFGPlayer;

sub update_ech {
    my ($tournament) = @_;

    # Build a hash of all the players in the echelle file
    my %all_players;
    my $ech;

    my $ECHELLE_FILE = $tournament->ech_file();
    my $r = $tournament->download_echelle();
    return $r if not defined $tournament;

    open $ech, $ECHELLE_FILE or die "$ECHELLE_FILE: $!\n";


    while (<$ech>) {
        next if /^#/;
        my $p = FFGPlayer->new_from_ech(decode 'ISO-8859-1', $_);
        next if not defined $p;
        $all_players{$p->id} = $p;
    }

    update_fields($tournament, %all_players);
}


1;
