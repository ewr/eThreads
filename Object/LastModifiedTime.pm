package eThreads::Object::LastModifiedTime;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		objects	=> {},
	} , $class ); 

	return $class;
}

#----------

sub set {
	shift->nominate(@_);
}

#----------

sub nominate {
	my $class = shift;
	my $ts = shift;

	if ($ts > $class->{ts}) {
		$class->{ts} = $ts;
	} else {
		# this vote loses
	}

	return 1;
}

#----------

sub get {
	my $class = shift;

	return $class->{ts};
}

#----------

1;
