package eThreads::Object::LastModifiedTime;

use Spiffy -Base;

use strict;

#----------

sub new {
	my $data = shift;

	$self = bless ( {
		_		=> $data,
		ts		=> 0,
	} , $self ); 

	return $self;
}

#----------

sub set {
	$self->nominate(@_);
}

#----------

sub nominate {
	my $ts = shift;

	if ($ts > $self->{ts}) {
		$self->{ts} = $ts;
	} else {
		# this vote loses
	}

	return 1;
}

#----------

sub get {
	$self->{ts} || time;
}

#----------

=head1 NAME

eThreads::Object::LastModifiedTime

=head1 SYNOPSIS

	my $lmt = $inst->new_object("LastModifiedTime");

	$lmt->set(ts);
	$lmt->nominate(ts);

	my $ts = $lmt->get;

=head1 DESCRIPTION

Keeps track of the last modified time for an instance.  Content modules can 
nominate modified times, and only the latest is returned.

=over 4

=item new 

Create and return a LastModifiedTime object.

=item nominate 

Nominate a new time.  ts should be unix timestamp.

=item set 

Synonym for nominate.

=item get

Get the time that was greatest out of those nominated.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
