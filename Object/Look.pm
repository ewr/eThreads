package eThreads::Object::Look;

sub new {
	my $class 	= shift;
	my $data 	= shift;

	$class = bless ( 
		{ 
			_		=> $data,
			id		=> undef,
			name	=> undef,
			type	=> undef,
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
		type	=> $class->{type},
	};
}

#----------

sub is_admin { 
	my $class = shift;
	return ( $class->{type} eq "ADMIN" ) ? 1 : undef;
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
			id
		from
			" . $class->{_}->core->tbl_name("templates") . "
		where 
			look = ? 
	");

	$class->bail("cache_template_map error: ".$db->errstr) 
		unless ( $get_templates->execute( $class->id ) );

	my ($name,$type,$id);
	$get_templates->bind_columns( \($name,$type,$id) );

	my $m = {};
	while ($get_templates->fetch) {
		$m->{ $name } = {
			path	=> $name,
			type	=> $type,
			id		=> $id,
		};
	}

	$class->{_}->cache->set(
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
			name
		from
			" . $class->{_}->core->tbl_name("subtemplates") . "
		where 
			look = ? 
	");

	$class->{_}->bail("cache_subtemplates error: ".$db->errstr) 
		unless ($get_templates->execute($class->id));

	my ($id,$name);
	$get_templates->bind_columns( \($id,$name) );

	my $m = {};
	while ($get_templates->fetch) {
		$m->{$name} = {
			id		=> $id,
			path	=> $name
		};
	}

	$class->{_}->cache->set(
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
		$class->{_}->bail->("No template found for $tpath.");
	}

	# -- load a template object -- #

	my $id = $tm->{ $tpath }{id};

	my $t = $class->{_}->new_object(
		"Template", 
		%{$tm->{$tpath}},
		look	=> $class
	);

	return $t;
}

#----------

sub load_template_by_path {
	my $class = shift;
	my $path = shift;

	if (!$path) {
		return undef;
	}

	my $tm = $class->get_templates;

	my $ocache = $class->{_}->cache->objects;

	if ($tm->{$path}) {
		if (my $t = $ocache->get("Template",$tm->{$path}{id})) {
			return $t;
		} else {
			my $t = $class->{_}->new_object(
				"Template",
				%{$tm->{$path}},
				look	=> $class
			);

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

	my $t = $class->{_}->new_object( 
		"Template", 
		%{ $by_ids->{ $id } },
		look	=> $class
	);

	return $t;
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

	my $t = $class->{_}->new_object( 
		"Template::Subtemplate", 
		%{ $tm->{ $path } },
		look	=> $class
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

	my $t = $class->{_}->new_object( 
		"Template::Subtemplate", 
		%{ $by_ids->{ $id } },
		look	=> $class
	);

	return $t;
}

#----------

sub get_templates {
	my $class = shift;

	my $tm = $class->{_}->cache->get(
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

	my $tm = $class->{_}->cache->get(
		tbl		=> "subtemplates",
		first	=> $class->id,
	);

	if (!$tm) {
		$tm = $class->cache_subtemplates();
	}

	return $tm;
}

#----------

=head1 NAME

eThreads::Object::Look

=head1 SYNOPSIS

=head1 DESCRIPTION

This is the Look object.  It keeps track of loading look data and knowing 
what template should be called.

=over 4

=item new

	my $look = $inst->new_object("Look",id=>$id);

Return a new look object.  You should pass it the look id.

=item cachable 

Return the cachable items for the look.  These are just id and name.

=item id 

Return the look id

=item cache_template_map

Cache the template map for the look.

=item cache_subtemplates

Cache the subtemplates for the look.

=item determine_template

	my $tmplt = $look->determine_template;

Determine the template for the given instance, and return it as a template 
object.

=item load_template_by_path

	my $tmplt = $look->load_template_by_path("/foo");

Load a template given its path.  Returns a template object.

=item load_template

	my $tmplt = $look->load_template("17");

Load a template given its ID.  Returns a template object.

=item load_subtemplate_by_path

	my $sub = $look->load_subtemplate_by_path("header");

Load a subtemplate given a lookup name.  Returns a subtemplate object.

=item load_subtemplate

	my $sub = $look->load_subtemplate("17");

Load a subtemplate given its ID.  Returns a subtemplate object.

=item get_templates

	my $tm = $look->load_templates;

Used internally to load template map.

=item get_subtemplates

	my $tm = $look->load_subtemplates;

Used internally to load subtemplate map.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
