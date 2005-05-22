package eThreads::Object::Controller::System;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		name	=> undef,
		object	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub name {
	shift->{name};
}

#----------

sub object {
	shift->{object};
}

#----------

=head1 NAME

eThreads::Object::Controller::System

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
