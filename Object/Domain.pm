package eThreads::Object::Domain;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		id		=> undef,
		domain	=> undef,
		path	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub id {
	my $class = shift;

	if ($_[0]) {
		$class->{id} = $_[0];
	}

	return $class->{id};
}

#----------

sub domain {
	my $class = shift;

	if ($_[0]) {
		$class->{domain} = $_[0];
	}

	return $class->{domain};
}

#----------

sub path {
	my $class = shift;

	if ($_[0]) {
		$class->{path} = $_[0];
	}

	return $class->{path};
}

#----------

=head1 NAME

eThreads::Object::

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
