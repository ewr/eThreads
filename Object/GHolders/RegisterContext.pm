package eThreads::Object::GHolders::RegisterContext;

use strict;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless({
		_		=> $data,
		ctx		=> undef,
	} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub set {
	my $class = shift;
	my $ctx = shift;

	$ctx .= "." if ($ctx !~ m!\.$!);
	$class->{ctx} = $ctx;

	return $class;
}

#----------

sub get {
	my $class = shift;
	return $class->{ctx};
}

#----------

sub register {
	my $class = shift;
	
	my @f;
	
	if (ref($_[0]) eq "ARRAY") {
		@f = @_;
	} else {
		@f = ([ $_[0] , $_[1] ]);
	}

	foreach my $r (@f) {
		$r->[0] = $class->{ctx} . $r->[0];
	}

	$class->{_}->gholders->register(@f);
}

#----------

1;
