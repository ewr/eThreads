package eThreads::Object::Glomule::Data::Posts;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		posts	=> undef,
		count	=> undef,
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub posts {
	my $class = shift;
	@_ and $class->{posts} = shift;
	return $class->{posts};
}

#----------

sub count {
	my $class = shift;
	@_ and $class->{count} = shift;
	return $class->{count};
}

#----------

=head1 NAME

eThreads::Object::Glomule::Data::Posts

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
