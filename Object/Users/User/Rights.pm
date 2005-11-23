package eThreads::Object::Users::User::Rights;

use Spiffy -Base;

field '_' => -ro;

#----------

sub new {
	my $data = shift;
	$self = bless {
		_	=> $data,
		@_
	} , $self;
}

#----------

sub has {
	my $type = shift;

	return 1;
}
