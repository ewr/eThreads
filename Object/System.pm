package eThreads::Object::System;

use Spiffy -Base;

#----------

field '_' => -ro;

sub new {
	my $data = shift;

	$self = bless ( {
		_		=> $data,
	} , $self ); 

	return $self;
}

#----------

sub load {
	my $sys = shift;

	# system objects can hold data, so we can't cache them.  perhaps in the 
	# future it might work to put a little storage area into Glomule::Data, 
	# so that we can let them have scratchpads there.  This will do for now, 
	# but it'll want optimization.

	$self->_->new_object('System::'.$sys,@_);

#	if (my $obj = $self->_->cache->objects->get("systemobj",$sys)) {
#		return $obj;
#	} else {
#		my $obj = $self->_->new_object("System::" . $sys);
#		$self->_->cache->objects->set("systemobj",$sys,$obj);
#		return $obj;
#	}
}

#----------

=head1 NAME

eThreads::Object::System

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
