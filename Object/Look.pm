package eThreads::Object::Look;

sub new {
	my $class 	= shift;
	my $data 	= shift;

	$class = bless ( 
		{ 
			_		=> $data,
			id		=> undef,
			name	=> undef,
			@_
		} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub cachable {
	my $class = shift;
	return {
		id		=> $class->id,
		name	=> $class->{name},
	};
}

#----------

sub id {
	return shift->{id};
}

#----------

sub cache_template_map {
	my $class = shift;
	
	my $db = $class->{_}->core->get_dbh;

	my $get_templates = $db->prepare("
		select 
			name,
			c_type,
			id,
			value
		from
			" . $class->{_}->core->tbl_name("templates") . "
		where 
			look = ? 
	");

	$class->bail("cache_template_map error: ".$db->errstr) 
		unless ( $get_templates->execute( $class->id ) );

	my ($name,$type,$id,$v);
	$get_templates->bind_columns( \($name,$type,$id,$v) );

	my $m = {};
	while ($get_templates->fetch) {
		my $t = $class->{_}->instance->new_object("Template",
			path	=> $name,
			type	=> $type,
			id		=> $id,
			value	=> $v,
		);

		$m->{$name} = $t->cachable;
	}

	$class->{_}->cache->write_cache_file(
		tbl		=> "templates",
		first	=> $class->id,
		ref		=> $m,
	);

	return $m;	
}

#----------

sub cache_subtemplates {
	my $class = shift;
	
	my $db = $class->{_}->core->get_dbh;

	my $get_templates = $db->prepare("
		select 
			id,
			name,
			value
		from
			" . $class->{_}->core->tbl_name("subtemplates") . "
		where 
			look = ? 
	");

	$class->{_}->bail("cache_subtemplates error: ".$db->errstr) 
		unless ($get_templates->execute($class->id));

	my ($id,$name,$v);
	$get_templates->bind_columns( \($id,$name,$v) );

	my $m = {};
	while ($get_templates->fetch) {
		$m->{$name} = {
			id		=> $id,
			path	=> $name,
			value	=> $v,
		};
	}

	$class->{_}->cache->write_cache_file(
		tbl		=> "subtemplates",
		first	=> $class->id,
		ref		=> $m,
	);

	return $m;	
}
#----------

sub determine_template {
	my $class = shift;

	# -- load the template map for this container and look -- #
	my $tm = $class->get_templates;

	my $uri = $class->{_}->RequestURI->unclaimed;

	my $tpath;
	{
		my @parts = split("/",$uri);

		foreach my $p (@parts) {
			next if (!$p);
			my $test = $tpath . "/" . $p;
			if ($tm->{$test}) {
				$tpath = $test;
			} else {
				last;
			}
		}

		$tpath = "/" if (!$tpath);
	}

	$class->{_}->RequestURI->claim($tpath);

	# -- make sure we have that template -- #

	if (!$tm->{$tpath}) {
		$class->{_}->core->bail("No template found for $tpath.");
	}

	# -- load a template object -- #

	my $id = $tm->{ $tpath }{id};

	if (my $t = $class->{_}->memcache->get("Template",$id)) {
		return $t;
	} else {
		my $t = $class->{_}->instance->new_object("Template",
			%{$tm->{$tpath}}
		);

		$class->{_}->memcache->set("Template",$id,$t);

		return $t;
	}
}

#----------

sub load_template_by_path {
	my $class = shift;
	my $path = shift;

	if (!$path) {
		return undef;
	}

	my $tm = $class->get_templates;

	if ($tm->{$path}) {
		if (my $t = $class->{_}->memcache->get("Template",$tm->{$path}{id})) {
			return $t;
		} else {
			my $t = $class->{_}->instance->new_object(
				"Template",
				%{$tm->{$path}}
			);

			$class->{_}->memcache->set("Template",$tm->{$path}{id},$t);

			return $t;
		}
	} else {
		return undef;
	}
}

#----------

sub load_template {
	my $class = shift;
	my $id = shift;

	# fail if we don't get a template id
	if (!$id) {
		return undef;
	}

	# load the template map
	my $tm = $class->get_templates;

	# turn it inside out
	my $by_ids;
	%$by_ids = map { $tm->{ $_ }->{id} => $tm->{ $_ } } keys(%$tm);

	if ( !$by_ids->{ $id } ) {
		warn "no template map entry for id: $id\n";
		return undef;
	}

	if (my $t = $class->{_}->memcache->get("Template",$id)) {
		return $t;
	} else {
		my $t = $class->{_}->instance->new_object( 
			"Template", 
			%{ $by_ids->{ $id } }
		);

		$class->{_}->memcache->set("Template",$id,$t);

		return $t;
	}
}

#----------

sub load_subtemplate_by_path {
	my $class = shift;
	my $path = shift;

	# fail if we don't get a template id
	if (!$path) {
		return undef;
	}

	# load the template map
	my $tm = $class->get_subtemplates;

	if ( !$tm->{ $path } ) {
		warn "no subtemplate for path: $path\n";
		return undef;
	}

	my $id = $tm->{ $path }{id};

	if (my $t = $class->{_}->memcache->get("Template::Subtemplate",$id)) {
		return $t;
	} else {
		my $t = $class->{_}->instance->new_object( 
			"Template::Subtemplate", 
			%{ $tm->{ $path } }
		);

		$class->{_}->memcache->set("Template::Subtemplate",$id,$t);

		return $t;
	}

}

#----------

sub load_subtemplate {
	my $class = shift;
	my $id = shift;

	# fail if we don't get a template id
	if (!$id) {
		return undef;
	}

	# load the template map
	my $tm = $class->get_subtemplates;

	# turn it inside out
	my $by_ids;
	%$by_ids = map { $tm->{ $_ }->{id} => $tm->{ $_ } } keys(%$tm);

	if ( !$by_ids->{ $id } ) {
		warn "no template map entry for id: $id\n";
		return undef;
	}

	if (my $t = $class->{_}->memcache->get("Template::Subtemplate",$id)) {
		return $t;
	} else {
		my $t = $class->{_}->instance->new_object( 
			"Template::Subtemplate", 
			%{ $by_ids->{ $id } }
		);

		$class->{_}->memcache->set("Template::Subtemplate",$id,$t);

		return $t;
	}

}

#----------

sub get_templates {
	my $class = shift;

	if (my $tm = $class->{_}->memcache->get_raw("templates",$class->id)) {
		return $tm;
	} else {
		my $tm = $class->{_}->cache->load_cache_file(
			tbl		=> "templates",
			first	=> $class->id,
		);

		if (!$tm) {
			$tm = $class->cache_template_map();
		}

		$class->{_}->memcache->set_raw("templates",$class->id,$tm);

		return $tm;
	}
}

#----------

sub get_subtemplates {
	my $class = shift;

	if (my $tm = $class->{_}->memcache->get_raw("subtemplates",$class->id)) {
		return $tm;
	} else {
		my $tm = $class->{_}->cache->load_cache_file(
			tbl		=> "subtemplates",
			first	=> $class->id,
		);

		if (!$tm) {
			$tm = $class->cache_subtemplates();
		}

		$class->{_}->memcache->set_raw("subtemplates",$class->id,$tm);

		return $tm;
	}
}

#----------

1;
