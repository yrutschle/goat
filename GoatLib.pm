package GoatLib;

use locale;
use Exporter;
@ISA=qw(Exporter);
@EXPORT=qw( stone_to_level level_to_stones map_game download_echelle);


# Renvoie une valeur numérique correspondant à un niveau en
# pierres
sub stone_to_level {
    my ($niv) = @_;

    return undef if not defined $niv;
    $niv =~ /(\d+)([kd])/i or warn "Illegal level $niv\n" and return undef;

    if (lc $2 eq 'd') {
        return $1 * 100 - 50;
    } else {
        return - ($1 * 100 - 50);
    }
}

# Converts a numeric level to a stone level (1632 => '17K')
sub level_to_stones {
    my ($l) = @_;

    my $level = $l / 100;
    if ($level < 0) {
        $level = - POSIX::floor($level);
        $level .= 'k';
    } else {
        $level = POSIX::ceil($level);
        $level .= 'd';
    }

    return $level;
}

# Download echelle file from ffg site -- if filename already
# exists, delete it
sub download_echelle {
    my ($filename) = @_;

    unlink $filename;
    `wget http://ffg.jeudego.org/echelle/echtxt/ech_ffg_new.txt`;
    return -r $filename;
}

1;
