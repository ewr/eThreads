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

	my $gh = $class->{_}->cache->load_cache_file(
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
			$class->{_}->core->bail("Invalid Glomule: $class->{name}");
		}
	}

	# -- load glomule data -- #

	my $gd = $class->{_}->cache->load_cache_file(
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

sub register_functions {
	my $class = shift;

	foreach my $f (@_) {
		my $func = $class->{_}->instance->new_object(
			"Glomule::Function",
			$class,
			$f
		);
		$class->{f}{ $f->{name} } = $func;
	}

	return 1;
}

#----------

sub is_function {
	my $class = shift;
	my $func = shift;

	if (my $ref = $class->_is_function($func)) {
		if ( $ref->mode( $class->{_}->mode->mode ) ) {
			return $ref;
		} else {
			return undef;
		}
	} else {
		return undef;
	}
}

#----------

sub _is_function {
	my $class = shift;
	my $func = shift;

	if (my $ref = $class->{f}{ $func }) {
		return $ref;
	} else {
		return undef;
	}
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

	my $gp = $class->{_}->cache->load_cache_file(
		tbl		=> "prefs",
		first	=> $class->{id},
	);

	if (!$gp) {
		$gp = $class->cache_glomule_prefs;
	}

	# -- next load look-specific prefs -- #

	my $lp = $class->{_}->cache->load_cache_file(
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

sub cache_glomheaders {
	my $class = shift;

	my $core = $class->{_}->core;
	my $db = $core->get_dbh;

	my $get = $db->prepare("
		select 
			id,
			title,
			timestamp,
			parent,
			status,
			user
		from 
			$class->{headers}
	");

	$get->execute or $core->bail("cache_glomheaders failure: ".$db->errstr);

	my ($id,$t,$ts,$p,$s,$u);
	$get->bind_columns( \($id,$t,$ts,$p,$s,$u) );

	my $h = {};
	while ($get->fetch) {
		$h->{$id} = {
			id			=> $id,
			title		=> $t,
			timestamp	=> $ts,
			parent		=> $p,
			status		=> $s,
			user		=> $u
		};
	}

	$class->{_}->cache->write_cache_file(
		tbl		=> "glomheaders",
		first	=> $class->{id},
		ref		=> $h
	);

	return $h;
}

#----------

sub cache_glomdata {
	my $class = shift;

	my $core = $class->{_}->core;
	my $db = $core->get_dbh;

	my $get = $db->prepare("
		select 
			id,
			ident,
			value
		from 
			$class->{data}
	");

	$get->execute or $core->bail("cache_glomdata failure: ".$db->errstr);

	my ($id,$ident,$value);
	$get->bind_columns( \($id,$ident,$value) );

	my $d = {};
	while ($get->fetch) {
		$d->{ $id }{ $ident } = $value;
	}

	$core->{modules}{cache}->write_cache_file(
		tbl		=> "glomdata",
		first	=> $class->{id},
		ref		=> $d,
	);

	return $d;
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

1;
