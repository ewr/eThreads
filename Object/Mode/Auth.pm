package eThreads::Object::Mode::Auth;

@ISA = qw( eThreads::Object::Mode::Normal );

use strict;

#----------

sub go {
	my $class = shift;
	my $r = shift;

	my $user = $class->{_}->auth->authenticate
		or return $class->{_}->auth->unauthorized;

	$class->{_}->switchboard->register("user",$user);

	$class->SUPER::go($r);
}

#----------

1;
