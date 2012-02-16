package App::LogEater;

use 5.006;


use strict;
use warnings;
use Carp;
use Module::Load;
use POE qw( Wheel::FollowTail );
require Exporter;


=head1 NAME

App::LogEater - A very hungry multiple log parsing daemon based on POE

=head1 VERSION

Version 0.001001

=cut

our $VERSION = '0.001001';


=head1 SYNOPSIS


    use App::LogEater;

    my $logeater = App::LogEater->new;
    
    $logeater->use_config($config);


    object 'BoogerHead'
    
    logfile 'BoogerHead:/var/data/logs/messages
    
    module '
    
    
    
    $logeater->eat;


=head1 METHODS

=head2 new

The constructor. Accepts no arguments (this may change).
=cut
sub new {
    my $class = shift;
    #croak "new() needs stuff"                           unless $_[0];
    #croak "Argument passed to new() must be a hashref"  unless (ref $_[0] eq 'HASH');
    #my $self = shift;
    #croak "Missing new({ config => ? }) "               unless exists $self->{config};
    
    my $self = {};    
    bless $self, $class;
    return $self;
}




=head2 eat

Accepts no arguements. Builds all POE sessions and runs.
=cut
sub eat {
    my ($self) = shift;
    $self->_load_config;
    $self->_load_watchers;
    POE::Kernel->run;
}


=head2 demo

Returns a demo configuration hashref. Pass this to use_config for a demonstration.
=cut
sub demo {
    my $self = shift;
    my $demo = {
        objects => {
            Demo => {
                datasources => {
                    ds1 => {
                        parser => {
                            module => 'LogEater::Parser::Dummy',
                            method => 'parse',
                        },
                        logfile => "demo.log",
                        formats => {
                            test1 => {
                                schema => {
                                    resultset => undef,
                                },
                                traps => {
                                    demotrap => {
                                        this => "user",
                                        operator => "eqi",
                                        that => "logeater",
                                    },
                                    reactions => {
                                        demoreact => {
                                            module => "LogEater::Reactions::Dummy",
                                            args => {
                                                message => "[% user %] fell into the trap!",
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
    open(my $fh,'>','demo.log') or die $!;
    return $demo;

}

=head2 use_config
=cut

sub use_config {
    my ($self,$config) = @_;
    $self->{config} = $config;
}

=head1 CONFIGURATION

=head2 overview


objects
    datasources
        formats
            traps
                reactions
                
=over 4

=item * Objects

These are you network objects, or hostnames.

=item * Datasources

A datasource defines what log to watch, and which module to use for parsing

=item * Formats

Each line of the log file that is parsed returns a certain format. Is it a login format? A logout? Formats are defined in the parsing modules

=item * Traps

Things to watch for. A certain user logging in after hours may need some attention.

=item * Reactions

React when your trap caught something ie: send an email.

<objects>
    MyObject
        <datasources>
            MyDatasource
                parser  LogEater::Parser::Dummy
                method _dispatch
                <formats>
                logfile /var/log/messages
                schema 
                <traps>
                    Mytrap
                        this    user
                        operator eqi
                        that    root
                        <reactions>
                            Myreaction
                                type Notification
                                module LogEater::Reactions::Notification::Dummy
                                message Hi there [% user %] was trapped from [% address %]
                        </reactions>
                </traps>
        </datasources>
<objects>
                                
    

=back
=cut

sub _log {
    my ($self,$log) = @_;
    print scalar localtime .": $log\n";
}


sub _load_config {
    
    my ($self) = @_;
    my $config = $self->{config};
    
    croak "Config does not contain any objects"
        unless (exists $config->{objects} && keys %{ $config->{objects} });
    
    my $objects; # build a valid config and return this
    
    
    # Holy crap huge data structure lets go....
    foreach my $object (keys %{ $config->{objects} }) {
            
        my @errors;
        push(@errors, "no datasources")
            unless exists $config->{objects}{$object}{datasources};
            
        push(@errors, "datasource not a hashref")
                unless ref $config->{objects}{$object}{datasources} eq 'HASH';
        
        $self->_log( "Skipping $object:" . join (', ',@errors)) if @errors;
        

        if (!@errors) {
            
            foreach my $datasource (keys %{ $config->{objects}{$object}{datasources}}) {
            
                #
                # Check for the parser
                #
                
                push(@errors,"missing parser")
                    unless exists $config->{objects}{$object}{datasources}{$datasource}{parser};
                
                push(@errors,"parser not a hashref")
                    unless ref $config->{objects}{$object}{datasources}{$datasource}{parser} eq 'HASH';
                    
                push(@errors,"module not defined for parser")
                    unless exists $config->{objects}{$object}{datasources}{$datasource}{parser}{module};
                
                push(@errors,"method not defined for parser")
                    unless exists $config->{objects}{$object}{datasources}{$datasource}{parser}{method};
                
                push(@errors,"invalid method for parser")
                    unless length $config->{objects}{$object}{datasources}{$datasource}{parser}{method};
                    
                $self->_log( "Skipping $object/$datasource: " . join (', ',@errors)) if @errors;
                
                if (!@errors) {
                    my $module = $config->{objects}{$object}{datasources}{$datasource}{parser}{module};
                              
                    eval "use $module; return 1;";
                    push (@errors,"error loading module $module $@") if $@;
                    
                    if (!$@) {
                        # test the method
                        my $method = $config->{objects}{$object}{datasources}{$datasource}{parser}{method};
                        push(@errors,"$module can\'t $method")
                            unless $module->can($method);
                        
                    
            
                    
                        #
                        # Check for logfile
                        #
                               
                        push(@errors,"no logfile specified")
                            unless exists $config->{objects}{$object}{datasources}{$datasource}{logfile};
                
                        push(@errors,"no logfile defined")
                            unless length $config->{objects}{$object}{datasources}{$datasource}{logfile};
                
                        push(@errors,"logfile does not exist")
                            unless -e $config->{objects}{$object}{datasources}{$datasource}{logfile};
                        
                        $self->_log( "Skipping $object/$datasource: " . join (', ',@errors)) if @errors;
                            
                        if (!@errors) {
                            # yay! made it this far, this object is good to go!
                            
                            my $service = join('_',$object,$datasource);
                            $objects->{$service} = {
                                logfile => $config->{objects}{$object}{datasources}{$datasource}{logfile},
                                module  => $config->{objects}{$object}{datasources}{$datasource}{parser}{method},
                                method  => $config->{objects}{$object}{datasources}{$datasource}{parser}{method},
                            };
                
                            $self->_log("$object/$datasource: loaded $module");
            
                        }
                        else {
                
                            next; # is this even vaild here?
                        }
                    }
                }
    
                
            
            }

        }
    }
    
    $self->{objects} = $objects;
    
}

sub _load_watchers {
    my $self = shift;
    
    my $objects = $self->{objects};
    
    foreach my $object (keys %{$objects}) {
    

        POE::Session->create(
            
            inline_states => {
                _start => sub {
                    my $heap = $_[HEAP];
                    my $log_watcher = POE::Wheel::FollowTail->new(
                        Filename => $objects->{$object}{logfile},
                        Filter   => POE::Filter::Line->new(
                            InputLiteral => "\n",
                            OutputLiteral => "\n",
                        ),
                        InputEvent => $object,
                        ResetEvent => "log_reset",
                        ErrorEvent => "log_error",
                    );
                    $heap->{services}{$log_watcher->ID} = $object;
                    $heap->{watchers}{$log_watcher->ID} = $log_watcher;
                    
                },
                $object   => \&_dispatch,
                log_reset => \&_log_reset,
                log_error => \&_log_error,
            }
        );
     
        
    }
    
    
}

sub _dispatch {
    my ($heap,$string) = @_[HEAP,ARG0];
    my $service = $heap->{services}{$_[SESSION]->ID};
    
}
=head1 AUTHOR

Michael Kroher, C<< <infrared at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-logeater at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=LogEater>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc LogEater


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=LogEater>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/LogEater>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/LogEater>

=item * Search CPAN

L<http://search.cpan.org/dist/LogEater/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Michael Kroher.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of LogEater
