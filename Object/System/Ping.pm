package eThreads::Object::System::Ping;

@ISA = qw( eThreads::Object::System );

use strict;

#----------

sub new {
	my $class = shift;
	my $board = shift;

	$class = bless( { 
		@_,
		_	=> $board,
	} , $class );

	if (!$class->{glomule}) {
		$class->{_}->core->bail("No glomule given to Ping object.");
	}

	return $class;
}

#----------

sub ping_all {
	my $class = shift;


}

#----------

1;
