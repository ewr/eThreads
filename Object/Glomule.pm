package eThreads::Object::Glomule;

use strict;
use vars qw();

use eThreads::Object::Glomule::Data;
use eThreads::Object::Glomule::Data::Posts;

use eThreads::Object::Glomule::Function;
use eThreads::Object::Glomule::Pref;

use eThreads::Object::Glomule::Type::Admin;
use eThreads::Object::Glomule::Type::Blog;
use eThreads::Object::Glomule::Type::Comments;
use eThreads::Object::Glomule::Type::NCManagement;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub load {
	my $class = shift;
	my %a = @_;
	
	# -- make sure type is valid -- #

	my $controller = $class->{_}->controller->get( $a{type} )
		or $class->{_}->bail->("Invalid glomule type: $a{type}");

	my $g = $class->{_}->new_object(
		"Glomule::Data",
		name		=> $a{name},
		type		=> $a{type},
		controller	=> $controller,
	)->activate;

	return $g;
}

#----------

sub typeobj {
	my $class = shift;
	my $type = shift;

	if (my $obj = $class->{_}->cache->objects->get('glomuletype',$type)) {
		return $obj;
	} else {
		my $c = $class->{_}->controller->get($type)
			or return undef;
	
		my $obj = $class->{_}->new_object(
			"Glomule::Type::" . $c->object
		);

		$class->{_}->cache->objects->set('glomuletype',$type,$obj);

		return $obj;
	}
	
}

#----------

sub connect_to_gholders {
	my $class = shift;
	my $gholders = shift;

	$class->{gholders} = $gholders;

	return 1;
}

#----------

sub gholders {
	my $class = shift;
	return $class->{gholders};
}

#----------

sub functions {
	my $class = shift;

	if (!$class->{f}) {
		$class->{f} = $class->{_}->new_object(
			"Functions::Glomule"
		);
	}

	return $class->{f};
}

#----------

sub register_functions {
	my $class = shift;
	$class->functions->register(@_);
}

#----------

sub is_function {
	my $class = shift;
	my $func = shift;

	$class->functions->knows($func);
}

#----------

sub load_pings {
	my $class = shift;

	my $obj = $class->{_}->new_object(
		"System::Ping"
	);

	return $obj;
}

#----------

sub posts_generic {
	my $class = shift;
	my $fobj = shift;
	my $where = shift;

	my ($results,$count) = $class->get_from_glomheaders(
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

	my $data = $class->{_}->utils->g_load_tbl(
		tbl		=> $fobj->glomule->data('data'),
		ident	=> "id",
		ids		=> \@ids,
	);

	while ( my ($id,$d) = each %$data ) {
		while ( my ($k,$v) = each %$d ) {
			$posts->{$id}{$k} = $v if (!$posts->{$id}{$k});
		}
	}

	my $obj = $class->{_}->new_object("Glomule::Data::Posts");
	$obj->posts($results);
	$obj->count($count);

	return $obj;
}

#----------

sub posts_generic_w_limit {
	my $class 	= shift;
	my $fobj 	= shift;
	my $where 	= shift;
	my $start 	= shift;
	my $limit 	= shift;

	my $count = $class->{_}->core->get_dbh->prepare("
		select 
			count(id) 
		from
			" . $fobj->glomule->data('headers') . "
		where 
			$where
	");

	$count->execute(@_)
		or $class->{_}->bail->("count posts failed: ".$count->errstr);

	my $num_posts = $count->fetchrow_array;

	# now actually get our limited rows

	my $results = $class->get_from_glomheaders(
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

	my $data = $class->{_}->utils->g_load_tbl(
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

	my $obj = $class->{_}->switchboard->new_object("Glomule::Data::Posts");

	$obj->posts($results);
	$obj->count($num_posts);

	return $obj;
}

#----------

sub get_from_glomheaders {
	my $class = shift;
	my $fobj = shift;
	my $sql = shift;
	# the rest of @_ should be bind vars

	my $get = $class->{_}->core->get_dbh->prepare("
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
		or $class->{_}->bail->("get_from_gh failed: " . $get->errstr);

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
	my $class = shift;
	my $post = shift;
	my %a = @_;

	my $h_fields = $a{h_fields} || $class->header_fields;
	my $d_fields = $a{d_fields} || $class->fields;

	# fill in and check header fields
	foreach my $h ($h_fields,$d_fields) {
		foreach my $f (@{ $h }) {
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
	my $class = shift;
	my $fobj = shift;
	my $ipost = shift;
	my %args = @_;

	# allow for some special usage
	my $headers 	= $args{headers}	|| $fobj->glomule->data('headers');
	my $data 		= $args{data} 		|| $fobj->glomule->data('data');
	my $h_fields	= $args{h_fields} 	|| $class->header_fields;
	my $d_fields	= $args{d_fields} 	|| $class->fields;

	my $post = {};
	%$post = %$ipost;

	while ( my ($k,$v) = each %args ) {
		next if ($k =~ m!^(?:headers|data|h_fields|d_fields)$!);
		$post->{ $k } = $v;
	}

	my $db = $class->{_}->core->get_dbh;

	# now we need to insert (or update) our headers entry.

	my (@hfields,@hvalues);
	foreach my $f (@$h_fields) {
		next if ($f->{name} eq "id" || $f->{KEYS});

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
			or $class->{_}->bail->("update post failure: " . $db->errstr);
	} else {
		# insert 

		my $insert = $db->prepare("
			insert into 
				" . $headers . "
			(" . join(",",@hfields) . ") 
			values(" . join(",",split("","?"x@hfields)) . ")
		");

		$insert->execute(@hvalues) 
			or $class->{_}->bail->("insert post failed: " . $db->errstr);

		# FIXME - this is a MySQL specific hack
		$post->{id} = $db->{'mysql_insertid'};
	}

	# now do data
	foreach my $f (@$d_fields) {
		$class->{_}->utils->set_value(
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
	my $class = shift;
	my $fobj = shift;
	my $id = shift;

	# delete from headers
	my $delh = $class->{_}->core->get_dbh->prepare("
		delete from 
			" . $fobj->glomule->data('headers') . "
		where 
			id = ?
	");

	$delh->execute($id)
		or $class->{_}->bail->("delete headers failed: ".$delh->errstr);

	# delete from data
	my $deld = $class->{_}->core->get_dbh->prepare("
		delete from 
			" . $fobj->glomule->data('data') . "
		where 
			id = ?
	");

	$deld->execute($id)
		or $class->{_}->bail->("delete data failed: ".$deld->errstr);

	return 1;
}

#----------

sub edit_fields {
	my $class = shift;

	my $fields = [];

	foreach my $f (@{ $class->header_fields }) {
		push @$fields, $f if ($f->{edit});
	}

	foreach my $f (@{ $class->fields }) {
		push @$fields, $f if ($f->{edit});
	}

	return $fields;
}

#----------

sub header_fields {
	my $class = shift;

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
			( $class->{_}->switchboard->knows("user") 
				? $class->{_}->user->id
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
	my $class = shift;
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
