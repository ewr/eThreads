package eThreads::Object::Glomule;

use strict;
use vars qw();

#----------

sub new {
	die "Cannot directly load base Glomule Object\n";
}

#----------

sub id {
	my $class = shift;
	return $class->{id};
}

#----------

sub load_info {
	my $class = shift;

	# -- load glomule headers -- #

	my $gh = $class->{_}->cache->get(
		tbl		=> "glomule_headers",
	);

	if (!$gh) {
		$gh = $class->{_}->instance->cache_glomule_headers();
	}

	# -- figure out our id -- #

	my $ghobj;
	if (!$class->{id}) {
		if (my $r = $gh->{name}{$class->{_}->container->id}{$class->{name}}) {
			$ghobj = $r;
		} else {
			$class->{_}->bail->("Invalid Glomule: $class->{name}");
		}
	}

	# -- load glomule data -- #

	my $gd = $class->{_}->cache->get(
		tbl		=> "glomule_data",
		first	=> $ghobj->{id},
	);

	if (!$gd) {
		$gd = $class->{_}->instance->cache_glomule_data(
			$ghobj->{id}
		);
	}
		
	# -- load these values into our object -- #

	foreach my $h ($ghobj,$gd) {
		while ( my ($k,$v) = each %$h ) {
			next if ($class->{$k});
			$class->{$k} = $v;
		}
	}

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
			ident	=> "comments",
			id		=> $class->id,
		},
		value	=> $value,
	);

	$class->{_}->cache->update_times->set(
		tbl		=> "glomule_data",
		first	=> $class->id,
		ts		=> time,
	);

	$class->{ $name } = $value;

	return 1;
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
		$class->{f} = $class->{_}->switchboard->new_object(
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
		my $obj = $class->{_}->instance->new_object("Glomule::Pref")->init($p);
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

	my $obj = $class->{_}->instance->new_object(
		"System::Ping"
	);

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
			" . $class->{headers} . "
		where 
			$sql
	");

	$get->execute(@_) 
		or $class->{_}->bail->("get_from_gh failed: " . $get->errstr);

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

	return $posts;
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
	my %a = @_;

	my $post = $a{post};
	my $data = $a{data};

	# fill in and check header fields
	foreach my $f (@{$class->header_fields}) {
		if ($f->{require} && !$post->{ $f->{name} }) {
			$class->{_}->bail->("missing required field: $f->{name}");
		}

		if (!$post->{ $f->{name} }) {
			$post->{ $f->{name} } = $f->{d_value};
		}
	}

	# fill in data fields
	foreach my $f (@{$data}) {
		if (!$post->{ $f->{name} }) {
			$post->{ $f->{name} } = $f->{d_value};
		}
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
			" . $class->{headers} . "
		where 
			id = ?
	");

	$delh->execute($id)
		or $class->{_}->bail->("delete headers failed: ".$delh->errstr);

	# delete from data
	my $deld = $class->{_}->core->get_dbh->prepare("
		delete from 
			" . $class->{data} . "
		where 
			id = ?
	");

	$deld->execute($id)
		or $class->{_}->bail->("delete data failed: ".$deld->errstr);

	return 1;
}

#----------

sub header_fields {
	my $class = shift;

	return [

	{
		name	=> "id",
		allowed	=> '\d+',
		d_value	=> 0,
	},
	{
		name	=> "title",
		allowed	=> '.*',
		require	=> 1,
	},
	{
		name	=> "parent",
		allowed	=> '\d+',
		d_value	=> 0,
	},
	{
		name	=> "timestamp",
		allowed	=> '\d+',
		d_value	=> time,
	},
	{
		name	=> "user",
		allowed	=> '\d+',
		d_value	=> $class->{_}->user->id,
		require	=> 0,
	},
	{
		name	=> "status",
		allowed	=> '\d+',
		d_value	=> 0,
	},

	];
}

#----------

1;
