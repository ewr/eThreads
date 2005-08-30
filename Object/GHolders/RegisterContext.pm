package eThreads::Object::GHolders::RegisterContext;

use Spiffy -Base;

field '_'	=> -ro;
field 'get'	=> -ro, -key=>'ctx';

sub new {
	my $data = shift;

	$self = bless({
		_		=> $data,
		ctx		=> undef,
	} , $self );

	return $self;
}

#----------

sub set {
	my $ctx = shift;

	$ctx .= "." if ($ctx !~ m!\.$!);
	$self->{ctx} = $ctx;

	return $self;
}

#----------

sub register {
	my @f;
	
	if (ref($_[0]) eq "ARRAY") {
		@f = @_;
	} else {
		@f = ([ $_[0] , $_[1] ]);
	}

	foreach my $r (@f) {
		$r->[0] = $self->{ctx} . $r->[0];
	}

	$self->_->gholders->register(@f);
}

#----------
