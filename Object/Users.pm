package eThreads::Object::Users;

use eThreads::Object::Users::User;

use Spiffy -Base;

field '_' => -ro;

field 'headers' => 
	-ro, 
	-init=>q!
		$self->load_headers
			or $self->cache_headers
	!;

#----------

sub new {
	my $data = shift;

	$self = bless { 
		_	=> $data,
	} , $self;

	return $self;
}

#----------

sub is_username {
	( $self->headers->{u}{ shift } ) ? 1 : 0;
}

#----------

sub is_userid {
	my $id = shift;
	( $self->headers->{id}{ $id } ) ? 1 : 0;
}

#----------

sub get_obj_for_user {
	my $id = shift;

	if ( my $obj = $self->_->cache->objects->get('user',$id) ) {
		return $obj;
	} else {
		if ( $self->is_userid( $id ) ) {
			my $obj = $self->_->new_object(
				'Users::User', 
				%{ $self->headers->{id}{ $id } }
			);

			$self->_->cache->objects->set('user',$id,$obj);

			return $obj;
		} else {
			return undef;
		}
	}
}

#----------

sub populate_users_by_id {
	my $users = shift;

	my @data;
	my $pop = {};
	foreach my $u (@$users) {
		next if ( $pop->{ $u } );
		my $obj = $self->get_obj_for_user($u);

		if ( !$obj ) {
			warn "no obj for user $u\n";
			next;
		}

		my $user = $obj->cachable;

		push @data, [ 'users.' . $u , $user ];
		$pop->{ $u } = 1;
	}

	$self->_->gholders->register(@data);

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
			user		=> $u,
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


