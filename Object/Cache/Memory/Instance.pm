package eThreads::Object::Cache::Memory::Instance;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		objects	=> {},
	} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;

	%{$class->{objects}} = ();

	return 1;
}

#----------

sub set {
	my $class = shift;
	my $type = shift;
	my $key = shift;
	my $obj = shift;

	$class->{_}->core->memcache->set($type,$key,$obj);

	$class->{objects}{ $type }{ $key } = $obj;
}

#----------

sub get {
	my $class = shift;
	my $type = shift;
	my $key = shift;

	if (my $obj = $class->{objects}{ $type }{ $key }) {
		return $obj;
	}

	my $get = $class->{_}->core->memcache->get($type,$key);
	return undef if (!$get);

	my $obj = $class->{_}->instance->new_object($type,%{$get});

	$class->{objects}{ $type }{ $key } = $obj;

	return $obj;
}

#----------

sub set_raw {
	my $class = shift;

	$class->{_}->core->memcache->set_raw(@_);
}

#----------

sub get_raw {
	my $class = shift;

	$class->{_}->core->memcache->get(@_);
}

#----------

1;
