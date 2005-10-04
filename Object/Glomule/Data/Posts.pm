package eThreads::Object::Glomule::Data::Posts;

use Spiffy -Base;

#----------

field 'posts';
field 'count';

sub new {
	my $data = shift;

	$self = bless ( {
		_		=> $data,
	} , $self ); 

	return $self;
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
