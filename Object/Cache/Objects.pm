package eThreads::Object::Cache::Objects;

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

sub DESTROY {
	my $class = shift;

	%{$class->{objects}} = ();
}

#----------

sub get {
	my $class = shift;
	my $type = shift;
	my $key = shift;

	if (my $obj = $class->{objects}{ $type }{ $key }) {
		return $obj;
	} else {
		return undef;
	}
}

#----------

sub set {
	my $class = shift;
	my $type = shift;
	my $key = shift;
	my $obj = shift;

	$class->{objects}{ $type }{ $key } = $obj;
}

#----------

1;
