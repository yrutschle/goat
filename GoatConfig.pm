package GoatConfig;

use strict;

use YAML qw/LoadFile/;

require Exporter;

use vars qw/ @EXPORT @ISA/;
@ISA = qw/Exporter/;
@EXPORT=qw/ 
$INSTALL_DIR $WORK_DIR $LOG_DIR $TMP_DIR $SGF_URL

$GOAT_ADDRESS $ADMIN_ADDRESS $TOURNAMENT_NAME $TOURNAMENT_CITY
$TOURNAMENT_LICENSES

$TEMPLATE_DIR

$LOCALE $TIMEZONE

$BIN_MAIL_OUT $BIN_MAIL_IN $BIN_GOAT

CHALLENGED_TIMEOUT SCHEDULED_TIMEOUT
GAME_COMINGUP_TIMEOUT
/;

die "Environment variable GOAT_DIR not set.\n" unless defined $ENV{GOAT_DIR};
die "Environment variable WORK_DIR not set.\n" unless defined $ENV{WORK_DIR};

# Period at which to send reminders of a forgotten challenge
use constant CHALLENGED_TIMEOUT => 7 * 24 * 3600; # 7 days

# Timeout before asking for the results of the game, after
# the game.
use constant SCHEDULED_TIMEOUT => 1 * 24 * 3600; # 1 day

# How early should we remind people about scheduled games?
# (This may need adjusting if you're running the script in the evening)
use constant GAME_COMINGUP_TIMEOUT => 1 * 24 * 3600; # 1 day

# Directory structure. If you followed the suggestion in README,
# you should not need to change anything here.

# Where is goat installed? This will usually be a home
# directory, e.g. /home/goat.
our $INSTALL_DIR = "$ENV{GOAT_DIR}";

my $cfg = LoadFile("$ENV{WORK_DIR}/goat.cfg");
our $GOAT_ADDRESS = $cfg->{goat_address};
our $ADMIN_ADDRESS = $cfg->{admin_address};
our $TOURNAMENT_NAME = $cfg->{tournament_name};
our $TOURNAMENT_CITY = $cfg->{tournament_city};
our $TOURNAMENT_LICENSES= $cfg->{tournament_licenses};
our $LOCALE = $cfg->{locale};
our $TIMEZONE = $cfg->{timezone};
my $template_name = $cfg->{template_name};

our $SGF_URL = $cfg->{sgf_url};


# Directory to get templates for outgoing e-mails
our $TEMPLATE_DIR = "$INSTALL_DIR/$template_name";


# Where to put working files? Typically log/ and tmp/
our $WORK_DIR=$ENV{WORK_DIR};
our $LOG_DIR="$WORK_DIR/log";
our $TMP_DIR="$WORK_DIR/tmp";

# Where are the binaries?
our $BIN_GOAT = "$INSTALL_DIR/goat";
our $BIN_MAIL_IN = "$INSTALL_DIR/mail_in";
our $BIN_MAIL_OUT = "$INSTALL_DIR/mail_out";

# Creates directories if required
foreach my $dir ($WORK_DIR, $LOG_DIR, $TMP_DIR) {
    unless ( -d $dir ) {
        mkdir $dir or die "mkdir $dir: $!\n";
    }
}

1;
