package eThreads::Object::Glomule::Function;

use strict;

sub new {
	my $class 	= shift;
	my $data 	= shift;
	my $glomule = shift;
	my $func 	= shift;

	$class = bless ({
		_			=> $data,
		gholders	=> $glomule->gholders,
		name		=> $func->{name},
		object		=> $func->{object},
		system		=> $func->{system},
		sub			=> $func->{sub},
		qopts		=> $func->{qopts},
		modes		=> $func->{modes},
		g			=> $glomule,
		bucket		=> undef,
	},$class);

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
	undef $class->{g};
	undef $class->{bucket};
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
		my $d;
		if ($q->{is_pref}) {
			$d = $class->glomule->pref( $q->{default} )->get;
		} else {
			$d = $q->{default};
		}

		$bucket->register(%$q,default=>$d);
	}

	# we don't need these any more
	undef $class->{qopts};

	$class->{bucket} = $bucket;

	return $class;
}

#----------

sub bucket {
	my $class = shift;
	return $class->{bucket};
}

#----------

sub glomule { shift->{g} }
sub gholders { shift->{gholders} }

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

	if ($class->{object}) {
		my $obj = $class->{_}->glomule->typeobj($class->{object})
			or $class->{_}->bail->("couldn't get typeobj for $class->{object}");

		my $sub = $class->{sub};

		return $obj->$sub($class,@_);

	} elsif ($class->{system}) {
		my $obj = $class->glomule->system( $class->{system} );
	
		my $sub = $class->{sub};

		return $obj->$sub($class,@_);
	} else {
		$class->{_}->bail->("Can't call function without object or system.");
	}
}

#----------

sub qopts {
	return shift->{qopts};
}

#----------

1;
