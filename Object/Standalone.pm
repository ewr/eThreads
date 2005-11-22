package eThreads::Object::Standalone;

use eThreads::Object::Core;

use Spiffy -Base;

field '_' => -ro;

#----------

sub new {
	$self = bless ( {
		_		=> undef,
		objects	=> undef,
	} , $self ); 

	# connect to core
	my $core = new eThreads::Object::Core;

	# create objects object
	$self->{objects} = eThreads::Object::Objects->new($self);

	# create switchboard object
	my $swb = $core->_->switchboard->custom;
	$swb->reroute_calls_for($self);

	# register our own bail
	$swb->register('bail',sub { 
		sub { $self->bail(@_); } 
	});

	# register objects with switchboard
	$swb->register('objects',$self->{objects});

	# load up the utils object
	$swb->register('utils',sub {
		$self->_->new_object('Utils');
	});

	# create cache object
	$self->{cache} 	= $self->_->new_object(
		$self->_->settings->{cache_obj}
	);
	$swb->register('cache',$self->{cache});

	# create system object
	$swb->register('system',sub {
		$self->_->new_object('System');
	});

	return $self;
}

#----------

sub bail {
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
