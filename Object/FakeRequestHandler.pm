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

	$class->{headers_out} = $class->{_}->new_object(
		"FakeRequestHandler::headers_out"
	);

	return $class;
}

#----------

sub content_type {
	my $class = shift;
	my $type = shift;

	$class->{_ctype} = $type;
#	if (!$class->{_ctype}++) {
#		print "Content-type: $type\n\n";
#	}

	return 1;
}

#----------

sub custom_response {
	my $class = shift;
	my $status = shift;
	my $err = shift;

	if (!$class->{_ctype}) {
		$class->{_ctype} = "text/html";
	}

	$class->print($err);

#	warn "error: $err\n";
}

#----------

sub print {
	my $class = shift;

	if (!$class->{_status}++) {
		print "Content-type: " . ( $class->{_ctype} || "text/html" ) . "\n";
		foreach my $h (@{$class->headers_out->get}) {
			print $h . "\n";
		}

		print "\n";
	}

	print @_;
}

#----------

sub set_last_modified {
	return 1;
}

#----------

sub headers_out {
	return shift->{headers_out};
}

#----------

package eThreads::Object::FakeRequestHandler::headers_out;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		headers	=> [],
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub set {
	my $class = shift;

	push @{ $class->{headers} } , "$_[0]: $_[1]";

	return 1;
}

#----------

sub get {
	my $class = shift;

	return $class->{headers};
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
