package eThreads::Object::Functions;

use strict;

use eThreads::Object::Functions::Glomule;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		f		=> {},
		@_,
		_		=> $data,
	} , $class );

	return $class;
}

#----------

sub register {
	my $class = shift;

	foreach my $f (@_) {
		$class->{f}{ $f->{name} } = $f;
	}

	return 1;
}

#----------

sub knows {
	return $_[0]->{f}{ $_[1] } || undef;
}

#----------

=head1 NAME

eThreads::Object::Functions

=head1 SYNOPSIS

	my $funcs = $inst->new_object("Functions");

	$funcs->register(
		{
			name	=> "main",
			sub		=> sub { $class->f_main(@_); },
		}
	);

	if (my $f = $funcs->knows("main")) {
		$f->{sub}->();
	}

=head1 DESCRIPTION

Functions acts as a lookup table.  You create a functions object, register 
your calls with it, and then have a consistant interface for checking if a 
call exists, etc.

=over 4

=item new

Create a new function map.

=item register

	$funcs->register(
		{
			name	=> "main",
			sub		=> sub { $class->f_main(@_); },
		}
	);

Register a function into the map.  You must pass in a hash ref, and one of 
the keys must be name. 

=item knows

	if (my $f = $funcs->knows("main")) {
		$f->{sub}->();
	}

If the function has been registered, return the originally registered hash 
ref.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
