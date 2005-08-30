package eThreads::Object::Container;

use Spiffy -Base;

field '_'		=> -ro;
field 'path' 	=> -ro;
field 'data'	=> -ro, -init=>q!$self->load_data!;

sub new {
	my $data = shift;

	$self = bless({
		_		=> $data,
		id		=> undef,
		name	=> undef,
		path	=> undef,
		@_,
		# etc...
	},$self);

	return $self;
}

#----------

sub cachable {
	return {
		id		=> $self->id,
		path	=> $self->path,
		name	=> $self->name,
	};
}

#----------

sub DESTROY {
	
}

#----------

sub name {
	return $self->{name} if ($self->{name});

	if (!$self->{id}) {
		$self->_->bail->("Can't get container name without id");
	}

	my $db = $self->_->core->get_dbh;

	my $get = $db->prepare("
		select 
			name 
		from 
			" . $self->_->core->tbl_name("containers") . "
		where 
			id = ?
	");

	$get->execute($self->{id});

	$self->{name} = $get->fetchrow_array;

	return $self->{name};
}

#----------

sub id {
	return $self->{id} if ($self->{id});

	if (!$self->{name}) {
		$self->_->bail->("Can't get container id without name");
	}

	my $get = $self->_->core->get_dbh->prepare("
		select 
			id 
		from 
			" . $self->_->core->tbl_name("containers") . "
		where 
			name = ?
	");

	$get->execute($self->{name});

	$self->{id} = $get->fetchrow_array;

	return $self->{id};
}

#----------

sub register_data {
	my $name = shift;
	my $value = shift;

	$self->_->utils->set_value(
		tbl		=> "container_data",
		keys	=> {
			ident	=> "comments",
			id		=> $self->id,
		},
		value	=> $value,
	);

	$self->_->cache->update_times->set(
		tbl		=> "container_data",
		first	=> $self->id,
		ts		=> time,
	);

	$self->{ $name } = $value;

	return 1;
}

#----------

sub load_data {
	my $data = $self->_->cache->get(
		tbl 	=> "container_data",
		first	=> $self->id
	);

	if (!$data) {
		$data = $self->cache_data;
	}

	return $data;
}

#----------

sub cache_data {
	my $data = $self->_->utils->g_load_tbl(
		tbl		=> $self->_->core->tbl_name("container_data"),
		ident	=> "id",
		ids		=> [ $self->id ],
		flat	=> 1,
	);

	$self->_->cache->set(
		tbl		=> "container_data",
		first	=> $self->id,
		ts		=> time,
		ref		=> $data
	);

	return $data;
}

#----------

sub get_default_look {
	my $looks = $self->get_looks;

	$self->_->bail->("Container has no default look") 
		if (!$looks->{DEFAULT});

	my $l = $self->_->new_object(
		"Look",
		id		=> $looks->{DEFAULT}->{id},
		name	=> $looks->{DEFAULT}->{name},
		type	=> $looks->{DEFAULT}->{type}
	);

	return $l;
}

#----------

sub is_valid_look_name {
	my $name = shift;

	my $looks = $self->get_looks;

	if (my $l = $looks->{name}{ $name }) {
		my $obj = $self->_->new_object(
			'Look',
			id		=> $l->{id},
			name	=> $l->{name},
			type	=> $l->{type}
		);
	
		return $obj;
	} else {
		return undef;
	}
}

#----------

sub is_valid_look {
	my $id = shift;

	my $looks = $self->get_looks;

	if (my $l = $looks->{id}{ $id }) {
		my $obj = $self->_->new_object(
			'Look',
			id		=> $l->{id},
			name	=> $l->{name},
			type	=> $l->{type}
		);
	
		return $obj;
	} else {
		return undef;
	}
}

#----------

sub get_looks {
	my $looks = $self->_->cache->get(tbl=>"looks");

	if (!$looks) {
		$looks = $self->_->instance->cache_looks();
	}

	return $looks->{ $self->id };
}

#----------

sub determine_look {
	# -- figure out what look we're using -- #

	my $look = $self->_->raw_queryopts->get('look');

	if ($look && (my $obj = $self->is_valid_look_name($look))) {
		return $obj;
	} else {
		return $self->get_default_look;
	}

	#$self->{look} = $look;

	#return $look;
}

#----------

sub glomule_n2id {
	my $name = shift;

	my $gh = $self->_->glomule->load_headers;

	if ( my $r = $gh->{name}{ $self->id }{ $name } ) {
		return wantarray ? ($r->{id},$r) : $r->{id};
	} else {
		return undef;
	}
}

#----------

sub glomule_id2n {
	my $id = shift;

	my $gh = $self->_->glomule->load_headers;

	if ( my $r = $gh->{container}{ $self->id }{ $id } ) {
		return wantarray ? ($r->{name},$r) : $r->{name};
	} else {
		return undef;
	}
}

#----------

1;
