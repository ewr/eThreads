package eThreads::Object::ContentType::XML;

use eThreads::Object::ContentType -Base;

#----------

field '_' => -ro;

const 'type' => 'text/xml';

sub new {
	my $data = shift;

	$self = bless({
		_		=> $data,
	},$self);

	return $self;
}

#----------

sub activate {


	return $self;
}

#----------

1;

