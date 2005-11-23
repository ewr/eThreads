package eThreads::Object::Glomule::Function;

use Spiffy -Base;
no warnings;

field '_' => -ro;

field 'bucket' => 
	-init=>q!
		$self->_->queryopts->new_bucket(
			glomule		=> scalar $self->{g}->id,
			function	=> $self->{name},
		);
	!, -ro;

field 'glomule'		=> -key=>'g', -ro;
field 'gholders'	=> -ro;
field 'qopts'		=> -ro;

sub new {
	my $data 	= shift;
	my $glomule = shift;
	my $func 	= shift;

	$self = bless {
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
	} , $self;

	return $self;
}

#----------

sub DESTROY {
	my $self = shift;
	undef $self->{g};
	undef $self->{bucket};
}

#----------

sub activate {
	# -- register qopts -- #

	foreach my $q (@{$self->{qopts}}) {
		my $d;
		if ($q->{is_pref}) {
			$d = $self->glomule->pref( $q->{default} )->get;
		} else {
			$d = $q->{default};
		}

		$self->bucket->register(%$q,default=>$d);
	}

	# we don't need these any more
	undef $self->{qopts};

	return $self;
}

#----------

sub mode {
	my $mode = shift;

	if ($self->{modes}{$mode}) {
		return 1;
	} else {
		return 0;
	}
}

#----------

sub execute {
	if ($self->{object}) {
		my $obj = $self->_->glomule->typeobj($self->{object})
			or $self->_->bail->("couldn't get typeobj for $self->{object}");

		my $sub = $self->{sub};

		return $obj->$sub($self,@_);

	} elsif ($self->{system}) {
		my $obj = $self->glomule->system( $self->{system} );
	
		my $sub = $self->{sub};

		return $obj->$sub($self,@_);
	} else {
		$self->_->bail->("Can't call function without object or system.");
	}
}

#----------

1;
