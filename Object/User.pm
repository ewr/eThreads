package eThreads::Object::User;

use strict;

#----------

sub new {
	my $class 	= shift;
	my $data 	= shift;
	my $id 		= shift;

	$class = bless ( {
		_			=> $data,
		id			=> $id,
		username	=> undef,
		name		=> undef,
		email		=> undef,
		vemail		=> undef,
		url			=> undef,
		rights		=> undef,
	} , $class );

	return $class;
}

#----------

sub id {
	return shift->{id};
}

#----------

sub username {
	my $class = shift;

	if (!$class->{username}) {
		$class->get_user_info;
	}

	return $class->{username};
}

#----------

sub name {
	my $class = shift;

	if (!$class->{username}) {
		$class->get_user_info;
	}

	return $class->{name};
}

#----------

sub email {
	my $class = shift;

	if (!$class->{username}) {
		$class->get_user_info;
	}

	return $class->{email};
}

#----------

sub vemail {
	my $class = shift;

	if (!$class->{username}) {
		$class->get_user_info;
	}

	return $class->{vemail};
}

#----------

sub url {
	my $class = shift;

	if (!$class->{username}) {
		$class->get_user_info;
	}

	return $class->{url};
}

#----------

sub get_user_info {
	my $class = shift;

	if (!$class->{id}) {
		$class->{_}->core->bail("Can't get user info with no id.");
	}

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			username,name,email,vemail,url
		from 
			" . $class->{_}->core->tbl_name("users") . " 
		where 
			id = ?
	");

	$get->execute($class->{id});

	my ($un,$n,$e,$v,$u);
	$get->bind_columns( \($un,$n,$e,$v,$u) );
	$get->fetch;

	$class->{username}	= $un;
	$class->{name}		= $n;
	$class->{email}		= $e;
	$class->{vemail}	= $v;
	$class->{url}		= $u;

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
