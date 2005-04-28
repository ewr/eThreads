package eThreads::Object::Container;

use strict;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless({
		_		=> $data,
		id		=> undef,
		name	=> undef,
		path	=> undef,
		@_,
		# etc...
	},$class);

	return $class;
}

#----------

sub cachable {
	my $class = shift;
	return {
		id		=> $class->id,
		path	=> $class->path,
		name	=> $class->name,
	};
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub path {
	my $class = shift;
	return $class->{path};
}

#----------

sub name {
	my $class = shift;

	return $class->{name} if ($class->{name});

	if (!$class->{id}) {
		$class->{_}->bail->("Can't get container name without id");
	}

	my $db = $class->{_}->core->get_dbh;

	my $get = $db->prepare("
		select 
			name 
		from 
			" . $class->{_}->core->tbl_name("containers") . "
		where 
			id = ?
	");

	$get->execute($class->{id});

	$class->{name} = $get->fetchrow_array;

	return $class->{name};
}

#----------

sub id {
	my $class = shift;

	return $class->{id} if ($class->{id});

	if (!$class->{name}) {
		$class->{_}->bail->("Can't get container id without name");
	}

	my $get = $class->{_}{db}->prepare("
		select 
			id 
		from 
			" . $class->{_}->core->tbl_name("containers") . "
		where 
			name = ?
	");

	$get->execute($class->{name});

	$class->{id} = $get->fetchrow_array;

	return $class->{id};
}

#----------

sub data {
	my $class = shift;

	if (!$class->{data}) {
		$class->{data} = $class->load_data;
	}

	return $class->{data};
}

#----------

sub register_data {
	my $class = shift;
	my $name = shift;
	my $value = shift;

	$class->{_}->utils->set_value(
		tbl		=> "container_data",
		keys	=> {
			ident	=> "comments",
			id		=> $class->id,
		},
		value	=> $value,
	);

	$class->{_}->cache->update_times->set(
		tbl		=> "container_data",
		first	=> $class->id,
		ts		=> time,
	);

	$class->{ $name } = $value;

	return 1;
}

#----------

sub load_data {
	my $class = shift;

	my $data = $class->{_}->cache->get(
		tbl 	=> "container_data",
		first	=> $class->id
	);

	if (!$data) {
		$data = $class->cache_data;
	}

	return $data;
}

#----------

sub cache_data {
	my $class = shift;

	my $data = $class->{_}->utils->g_load_tbl(
		tbl		=> $class->{_}->core->tbl_name("container_data"),
		ident	=> "id",
		ids		=> [ $class->id ],
		flat	=> 1,
	);

	$class->{_}->cache->set(
		tbl		=> "container_data",
		first	=> $class->id,
		ts		=> time,
		ref		=> $data
	);

	return $data;
}

#----------

sub get_default_look {
	my $class = shift;

	my $looks = $class->get_looks;

	$class->{_}->bail->("Container has no default look") 
		if (!$looks->{DEFAULT});

	my $l = $class->{_}->instance->new_object(
		"Look",
		id		=> $looks->{DEFAULT}->{id},
		name	=> $looks->{DEFAULT}->{name},
	);

	return $l;
}

#----------

sub is_valid_look_name {
	my $class = shift;
	my $name = shift;

	my $looks = $class->get_looks;

	if (my $l = $looks->{name}{ $name }) {
		my $obj = $class->{_}->new_object(
			'Look',
			id		=> $l->{id},
			name	=> $l->{name}
		);
	
		return $obj;
	} else {
		return undef;
	}
}

#----------

sub is_valid_look {
	my $class = shift;
	my $id = shift;

	my $looks = $class->get_looks;

	if (my $l = $looks->{id}{ $id }) {
		my $obj = $class->{_}->new_object(
			'Look',
			id		=> $l->{id},
			name	=> $l->{name}
		);
	
		return $obj;
	} else {
		return undef;
	}
}

#----------

sub get_looks {
	my $class = shift;

	my $looks = $class->{_}->cache->get(tbl=>"looks");

	if (!$looks) {
		$looks = $class->{_}->instance->cache_looks();
	}

	return $looks->{ $class->id };
}

#----------

sub determine_look {
	my $class = shift;

	# -- figure out what look we're using -- #

	my $look = $class->{_}->raw_queryopts->get('look');

	if ($look && (my $obj = $class->is_valid_look_name($look))) {
		return $obj;
	} else {
		return $class->get_default_look;
	}

	#$class->{look} = $look;

	#return $look;
}

#----------

1;
