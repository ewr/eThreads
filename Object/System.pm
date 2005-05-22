package eThreads::Object::System;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub load {
	my $class = shift;
	my $sys = shift;

	if (my $obj = $class->{_}->cache->objects->get("systemobj",$sys)) {
		return $obj;
	} else {
		my $obj = $class->{_}->new_object("System::" . $sys);
		$class->{_}->cache->objects->set("systemobj",$sys,$obj);
		return $obj;
	}
}

#----------

=head1 NAME

eThreads::Object::System

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
