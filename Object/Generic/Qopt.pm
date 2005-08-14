package eThreads::Object::Generic::Qopt;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		key		=> undef,
		allowed	=> undef,
		persist	=> undef,
		default	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

sub opt 	{ shift->{key} }
sub allowed { shift->{allowed} }
sub persist { shift->{persist} }
sub default { shift->{default} }
sub is_pref { shift->{pref} }

sub attributes {
	my $class = shift;

	{
		opt		=> $class->{key},
		allowed	=> $class->{allowed},
		persist	=> $class->{persist},
		default	=> $class->{default},
		is_pref	=> $class->{pref}
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
