package eThreads::Object::Look;

sub new {
	my $class 	= shift;
	my $data 	= shift;

	$class = bless ( 
		{ 
			_		=> $data,
			id		=> undef,
			name	=> undef,
			# etc...
		} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
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

	my $t = $class->{_}->instance->new_object("Template",
		%{$tm->{$tpath}}
	);

	return $t;
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

	my $t = $class->{_}->instance->new_object( 
		"Template", 
		%{ $by_ids->{ $id } }
	);

	return $t;
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

	my $t = $class->{_}->instance->new_object( 
		"Template::Subtemplate", 
		%{ $by_ids->{ $id } }
	);

	return $t;
}

#----------

sub get_templates {
	my $class = shift;

	my $tm = $class->{_}->cache->load_cache_file(
		tbl		=> "templates",
		first	=> $class->id,
	);

	if (!$tm) {
		$tm = $class->cache_template_map();
	}

	return $tm;
}

#----------

sub get_subtemplates {
	my $class = shift;

	my $tm = $class->{_}->cache->load_cache_file(
		tbl		=> "subtemplates",
		first	=> $class->id,
	);

	if (!$tm) {
		$tm = $class->cache_subtemplates();
	}

	return $tm;
}

#----------

1;
