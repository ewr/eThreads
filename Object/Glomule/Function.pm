package eThreads::Object::Glomule::Function;

use strict;

sub new {
	my $class 	= shift;
	my $data 	= shift;
	my $glomule = shift;
	my $func 	= shift;

	$class = bless ({
		_		=> $data,
		name	=> $func->{name},
		sub		=> $func->{sub},
		qopts	=> $func->{qopts},
		modes	=> $func->{modes},
		g		=> $glomule,
		type	=> ref($glomule),
		bucket	=> undef,
	},$class);

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
	undef $class->{sub};
}

#----------

sub activate {
	my $class = shift;

	# -- create a new qopt bucket -- #

	my $bucket = $class->{_}->queryopts->new_bucket(
		glomule		=> $class->{g}->id,
		function	=> $class->{name},
	);

	# -- register qopts -- #

	foreach my $q (@{$class->{qopts}}) {
		$bucket->register(%$q);
	}

	$class->{bucket} = $bucket;

	return $class;
}

#----------

sub bucket {
	my $class = shift;
	return $class->{bucket};
}

#----------

sub mode {
	my $class = shift;
	my $mode = shift;

	if ($class->{modes}{$mode}) {
		return 1;
	} else {
		return 0;
	}
}

#----------

sub execute {
	my $class = shift;
	return $class->{sub}->($class,@_);
}

#----------

sub qopts {
	return shift->{qopts};
}

#----------

1;
