package eThreads::Object::Glomule;

use strict;
use vars qw();

use eThreads::Object::Glomule::Data::Posts;

use eThreads::Object::Glomule::Function;
use eThreads::Object::Glomule::Pref;

use eThreads::Object::Glomule::Type::Admin;
use eThreads::Object::Glomule::Type::Blog;
use eThreads::Object::Glomule::Type::Comments;

#----------

sub new {
	die "Cannot directly load base Glomule Object\n";
}

#----------

sub id {
	my $class = shift;

	if ($class->{id}) {
		return $class->{id};
	} else {
		# -- load glomule headers -- #

		my $gh = $class->{_}->cache->get(
			tbl		=> "glomule_headers",
		);

		if (!$gh) {
			$gh = $class->{_}->instance->cache_glomule_headers();
		}

		if (
			my $r = 
				$gh
					->{name}
					->{ $class->{_}->container->id }
					->{ $class->{name} }
		) {
			$class->{id} = $r->{id};
			return wantarray ? ($r->{id},$r) : $r->{id};
		} else {
			return undef;
		}
	}
}

#----------

sub load_info {
	my $class = shift;

	if (!$class->{name}) {
		# if we don't have a name we're going to skip all of this
		return 1;
	}


	# -- figure out our id -- #

	my ($id,$gh) = $class->id;

	if (!$id) {
		# we need to create our glomule
		$class->initialize;

		# now we get this again, since we're too lazy to get the 
		# object elsewise
		($id,$gh) = $class->id;
	}

	# -- load glomule data -- #

	my $gd = $class->{_}->cache->get(
		tbl		=> "glomule_data",
		first	=> $id,
	);

	if (!$gd) {
		$gd = $class->{_}->instance->cache_glomule_data(
			$id
		);
	}
		
	# -- load these values into our object -- #

	foreach my $h ($gh,$gd) {
		while ( my ($k,$v) = each %$h ) {
			next if ($class->{data}{$k});
			$class->{data}{$k} = $v;
		}
	}

	return 1;
}

#----------

sub initialize {
	my $class = shift;

	# ok, we need to create an entry in glomule_headers and get an id 
	# for our efforts

	my $ins = $class->{_}->core->get_dbh->prepare("
		insert into 
			" . $class->{_}->core->tbl_name("glomule_headers") . "
		(id,container,name,natural_type,parent) 
		values(0,?,?,?,?)
	");

	$ins->execute(
		$class->{_}->container->id,
		$class->{name},
		$class->TYPE,
		0
	) or $class->{_}->bail->("couldn't init glomule: " . $ins->errstr);

	$class->{_}->cache->update_times->set(
		tbl	=> "glomule_headers",
		ts	=> time,
	);

	# -- now create headers tbl -- #

	my $headers = $class->{_}->utils->create_table(
		$class->{_}->utils->get_unused_tbl_name("glomheaders"),
		$class->header_fields
	);

	$class->register_data("headers",$headers);

	# -- now create data tbl -- #

	my $data = $class->{_}->utils->create_table(
		$class->{_}->utils->get_unused_tbl_name("glomdata"),
		$class->_data_tbl_fields,
	);

	$class->register_data("data",$data);

	return 1;
}

#----------

sub register_data {
	my $class = shift;
	my $name = shift;
	my $value = shift;

	$class->{_}->utils->set_value(
		tbl		=> "glomule_data",
		keys	=> {
			ident	=> $name,
			id		=> scalar $class->id,
		},
		value	=> $value,
	);

	$class->{_}->cache->update_times->set(
		tbl		=> "glomule_data",
		first	=> scalar $class->id,
		ts		=> time,
	);

	$class->{data}{ $name } = $value;

	return 1;
}

#----------

sub data {
	my $class = shift;
	my $name = shift;
	#return $class->{$name};
	return $class->{data}{$name};
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

sub register_prefs {
	my $class = shift;
	my $prefs = shift;

	foreach my $p (@$prefs) {
		my $obj = $class->{_}->new_object("Glomule::Pref")->init($p);
		$class->{prefs}{ $p->{name} } = $obj;
	}

	return $class;
}

#----------

sub load_prefs {
	my $class = shift;

	my $core = $class->{_}->core;

	# -- first load glomule-wide prefs -- #

	my $gp = $class->{_}->cache->get(
		tbl		=> "prefs",
		first	=> $class->{id},
	);

	if (!$gp) {
		$gp = $class->cache_glomule_prefs;
	}

	# -- next load look-specific prefs -- #

	my $lp = $class->{_}->cache->get(
		tbl		=> "prefs",
		first	=> $class->{id},
		second	=> $class->{_}->look->id
	);

	if (!$lp) {
		$lp = $class->cache_look_prefs;
	}

	foreach my $ps ($gp,$lp) {
		while ( my ($k,$v) = each %$ps ) {
			my $obj = $class->pref($k);
			next if (!$obj);
			$obj->set($v);
		}
	}

	return $class;
}

#----------

sub pref {
	my $class = shift;
	my $pref = shift;

	return $class->{prefs}{ $pref };
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
	my $where = shift;

	my ($results,$count) = $class->get_from_glomheaders(
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
		tbl		=> $class->data('data'),
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
	my $class = shift;
	my $where = shift;
	my $start = shift;
	my $limit = shift;

	my $count = $class->{_}->core->get_dbh->prepare("
		select 
			count(id) 
		from
			" . $class->data('headers') . "
		where 
			$where
	");

	$count->execute(@_)
		or $class->{_}->bail->("count posts failed: ".$count->errstr);

	my $num_posts = $count->fetchrow_array;

	# now actually get our limited rows

	my $results = $class->get_from_glomheaders(
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
		tbl		=> $class->data('data'),
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
			" . $class->data('headers') . "
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

sub cache_glomule_prefs {
	return {};
}

#----------

sub cache_look_prefs {
	return {};
}

#----------

sub flesh_out_post {
	my $class = shift;
	my $post = shift;

	# fill in and check header fields
	foreach my $h ($class->header_fields,$class->fields) {
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
	my $ipost = shift;
	my %args = @_;

	my $post = {};
	%$post = %$ipost;

	while ( my ($k,$v) = each %args ) {
		$post->{ $k } = $v;
	}

	my $db = $class->{_}->core->get_dbh;

	# now we need to insert (or update) our headers entry.

	my (@hfields,@hvalues);
	foreach my $f (@{$class->header_fields}) {
		next if ($f->{name} eq "id");
		
		push @hfields, $f->{name};
		push @hvalues, $post->{ $f->{name} };
	}
	
	if ($post->{id}) {
		# update

		my $update = $db->prepare("
			update 
				" . $class->data('headers') . " 
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
				" . $class->data('headers') . "
			(" . join(",",@hfields) . ") 
			values(" . join(",",split("","?"x@hfields)) . ")
		");

		$insert->execute(@hvalues) 
			or $class->{_}->bail->("insert post failed: " . $db->errstr);

		# FIXME - this is a MySQL specific hack
		$post->{id} = $db->{'mysql_insertid'};
	}

	# now do data
	foreach my $f (@{ $class->fields }) {
		$class->{_}->utils->set_value(
			tbl		=> $class->data('data'),
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
	my $id = shift;

	# delete from headers
	my $delh = $class->{_}->core->get_dbh->prepare("
		delete from 
			" . $class->data('headers') . "
		where 
			id = ?
	");

	$delh->execute($id)
		or $class->{_}->bail->("delete headers failed: ".$delh->errstr);

	# delete from data
	my $deld = $class->{_}->core->get_dbh->prepare("
		delete from 
			" . $class->data('data') . "
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

	{
		name	=> "id",
		def		=> "int(11) not null auto_increment",
		primary	=> 1,
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

	{
		name	=> "id",
		def		=> "int(11) not null",
		primary	=> 1,
	},
	{
		name	=> "ident",
		def		=> "varchar(20) not null",
		primary	=> 1,
	},
	{
		name	=> "value",
		def		=> "text"
	}

	];
}

#----------

1;
