package GoatLib;

use locale;
use Pod::Usage;

use Exporter;
use Time::ParseDate;  # This is in Debian's libtime-modules-perl package
use Date::Parse;
use Date::Language;
use DateTime::TimeZone;

@ISA=qw(Exporter);
@EXPORT=qw( stone_to_level level_to_stones download_echelle parse_datestr);

=head2 fixup_frenchisms

Fix up accents in dates, so sloppy French writers can get
away with 'fev' instead of 'fév' etc.

Also change '18h32' to '18:32'

Also change "01/02/2016" to "02/01/2016", which may be
wrong, but there is no better way. DateTime parses US way,
the French do dd/mm/yyyy.

=cut
sub fixup_frenchisms {
    my %fixups = (
        'fevrier'  => 'février',
        'aout'     => 'août',
        'decembre' => 'décembre',
    );
    my ($date) = @_;

    foreach my $k (keys %fixups) {
        my $v = $fixups{$k};
        $date =~ s/$k/$v/; #  Substitute whole words

        $k = substr $k, 0, 3;
        $v = substr $v, 0, 3;
        $date =~ s/$k/$v/; # Substitute 3-letter abbreviations
    }
    $date =~ s/(\d\d)h(\d\d)/$1:$2/;

    # Swap month and day if date in xx/yy/zz format
    my ($d, $m, $rest) = split /\//, $date;
    $date = "$m/$d/$rest" if (defined $m and defined $rest);

    return $date;
}

# get date as string, and return a date
#
sub parse_datestr {
    my ($date_str) = @_;

    $date_str = Encode::decode("utf8", $date_str);

    my $lang = Date::Language->new('French');
    eval {  # str2time and others die on illegal dates: we really don't want that.
        $date_str = fixup_frenchisms $date_str;
        $date = $lang->str2time($date_str);
        # Compute date in UTC using timezone in configuration
        my $tz = DateTime::TimeZone->new(name => $TIMEZONE);
        my $dt = DateTime->from_epoch(epoch => $date);
        $date -= $tz->offset_for_datetime($dt);
        #print "$date\n";
    };
    return $date;
}


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
