package eThreads::Object::Generic::Qopt;

use Spiffy -Base;

use strict;

#----------

field 'opt'		=> -key=>'key',-ro;
field 'allowed'	=> -ro;
field 'persist'	=> -ro;
field 'default'	=> -ro;
field 'is_pref'	=> -ro;

sub new {
	my $data = shift;

	$self = bless ( {
		key		=> undef,
		allowed	=> undef,
		persist	=> undef,
		default	=> undef,
		@_,
		_		=> $data,
	} , $self ); 

	return $self;
}

sub attributes {
	{
		opt		=> $self->{key},
		allowed	=> $self->{allowed},
		persist	=> $self->{persist},
		default	=> $self->{default},
		is_pref	=> $self->{pref}
	};
}

#----------

=head1 NAME

eThreads::Object::Generic::Qopt

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
