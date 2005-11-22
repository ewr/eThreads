package eThreads::Object::User;

use Spiffy -Base;

field '_' => -ro;

field 'headers' => 
	-ro, 
	-init=>q!
		$self->load_headers
			or $self->cache_headers
	!;

field '_data' => 
	-ro,
	-init=>q!
		$self->load_data
	!;

field 'id' 			=> -ro;
field 'username' 	=> -ro;

#----------

sub new {
	my $data 	= shift;

	$self = bless ( {
		_			=> $data,
		id			=> undef,
		username	=> undef,
		name		=> undef,
		email		=> undef,
		vemail		=> undef,
		url			=> undef,
		rights		=> undef,
		@_
	} , $self );

	if (!$self->{id}) {
		$self->_->bail->("No id given to User module");
	}

	$self->_validate_user;

	return $self;
}

#----------

sub cachable {
	return {
		id			=> $self->id,
		username	=> $self->username,
		email		=> $self->data("email"),
		vemail		=> $self->data("vemail"),
		url			=> $self->data("url"),
		name		=> $self->data("name"),
	};
}

#----------

sub _validate_user {
	my $user = 
		$self->headers->{id}{ $self->id }
			or $self->_->bail->("Attempted to load user with invalid ID");

	$self->{username} = $user->{username};

	return 1;
}

#----------

sub load_headers {
	$self->_->cache->get(
		tbl	=> 'user_headers'
	);
}

#----------

sub cache_headers {
	my $get = $self->_->core->get_dbh->prepare("
		select 
			id,user,password 
		from 
			" . $self->_->core->tbl_name("user_headers") . " 
	");

	$get->execute();

	my ($id,$u,$p);
	$get->bind_columns( \($id,$u,$p) );

	my $headers = { u => {} , id => {} };
	while ($get->fetch) {
		my $user = {
			id			=> $id,
			username	=> $u,
			password	=> $p,
		};

		$headers->{u}{ $u } = $headers->{id}{ $id } = $user;
	}

	$self->_->cache->set(
		tbl		=> "user_headers",
		ref		=> $headers,
	);

	return $headers;
}

#----------

sub data {
	my $key = shift;

	if (!$self->{data}) {
		$self->get_user_info;
	}

	return $self->{data}{ $key };
}

#----------

sub load_data {
	if ( !$self->id ) {
		$self->_->bail->("Can't get user info with no id.");
	}

	my $user = $self->_->utils->g_load_tbl(
		tbl		=> "user_data",
		ident	=> "id",
		ids		=> [ $self->id ],
		flat	=> 1,
	);

	$self->{data} = $user;

	return $self;
}

#----------

sub has_rights {
	my $type = shift;

	if (!$self->{rights}) {
		$self->get_rights;
	}

	return $self->{rights}{ $type };
}

#----------

sub get_rights {
	# this will most likely need to evolve into some sort of a tree lookup 
	# mechanism so that you can have recursive rights and all that.  for 
	# now, though, we'll just build a tree of the current container and 0.  
	# at whatever point this lookup needs a deeper tree, this is the place 
	# to insert it.

	my @tree = ( '0' , $self->_->container->id );

	my $rights = $self->_->utils->g_load_tbl(
		tbl		=> $self->_->core->tbl_name("rights"),
		ident	=> "container",
		extra	=> "and user=" . $self->{id},
		ids		=> \@tree,
	);

	$self->{rights} = $self->_->utils->g_rec_populate($rights,\@tree);

	return $self;
}

#----------

1;
