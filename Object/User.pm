package eThreads::Object::User;

use strict;

#----------

sub new {
	my $class 	= shift;
	my $data 	= shift;

	$class = bless ( {
		_			=> $data,
		id			=> undef,
		username	=> undef,
		name		=> undef,
		email		=> undef,
		vemail		=> undef,
		url			=> undef,
		rights		=> undef,
		@_
	} , $class );

	if (!$class->{id}) {
		$class->{_}->core->bail("No id given to User module");
	}

	$class->_validate_user;

	return $class;
}

#----------

sub cachable {
	my $class = shift;
	return {
		id			=> $class->id,
		username	=> $class->username,
		email		=> $class->data("email"),
		vemail		=> $class->data("vemail"),
		url			=> $class->data("url"),
		name		=> $class->data("name"),
	};
}

#----------

sub _validate_user {
	my $class = shift;

	my $headers = $class->{_}->cache->get(
		tbl		=> "user_headers",
	);

	if (!$headers) {
		$headers = $class->{_}->instance->cache_user_headers;
	}

	my $ref = $headers->{id}{ $class->id };

	if (!$ref) {
		$class->{_}->core->bail("Invalid id given to User");
	}

	$class->{username} = $ref->{username};

	return 1;
}

#----------

sub id {
	return shift->{id};
}

#----------

sub username {
	return shift->{username};
}

#----------

sub data {
	my $class = shift;
	my $key = shift;

	if (!$class->{data}) {
		$class->get_user_info;
	}

	return $class->{data}{ $key };
}

#----------

sub get_user_info {
	my $class = shift;

	if (!$class->{id}) {
		$class->{_}->core->bail("Can't get user info with no id.");
	}

	my $user = $class->{_}->core->g_load_tbl(
		tbl		=> "user_data",
		ident	=> "id",
		ids		=> [ $class->{id} ],
		flat	=> 1,
	);

	$class->{data} = $user;

	return $class;
}

#----------

sub has_rights {
	my $class = shift;
	my $type = shift;

	if (!$class->{rights}) {
		$class->get_rights;
	}

	return $class->{rights}{ $type };
}

#----------

sub get_rights {
	my $class = shift;

	# this will most likely need to evolve into some sort of a tree lookup 
	# mechanism so that you can have recursive rights and all that.  for 
	# now, though, we'll just build a tree of the current container and 0.  
	# at whatever point this lookup needs a deeper tree, this is the place 
	# to insert it.

	my @tree = ( '0' , $class->{_}->container->id );

	my $rights = $class->{_}->core->g_load_tbl(
		tbl		=> $class->{_}->core->tbl_name("rights"),
		ident	=> "container",
		extra	=> "and user=" . $class->{id},
		ids		=> \@tree,
	);

	$class->{rights} = $class->{_}->core->g_rec_populate($rights,\@tree);

	return $class;
}

#----------

1;
