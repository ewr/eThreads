package eThreads::Object::Auth;

use strict;

#----------

sub new {
	die "Cannot call Auth object directly\n";
}

#----------


#----------

sub allowed {
	my $class = shift;

	return 1;
}

#----------

1;
