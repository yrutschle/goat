package GoatConfig;

use strict;

require Exporter;

use vars qw/ @EXPORT @ISA/;
@ISA = qw/Exporter/;
@EXPORT=qw/ 
$INSTALL_DIR $WORK_DIR $LOG_DIR $TMP_DIR 

$GOAT_ADDRESS $ADMIN_ADDRESS

$TEMPLATE_DIR

$LOCALE $TIMEZONE

$BIN_MAIL_OUT $BIN_MAIL_IN $BIN_GOAT

CHALLENGED_TIMEOUT SCHEDULED_TIMEOUT
GAME_COMINGUP_TIMEOUT
/;

die "Environment variable GOAT_DIR not set.\n" unless defined $ENV{GOAT_DIR};
die "Environment variable WORK_DIR not set.\n" unless defined $ENV{WORK_DIR};

# Which address receives for Goat?
our $GOAT_ADDRESS = "GO Assistant <goat\@rutschle.net>";

# What is the tournament admin address?
our $ADMIN_ADDRESS = "Yves Rutschle <yves\@rutschle.net>";

# What locale and timezone should be used for date parsing and writing?
our $LOCALE = 'fr_FR';
our $TIMEZONE = 'Europe/Paris';

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

# Directory to get templates for outgoing e-mails
our $TEMPLATE_DIR = "$INSTALL_DIR/fr";


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
