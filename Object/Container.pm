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
		$class->{_}->core->bail("Can't get container name without id");
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
		$class->{_}->core->bail("Can't get container id without name");
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

sub get_default_look {
	my $class = shift;

	my $looks = $class->get_looks;

	$class->bail("Container has no default look") 
		if (!$looks->{DEFAULT});

	if (my $l = $class->{_}->memcache->get("Look",$looks->{DEFAULT}->{id})) {
		return $l;
	} else {
		my $l = $class->{_}->instance->new_object(
			"Look",
			id		=> $looks->{DEFAULT}->{id},
			name	=> $looks->{DEFAULT}->{name},
		);

		$class->{_}->memcache->set("Look",$l->id,$l);

		return $l;
	}
}

#----------

sub get_looks {
	my $class = shift;

	if (my $l = $class->{_}->memcache->get_raw("looks")) {
		return $l->{ $class->id };
	} else {
		my $looks = $class->{_}->cache->load_cache_file(tbl=>"looks");

		if (!$looks) {
			$looks = $class->{_}->instance->cache_looks();
		}

		$class->{_}->memcache->set_raw("looks",undef,$looks);

		return $looks->{ $class->id };
	}
}

#----------

sub determine_look {
	my $class = shift;

	# -- figure out what look we're using -- #

	my $look;

	if (0) {

	} else {
		$look = $class->get_default_look;
	}

	$class->{look} = $look;

	return $look;
}

#----------

1;
