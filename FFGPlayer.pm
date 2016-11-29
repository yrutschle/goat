package FFGPlayer;

use v5.14;
use strict;
use locale;
use Data::Dumper;
use GoatLib;

use Unicode::Collate;

# Objet décrivant un joueur de la fédération française de Go.
# Il y a quelques champs supplémentaires que l'utilisateur peut remplir à la
# main.

my $player_dtd = 
[ 'FFGPlayer' =>
        [],
        'id',
        'familyname',
        'givenname',
        'level',
        'status',
        'license',
        'club',
        'email',
        ['registering_level'],
];

# Returns the DTD for this object
sub dtd {
    $player_dtd;
}

BEGIN {
    my $subs;
    foreach my $data ( qw/givenname familyname level status license club email registering_level/ ) {
        $subs .= qq{
            sub $data {
                \$_[1] ? \$_[0]->{$data} = \$_[1] : \$_[0]->{$data};
            }
        }
    }
    eval $subs;
}

# Crée un nouvel objet joueur.
# En paramètre, ligne de l'échelle.
# Renvoie un joueur, ou undef si la ligne est invalide.
sub new_from_ech {
    my ($class, $line) = @_;

    $line =~ /^(\S+)\s+    # Name
               (\S+)\s+    # 1st name
               ([-\d]+)\s     # Rank
               (.)\s          # status: L: has a valid license; e: foreigner; -: no license ; X: ? ; C: licence loisir?
               ([\w-]{7})\s   # License number
               (.{4})?        # Club (optionnal)
             /x or (warn "Illegal echelle line: $line") and return undef;

    my ($name,$surname,$level,$status,$license,$club) = ($1,$2,$3,$4,$5,$6 // "");
    my %data;
    my $ref = \%data;
    bless $ref, $class;

    $ref->registering_level([]);

    $ref->familyname($name);
    $ref->givenname($surname);
    $ref->level($level);
    $ref->status($status);
    $ref->license($license);
    $club =~ s/^\s*//;
    $ref->club($club);

    return $ref;
}

# alias line parsing: Parses additional information, at the end of the line
# after the '#'. Info can be a level, a licence number.
# Reports unknown options to stderr.
# Returns: ($niv, $licence) list
# (this is a private function)
sub parse_additional_info {
    my ($info) = @_;

    return (undef, undef) unless defined $info;

    my ($niv, $licence);

    if ($info =~ s/\b(\d+[kd]\b)//i) {
        $niv = $1;
    }

    if ($info =~ s/\b(\d{7})\b//) {
        $licence = $1;
    }

    $info =~ s/[#\s]//g;

    warn "Unknown option: $info\n" if $info;

    return ($niv, $licence);
}


# grep_echelle($filename, "John Doe");
# Search $filename for players which name contains the list at the end. Here
# it'd find all John Doe's
# License is not currently used (could be used to disambiguate or speed up
# later)
sub grep_echelle {
    my ($fn, $names, $license) = @_;

    my $verbose_search = 0;
    my $checked = 0; # Counter for progress bar
    my @out;

    my @names = split /\s+/, $names;
    my $ech;
    open $ech, $fn or die "$fn: $!\n";
    my @haystack;
    @haystack = <$ech>;


    print "searching for ".(join " ", @names)."\n" if $verbose_search;
    # First we search with ASCII as it's fastest
    foreach my $line (@haystack) {
        my $match = 1;
        foreach my $name (@names) {
            if ($line !~ /$name/i) {
                $match = 0;
                last;
            }
        }
        if ($match) {
            push @out, $line;
        }
    }
    @out = grep /$license/, @out if defined $license;
    return @out if @out;

    # If ASCII failed, try Unicode collation (pretty slow)
    # (Actually I think this is not necessary if running UTF8 as pattern
    # matching works right. Disabling for now).
    if (0) {
        my $Collator = Unicode::Collate->new(normalization => undef, level => 1);
        foreach my $line (@haystack) {
            my $match = 1;
            foreach my $name (@names) {
                if ($Collator->index($line, $name) == -1) {
                    $match = 0;
                    last;
                }
            }

            if ($match) {
                print "\rmatch: $line" if $verbose_search;
                return $line;
            }
            {
                local $|; $| = 1;
                printf("\r%2.f%%",(100 * $checked / scalar @haystack) ) if $verbose_search;
            }
            $checked++;
        }
    }

return undef;
}


# create a new player object from a mutt alias line (and an echelle file)
# returns a player object or undef and warns about errors
sub new_from_alias {
    my ($class, $line, $echelle_file) = @_;
    my ($name, $email, $niv, $licence);

    if ($line =~ /^alias\s+\S+\s+([^<]*)<(\S*)>(\s*#.*)?/) {
        ($name, $email) = ($1, $2);
        ($niv, $licence) = parse_additional_info($3);
    } else {
        warn("line $.:Illegal: $_\n");
        return undef;
    }

    $name =~ s/\s*$//; # suppress trailing spaces
    $name =~ s/[\\\",]//g; # remove weird characters from Airbus names

    # If there is a registration level, finish extracting it
    if (defined $niv) {
        $niv = stone_to_level $niv;
    }

    my @from_echelle = grep_echelle($echelle_file, $name, $licence);

    if (@from_echelle > 1) {
        warn "Ambiguous name \"$name\":\n @from_echelle\n";
        warn "Try to add licence number to the end of the alias line.\n";
        return undef;
    }
    if (not defined $from_echelle[0]) {
        warn "Not found \"$name\" in echelle -- adding anyway\n";
        # Fake echelle entry
        $niv ||= -1600;
        $from_echelle[0] = "$name    $niv - ------- ----";
    }
    my $player = new_from_ech FFGPlayer $from_echelle[0];
    if (defined $player) {
        $player->email($email);

        $player->level($niv) if (defined $niv);
    }
    return $player;
}

# copy from player
sub new {
    my %r;
    my $class = shift;
    %r = %{$_[0]};
    return bless \%r, $class;
}


sub register_level {
    my ($self, $round, $level) = @_;

    $self->{registering_level}->[$round] = 
        (defined $level ? $level : $self->{registering_level}->[$round]);
}


# True if player has a valid current license
# $licenses: string of letters coding for allowed licenses, e.g. "LC" for normal + loisir (FFG)
sub is_licensed {
    my ($self, $licenses) = @_;

    my (@licenses) = split //, $licenses;

    foreach my $l (@licenses) {
        return 1 if $self->status eq $l;
    }

    return 0;
}

use POSIX;
use GoatLib;
use Carp;

# Renvoie le niveau en pierres: '23k', '2k', '3d' ...
sub stones {
    return level_to_stones($_[0]->level);
}

# Returns a unique id for the player. At first I used License, but sometimes
# that changes (player that becomes licensed after the beginning of the
# tournament) and makes a mess. 
# Then I used email, but we don't always _have_ email (e.g. when parsing
# echelle file)
# Now I'll see with fullname, which may work if echelle garantees uniqueness.
sub id {
    my ($self) = @_;

    my $id = $self->fullname;
    $self->{id} = $id; # Store it in hash so it gets exported in XML dumps
}

# Returns givenname + familyname in one string
sub fullname {
    $_[0]->givenname . " " . $_[0]->familyname;
}

# Returns familyname + givenname in one string (useful for sorting)
sub sortname {
    $_[0]->familyname . " " . $_[0]->givenname;
}

# Returns RF822-style full name and address
sub fulladdress {
    $_[0]->givenname." ".$_[0]->familyname." <".$_[0]->email.">";
}


1;
