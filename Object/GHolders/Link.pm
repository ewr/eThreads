package eThreads::Object::GHolders::Link;

use eThreads::Object::GHolders::GHolder -Base;

field '_' => -ro;
field 'linkpath';
field 'linkedgh'	=> 
	-ro,
	-init=>q!
		$self->find_linked_gh;
	!;

stub 'flat';
stub 'sub';
stub 'array';

sub new {
	my $data = shift;
	my $key = shift;
	my $path = shift;

	$self = bless({
		_			=> $data,
		key			=> $key || undef,
		parent		=> undef,
		children	=> {},
	} , $self);

	if ( $path ) {
		$self->{linkpath} = $path;
	}

	return $self;
}

#----------

sub add_child {
	$self->_->bail->('Unable to add child to Link GHolder');
}

#----------

sub has_child {
	if ( my $l = $self->linkedgh ) {
		$l->has_child($_[0]);
	} else {
		return undef;
	}
}

#----------

sub find_linked_gh {
	if ( !$self->linkpath ) {
		$self->_->bail->('Unable to use link GHolder without linkpath.');
	}

	if ( my $gh = $self->_->gholders->exists( $self->linkpath ) ) {
		return $gh;
	} else {
		return undef;
	}
}
