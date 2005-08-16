package eThreads::Object::Controller::Function;

use Spiffy -Base;

use strict;

#----------

field 'name'	=> -ro;
field 'object'	=> -ro;
field 'system'	=> -ro;
field 'sub'		=> -ro;

sub new {
	my $data = shift;

	$self = bless ( {
		name	=> undef,
		object	=> undef,
		system	=> undef,
		sub		=> undef,
		qopts	=> undef,
		modes	=> undef,
		@_,
		_		=> $data,
	} , $self ); 

	return $self;
}

#----------

sub qopts {
	wantarray ? @{ $self->{qopts} } : $self->{qopts};
}

sub modes {
	wantarray ? @{ $self->{modes} } : $self->{modes};
}

#----------
#----------

package eThreads::Object::Controller::Function::Qopt;

# we use the generic Qopt object as-is
use base 'eThreads::Object::Generic::Qopt';

#----------
#----------

package eThreads::Object::Controller::Function::Mode;

use Spiffy -Base;

field 'name'	=> -ro;
field 'value'	=> -ro;

sub new {
	my $data = shift;

	$self = bless ( {
		name	=> undef,
		value	=> undef,
		@_,
		_		=> $data,
	} , $self ); 

	return $self;
}

sub attributes {
	{
		name	=> $self->{name},
		value	=> $self->{value}
	};
}

#----------

=head1 NAME

eThreads::Object::Controller::Function
eThreads::Object::Controller::Function::Qopt
eThreads::Object::Controller::Function::Mode

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
