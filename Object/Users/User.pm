package eThreads::Object::Users::User;

use Spiffy -Base;

field '_' => -ro;

field '_data' => 
	-ro,
	-init=>q!
		$self->load_data
	!;

field 'id' 			=> -ro;
field 'user'	 	=> -ro;

stub 'write';
stub 'delete';

field 'rights'		=> 
	-ro,
	-init=>q!
		$self->_->new_object('Users::User::Rights',user=>$self);
	!;

#----------

sub new {
	my $data 	= shift;

	$self = bless ( {
		_			=> $data,
		id			=> undef,
		@_
	} , $self );

	if (!$self->{id}) {
		$self->_->bail->("No id given to User module");
	}

	return $self;
}

#----------

sub cachable {
	return {
		id			=> $self->id,
		username	=> $self->user,
		# ( map { $_ => $self->_data->{ $_ } } keys %{ $self->_data } )
	};
}

#----------

sub data {
	my $key = shift;
	return $self->_data->{ $key };
}

#----------

sub load_data {
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
	$self->rights->has( shift );
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
