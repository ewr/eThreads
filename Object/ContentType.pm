package eThreads::Object::ContentType;

use strict;

#----------

sub new {
	die "Cannot call ContentType object directly\n";
}

#----------

sub type {
	return shift->{type};
}

#----------

1;

