package GoatConfig;

use strict;

use YAML qw/LoadFile/;
use Getopt::Long;

require Exporter;

use vars qw/ @EXPORT @ISA/;
@ISA = qw/Exporter/;
@EXPORT=qw/ 
$CFG

$TMP_DIR $SGF_DIR $SGF_URL $INDEX_URL

$GOAT_ADDRESS $ADMIN_ADDRESS $TOURNAMENT_NAME $TOURNAMENT_CITY
$TOURNAMENT_LICENSES @PAIRING_CRITERIA
$TOURNAMENT_FILE
$ADMIN_FORWARD

$SUBJECT_PREFIX

$TEMPLATE_DIR

$LOCALE $TIMEZONE

$BIN_MAIL_IN $BIN_GOAT

CHALLENGED_TIMEOUT SCHEDULED_TIMEOUT
GAME_COMINGUP_TIMEOUT
/;

# Period at which to send reminders of a forgotten challenge
use constant CHALLENGED_TIMEOUT => 7 * 24 * 3600; # 7 days

# Timeout before asking for the results of the game, after
# the game.
use constant SCHEDULED_TIMEOUT => 1 * 24 * 3600; # 1 day

# How early should we remind people about scheduled games?
# (This may need adjusting if you're running the script in the evening)
use constant GAME_COMINGUP_TIMEOUT => 1 * 24 * 3600; # 1 day

my ($cfg_file, $cl_cfg_file, $testing);
Getopt::Long::Configure qw/pass_through/;
GetOptions(
    'file=s' => \$cl_cfg_file,
    'test' => \$testing,
);

$cfg_file = $ENV{GOAT_CFG} if defined $ENV{GOAT_CFG};
$cfg_file = $cl_cfg_file if defined $cl_cfg_file;
$cfg_file //= "goat.cfg";
$ENV{GOAT_CFG} = $cfg_file;

my $cfg;

eval {
    $cfg = LoadFile($cfg_file);
};
if ($@) { warn "$cfg_file: $@\n"; return 1 }; # If no configuration, warn and keep going in case user did --help
our $CFG = $cfg;
our $GOAT_ADDRESS = $cfg->{goat_address};
our $ADMIN_ADDRESS = $cfg->{admin_address};
our $ADMIN_FORWARD = $cfg->{admin_forward};
our $SUBJECT_PREFIX = $cfg->{subject_prefix};
our $TOURNAMENT_NAME = $cfg->{tournament_name};
our $TOURNAMENT_FILE = $cfg->{tournament_file};
our $TOURNAMENT_CITY = $cfg->{tournament_city};
our $TOURNAMENT_LICENSES= $cfg->{tournament_licenses};
our @PAIRING_CRITERIA = split /\s+/, $cfg->{pairing_criteria};
our $LOCALE = $cfg->{locale};
our $TIMEZONE = $cfg->{timezone};

our $SGF_URL = $cfg->{sgf_url};
our $INDEX_URL = $cfg->{index_url};

our $TEMPLATE_DIR = $cfg->{template_dir};

our $TMP_DIR=$cfg->{tmp_dir};
our $SGF_DIR=$cfg->{sgf_dir};

$cfg->{testing} = $testing;

# The binaries should be in $PATH
our $BIN_GOAT = "goat";
our $BIN_MAIL_IN = "mail_in";

my ($logvol, $logdir, $logfile) = File::Spec->splitpath($cfg->{logfile});

# Creates directories if required
foreach my $dir ($logdir, $TMP_DIR, $SGF_DIR) {
    unless ( -d $dir ) {
        mkdir $dir or die "mkdir $dir: $!\n";
    }
}

1;
