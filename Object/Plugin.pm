package eThreads::Object::Plugin;

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

#----------

1;
