package eThreads::Object::FakeRequestHandler;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

#	$class->{connection} = $class->{_}->new_object(
#		"FakeRequestHandler::connection"
#	);

	return $class;
}

#----------

sub content_type {
	my $class = shift;
	my $type = shift;

	if (!$class->{_ctype}++) {
		print "Content-type: $type\n\n";
	}

	return 1;
}

#----------

sub print {
	print $_[1];
}

#----------

sub set_last_modified {
	return 1;
}

#----------

package eThreads::Object::FakeRequestHandler::connection;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

=head1 NAME

eThreads::Object::FakeRequestHandler

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
