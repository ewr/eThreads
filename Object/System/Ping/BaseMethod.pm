package eThreads::Object::System::Ping::BaseMethod;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub url {
	my $class = shift;
	return $class->{url};
}

#----------

sub func {
	my $class = shift;
	return $class->{func};
}

#----------

sub title {
	my $class = shift;
	return $class->{title};
}

#----------

sub local {
	my $class = shift;
	return $class->{local};
}

#----------

sub ping {
	my $class = shift;

	$class->{_}->bail->("Cannot ping directly on base ping object");
}

#----------

1;
