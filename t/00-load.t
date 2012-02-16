#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::LogEater' ) || print "Bail out!\n";
}

diag( "Testing App::LogEater $App::LogEater::VERSION, Perl $], $^X" );
