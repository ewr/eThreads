package eThreads::Object::Glomule::Pref;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless({
		_			=> $data,
		name		=> undef,
		allowed		=> undef,
		d_value		=> undef,
		select		=> undef,
		descript	=> undef,
		value		=> undef,
	},$class);

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub init {
	my $class = shift;
	my $hash = shift;

	while ( my ($k,$v) = each %$hash ) {
		$class->{ $k } = $v;
	}

	return $class;
}

#----------

sub get {
	my $class = shift;
	return $class->{value} | $class->{d_value};
}

#----------

sub set {
	my $class = shift;
	my $val = shift;

	if ($val =~ m!$class->{allowed}!) {
		$class->{value} = $val;
		return 1;
	} else {
		# do nothing?
		return undef;
	}
}

#----------

1;
