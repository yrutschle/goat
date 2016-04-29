#! /usr/bin/perl -w

use CGI;
use URI::Escape;
use Encode;

my $q = CGI->new;

my ($sgf) = Encode::decode('UTF-8', uri_unescape $q->param('sgf'));

print $q->header();

print <<EOF;
<!DOCTYPE HTML>
<html>
  <head>
    <title></title>
    <script type="text/javascript" src="wgo/wgo.min.js"></script>
    <script type="text/javascript" src="wgo/wgo.player.min.js"></script>
    <link type="text/css" href="wgo/wgo.player.css" rel="stylesheet" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  </head>
  <body>
    <div data-wgo="$sgf" style="width: 700px">
    Display $sgf<br>
      Sorry, your browser doesn't support WGo.js. Download SGF <a href="$sgf">directly</a>.
    </div>
    <center>
    <a href="$sgf">SGF download</a>
    </center>
  </body>
</html>

EOF
