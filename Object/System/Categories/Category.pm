package eThreads::Object::System::Categories::Category;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		name	=> undef,
		id		=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	if (!$class->{id} || $class->{name}) {
		$class->{_}->bail->("Improperly initialized category.");
	}

	return $class;
}

#----------

sub activate {
	my $class = shift;


}

#----------

sub id {
	return shift->{id};
}

#----------

sub name {
	return shift->{name};
}

#----------

sub sql {
	my $class = shift;

}

#----------

=head1 NAME

eThreads::Object::System::Categories::Category

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
