#!/usr/bin/perl

use strict;
use warnings;

use lib './lib';
use App::LogEater;


my $logeater = App::LogEater->new({ booger => 'that'});

$logeater->use_config( $logeater->demo );


#$logeater->merge($coderef);



$logeater->eat;


1;