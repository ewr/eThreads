package eThreads::Object::Functions;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		f		=> {},
		_		=> $data,
	} , $class );

	return $class;
}

#----------

sub register {
	my $class = shift;

	foreach my $f (@_) {
		$class->{f}{ $f->{name} } = $f;
	}

	return 1;
}

#----------

sub knows {
	my $class = shift;
	my $func = shift;

	if (my $ref = $class->{f}{ $func }) {
		return $ref;
	} else {
		return undef;
	}
}

#----------

1;
