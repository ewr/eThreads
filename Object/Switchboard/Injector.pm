package eThreads::Object::Switchboard::Injector;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		accessor	=> undef,
		routine		=> undef,
		@_,
		_			=> $data,
	} , $class ); 

	# validate our accessor
	if (my $ref = $class->{_}->knows( $class->{accessor} )) {
		# now validate the routine
		if (ref($ref) eq "CODE" && $ref->can( $class->{routine} )) {
			# we're cool
			$class->{acc_ref} = $ref;
		} else {
			$class->{_}->bail(
				"Invalid routine for $class->{accessor}: $class->{routine}"
			);
		}
	} else {
		$class->{_}->bail->("Invalid accessor: $class->{accessor}");
	}

	return $class;
}

#----------

sub activate {
	my $class = shift;

	return $class;
}

#----------

=head1 NAME

eThreads::Object::Switchboard::Injector

=head1 SYNOPSIS

=head1 DESCRIPTION

What the heck is a switchboard injector?  Well, it's a way for a plugin to 
find its way into a call structure, either replacing a routine or wrapping 
around one.  

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
