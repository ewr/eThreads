package eThreads::Object::Standalone;

use eThreads::Object::Core;

use strict;

#----------

sub new {
	my $class = shift;

	$class = bless ( {
		_		=> undef,
		objects	=> undef,
	} , $class ); 

	# connect to core
	my $core = new eThreads::Object::Core;

	# create objects object
	$class->{objects} = eThreads::Object::Objects->new($class);

	# create switchboard object
	my $swb = $class->{switchboard} = new eThreads::Object::Switchboard;
	$class->{_} = $class->{switchboard}->accessors;

	# register our own bail
	$swb->register('bail',sub { 
		sub { $class->bail(@_); } 
	});

	$swb->register('core',$core);
	$swb->register('settings',$core->settings);

	# register objects with switchboard
	$swb->register('objects',$class->{objects});

	# load up the utils object
	$swb->register('utils',sub {
		$class->{_}->new_object('Utils');
	});

	# create cache object
	$class->{cache} 	= $class->{_}->new_object(
		$class->{_}->settings->{cache_obj}
	);
	$swb->register('cache',$class->{cache});

	# create system object
	$swb->register('system',sub {
		$class->{_}->new_object('System');
	});

	# point to core's controller object
	$swb->register('controller',$class->{_}->core->controller);

	return $class;
}

#----------

sub bail {
	my $class = shift;
	my $err = shift;

	my @caller = caller;
	warn "caller: @caller\n";

	die "bail: $err\n";
}

#----------

=head1 NAME

eThreads::Object::Standalone

=head1 SYNOPSIS

=head1 DESCRIPTION


=over 4


=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
