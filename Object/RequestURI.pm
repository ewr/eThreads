package eThreads::Object::RequestURI;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	my $u = $ENV{REQUEST_URI};

	# strip off anything after the ?, QueryOpts will get that
	$u =~ s!\?.*!!;

	$class = bless ({
		_		=> $data,
		URI		=> $u,
		_URI	=> $u,
	},$class);

	return $class;
}

#----------

sub claim {
	my $class = shift;
	my $part = shift;

	if (!$part || $part eq "/") {
		return undef;
	}

	$class->{URI} =~ s!^$part!!;

	return 1;
}

#----------

sub unclaimed {
	my $class = shift;
	return $class->{URI};
}

#----------

sub uri {
	my $class = shift;
	return $class->{_URI};
}

#----------

=head1 NAME

eTrevolution::eThreads::Object::RequestURI

=head1 SYNOPSIS

	# new object
	my $r = new eTrevolution::eThreads::Object::RequestURI;

	# get remaining unclaimed URI
	my $uri = $r->unclaimed;

	# claim this off the beginning of URI
	$r->claim("/foo");

	# get the full unaltered URI
	print "uri: " . $r->uri;

=head1 DESCRIPTION

Manages REQUEST_URI, allowing different determinations to be done without 
each step knowing what steps have preceded it.

=over 4

=item new

	my $r = new eTrevolution::eThreads::Object::RequestURI;

Returns a new RequestURI object.  The URI is pulled out of ENV at this time.  
Also, the ? and after is stripped.

=item claim(PART)

	$r->claim("/foo");

Claims a part off the beginning of the managed URI.  Next time someone calls 
unclaimed() this part will be taken out of the returned URI.

=item unclaimed

	my $uri = $r->unclaimed;

Return the unclaimed part of the URI.

=item uri

	print $r->uri;

Return the initial URI (without query string, ie ? and after).

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2004 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.

=cut

1;
