package eThreads::Object::Glomule::Type;

use Spiffy -Base;

#----------

field '_'			=> -ro;

field 'pings'		=> 
	-ro,
	-init=>q!$self->_->new_object('System::Ping')!;

sub new {
	my $data = shift;

	$self = bless( { 
		_		=> $data,
	} , $self);

	return $self;
}

#----------

sub load_pings {
	$self->pings;
}

#----------

sub posts_generic {
	my $fobj = shift;
	my $where = shift;

	my ($results,$count) = $self->get_from_glomheaders(
		$fobj,
		$where,
		@_
	);

	my $posts = {};

	# if we didn't get anything, short-circuit here
	return undef 
		if (!$count);

	my @ids = map { $_->{id} } @$results;
	%$posts = map { $_->{id} => $_ } @$results; 
	
	# -- now get post data -- #

	my $data = $self->_->utils->g_load_tbl(
		tbl		=> $fobj->glomule->data('data'),
		ident	=> "id",
		ids		=> \@ids,
	);

	while ( my ($id,$d) = each %$data ) {
		while ( my ($k,$v) = each %$d ) {
			$posts->{$id}{$k} = $v if (!$posts->{$id}{$k});
		}
	}

	my $obj = $self->_->new_object("Glomule::Data::Posts");
	$obj->posts($results);
	$obj->count($count);

	return $obj;
}

#----------

sub posts_generic_w_limit {
	my $fobj 	= shift;
	my $where 	= shift;
	my $start 	= shift;
	my $limit 	= shift;

	my $count = $self->_->core->get_dbh->prepare("
		select 
			count(id) 
		from
			" . $fobj->glomule->data('headers') . "
		where 
			$where
	");

	$count->execute(@_)
		or $self->_->bail->("count posts failed: ".$count->errstr);

	my $num_posts = $count->fetchrow_array;

	# now actually get our limited rows

	my $results = $self->get_from_glomheaders(
		$fobj,
		$where
		. " limit " 
		. $start
		. ","
		. $limit,
		@_
	);

	my $posts = {};

	my @ids = map { $_->{id} } @$results;
	%$posts = map { $_->{id} => $_ } @$results; 
	
	# -- now get post data -- #

	my $data = $self->_->utils->g_load_tbl(
		tbl		=> $fobj->glomule->data('data'),
		ident	=> "id",
		ids		=> \@ids,
	);

	while ( my ($id,$d) = each %$data ) {
		while ( my ($k,$v) = each %$d ) {
			$posts->{$id}{$k} = $v if (!$posts->{$id}{$k});
		}
	}

	# -- now return this as an object -- #

	my $obj = $self->_->switchboard->new_object("Glomule::Data::Posts");

	$obj->posts($results);
	$obj->count($num_posts);

	return $obj;
}

#----------

sub get_from_glomheaders {
	my $fobj = shift;
	my $sql = shift;
	# the rest of @_ should be bind vars

	my $get = $self->_->core->get_dbh->prepare("
		select 
			id,
			title,
			timestamp,
			parent,
			status,
			user
		from 
			" . $fobj->glomule->data('headers') . "
		where 
			$sql
	");

	$get->execute(@_) 
		or $self->_->bail->("get_from_gh failed: " . $get->errstr);

	my $count = $get->rows;

	my ($id,$tit,$tim,$p,$s,$u);
	$get->bind_columns( \($id,$tit,$tim,$p,$s,$u) );

	my $posts = [];
	while ($get->fetch) {
		my $post = {
			id			=> $id,
			title		=> $tit,
			timestamp	=> $tim,
			parent		=> $p,
			status		=> $s,
			user		=> $u
		};

		push @$posts, $post;
	}

	return wantarray ? ($posts,$count) : $posts;
}

#----------

sub flesh_out_post {
	my $post = shift;
	my %a = @_;

	my $h_fields = $a{h_fields} || $self->header_fields;
	my $d_fields = $a{d_fields} || $self->fields;

	# fill in and check header fields
	foreach my $h ($h_fields,$d_fields) {
		foreach my $f (@{ $h }) {
			next if ($f->{KEYS});

			if ($f->{require} && $post->{ $f->{name} } !~ /\S/) {
				return (0,"Missing required field: $f->{name}");
			}

			if (!$post->{ $f->{name} }) {
				$post->{ $f->{name} } = $f->{d_value};
			}
		}
	}

	return 1;
}

#----------

sub post {
	my $fobj = shift;
	my $ipost = shift;
	my %args = @_;

	# allow for some special usage
	my $headers 	= $args{headers}	|| $fobj->glomule->data('headers');
	my $data 		= $args{data} 		|| $fobj->glomule->data('data');
	my $h_fields	= $args{h_fields} 	|| $self->header_fields;
	my $d_fields	= $args{d_fields} 	|| $self->fields;

	my $post = {};
	%$post = %$ipost;

	while ( my ($k,$v) = each %args ) {
		next if ($k =~ m!^(?:headers|data|h_fields|d_fields)$!);
		$post->{ $k } = $v;
	}

	# -- Here we run through our post hooks -- #

	{
		my $h = $fobj->glomule->posthooks;

		$h->run( $post , $self )
			or $self->_->bail->( 'Denied by PostHook: ' . $h->msg );
	}

	# -- Now proceed to posting -- #

	my $db = $self->_->core->get_dbh;

	# now we need to insert (or update) our headers entry.

	my (@hfields,@hvalues);
	foreach my $f (@$h_fields) {
		next if ($f->{KEYS} || $f->{name} eq "id");

		push @hfields, $f->{name};
		push @hvalues, $post->{ $f->{name} };
	}
	
	if ($post->{id}) {
		# update

		my $update = $db->prepare("
			update 
				" . $headers . " 
			set 
				" . join("=\?,",@hfields) . "=? 
			where 
				id = ?
		");

		$update->execute(@hvalues,$post->{id}) 
			or $self->_->bail->("update post failure: " . $db->errstr);
	} else {
		# insert 

		my $insert = $db->prepare("
			insert into 
				" . $headers . "
			(" . join(",",@hfields) . ") 
			values(" . join(",",split("","?"x@hfields)) . ")
		");

		$insert->execute(@hvalues) 
			or $self->_->bail->("insert post failed: " . $db->errstr);

		# FIXME - this is a MySQL specific hack
		$post->{id} = $db->{'mysql_insertid'};
	}

	# now do data
	foreach my $f (@$d_fields) {
		$self->_->utils->set_value(
			tbl		=> $data,
			keys	=> {
				id		=> $post->{id},
				ident	=> $f->{name},
			},
			value	=> $post->{ $f->{name} },
			set_zero_value	=> 1,
		);
	}

	return $post;
}

#----------

sub delete {
	my $fobj = shift;
	my $id = shift;

	# delete from headers
	my $delh = $self->_->core->get_dbh->prepare("
		delete from 
			" . $fobj->glomule->data('headers') . "
		where 
			id = ?
	");

	$delh->execute($id)
		or $self->_->bail->("delete headers failed: ".$delh->errstr);

	# delete from data
	my $deld = $self->_->core->get_dbh->prepare("
		delete from 
			" . $fobj->glomule->data('data') . "
		where 
			id = ?
	");

	$deld->execute($id)
		or $self->_->bail->("delete data failed: ".$deld->errstr);

	return 1;
}

#----------

sub edit_fields {
	my $fields = [];

	foreach my $f (@{ $self->header_fields }) {
		push @$fields, $f if ($f->{edit});
	}

	foreach my $f (@{ $self->fields }) {
		push @$fields, $f if ($f->{edit});
	}

	return $fields;
}

#----------

sub create_tables {
	my $dataobj = shift;

	if ( !$dataobj ) {
		$self->_->bail->('Unable to create tables without data object.');
	}

	# -- create headers tbl -- #

	my $headers = $self->_->utils->create_table(
		$self->_->utils->get_unused_tbl_name("glomheaders"),
		$self->header_fields
	);

	$dataobj->register_data("headers",$headers);

	# -- now create data tbl -- #

	my $data = $self->_->utils->create_table(
		$self->_->utils->get_unused_tbl_name("glomdata"),
		$self->_data_tbl_fields,
	);

	$dataobj->register_data("data",$data);
}

#----------

sub header_fields {
	return [

	{ KEYS => [
		'primary key(id)'
	] },
	{
		name	=> "id",
		def		=> "int(11) not null auto_increment",
		allowed	=> '\d+',
		d_value	=> 0,
	},
	{
		name	=> "title",
		def		=> "varchar(100) not null",
		allowed	=> '.*',
		require	=> 1,
		edit	=> 1,
	},
	{
		name	=> "parent",
		def		=> "int(11) not null",
		allowed	=> '\d+',
		d_value	=> 0,
	},
	{
		name	=> "timestamp",
		def		=> "int(11) not null",
		allowed	=> '\d+',
		d_value	=> time,
	},
	{
		name	=> "user",
		def		=> "int(11)",
		allowed	=> '\d+',
		d_value	=> 
			( $self->_->switchboard->knows("user") 
				? $self->_->user->id
				: 0 ),
		require	=> 0,
	},
	{
		name	=> "status",
		def		=> "tinyint not null",
		allowed	=> '\d+',
		d_value	=> 0,
	},

	];
}

#----------

sub _data_tbl_fields {
	return [

	{ KEYS => [
		'primary key(id,ident)'
	] },
	{
		name	=> "id",
		def		=> "int(11) not null",
	},
	{
		name	=> "ident",
		def		=> "varchar(20) not null",
	},
	{
		name	=> "value",
		def		=> "text"
	}

	];
}

#----------

1;
