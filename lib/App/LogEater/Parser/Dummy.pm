package App::LogEater::Parser::Dummy;

use strict;
use warnings;



sub parse {
    
    my $string = @_;
    if ($string =~ /logeater/) {
        
        my @data = ( "test1", { user => "logeater"});
        
        return @data;
        
        
    }
    die;
}


1;
