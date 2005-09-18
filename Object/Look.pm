package eThreads::Object::Look;

use Spiffy -Base;

no warnings;

field '_'		=> -ro;

field 'id' => -ro;
field 'name' => -ro;
field 'type' => -ro;

field 'templates'	=>
	-ro,
	-init=>q!
		$self->_->cache->get(tbl=>'templates',first=>$self->id)
			or $self->cache_template_map();
	!;

field 'subtemplates'	=>
	-ro,
	-init=>q!
		$self->_->cache->get(tbl=>'subtemplates',first=>$self->id)
			or $self->cache_subtemplates();
	!;

#----------

sub new {
	my $data 	= shift;

	$self = bless ( 
		{ 
			_		=> $data,
			@_
		} , $self );

	return $self;
}

#----------

sub DESTROY {
	# nothing right now
}

#----------

sub cachable {
	return {
		id		=> $self->id,
		name	=> $self->name,
		type	=> $self->type,
	};
}

#----------

sub is_admin { 
	return ( $self->{type} eq "ADMIN" ) ? 1 : undef;
}

#----------

sub cache_template_map {
	my $db = $self->_->core->get_dbh;

	my $get_templates = $db->prepare("
		select 
			name,
			c_type,
			id
		from
			" . $self->_->core->tbl_name("templates") . "
		where 
			look = ? 
	");

	$self->bail("cache_template_map error: ".$db->errstr) 
		unless ( $get_templates->execute( $self->id ) );

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

	$self->_->cache->set(
		tbl		=> "templates",
		first	=> $self->id,
		ref		=> $m,
	);

	return $m;	
}

#----------

sub cache_subtemplates {
	my $db = $self->_->core->get_dbh;

	my $get_templates = $db->prepare("
		select 
			id,
			name
		from
			" . $self->_->core->tbl_name("subtemplates") . "
		where 
			look = ? 
	");

	$self->_->bail("cache_subtemplates error: ".$db->errstr) 
		unless ($get_templates->execute($self->id));

	my ($id,$name);
	$get_templates->bind_columns( \($id,$name) );

	my $m = {};
	while ($get_templates->fetch) {
		$m->{$name} = {
			id		=> $id,
			path	=> $name
		};
	}

	$self->_->cache->set(
		tbl		=> "subtemplates",
		first	=> $self->id,
		ref		=> $m,
	);

	return $m;	
}

#----------

sub determine_template {
	# -- load the template map for this container and look -- #
	my $tm = $self->templates;

	my $uri = $self->_->RequestURI->unclaimed || '';

	my $tpath = '';
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

	$self->_->RequestURI->claim($tpath);

	# -- make sure we have that template -- #

	if (!$tm->{$tpath}) {
		$self->_->bail->("No template found for $tpath.");
	}

	# -- load a template object -- #

	my $id = $tm->{ $tpath }{id};

	my $t = $self->_->new_object(
		"Template", 
		%{$tm->{$tpath}},
		look	=> $self
	);

	return $t;
}

#----------

sub has_template_path_in_table {
	my $table = shift;
	my $path = shift;

	if (!$path) {
		return undef;
	}

	if (my $t = $self->$table->{$path}) {
		return $t->{id};
	} else {
		return undef;
	}
}

#----------

sub has_template_by_path {
	my $path = shift;

	if (!$path) { 
		return undef;
	}

	if (my $t = $self->templates->{$path}) {
		return $t->{id};
	} else {
		return undef;
	}
}

#----------

sub load_template_by_path {
	my $path = shift;

	if (!$path) {
		return undef;
	}

	my $ocache = $self->_->cache->objects;

	if (my $tref = $self->templates->{$path}) {
		if (my $t = $ocache->get("Template",$tref->{id})) {
			return $t;
		} else {
			my $t = $self->_->new_object(
				"Template",
				%$tref,
				look	=> $self
			);

			$ocache->set("Template",$t->id,$t);

			return $t;
		}
	} else {
		return undef;
	}
}

#----------

sub load_template {
	my $id = shift;

	# fail if we don't get a template id
	if (!$id) {
		return undef;
	}

	# load the template map
	my $tm = $self->templates;

	# turn it inside out
	my $by_ids;
	%$by_ids = map { $tm->{ $_ }->{id} => $tm->{ $_ } } keys(%$tm);

	if ( !$by_ids->{ $id } ) {
		warn "no template map entry for id: $id\n";
		return undef;
	}

	my $t = $self->_->new_object( 
		"Template", 
		%{ $by_ids->{ $id } },
		look	=> $self
	);

	return $t;
}

#----------

sub load_subtemplate_by_path {
	my $path = shift;

	# fail if we don't get a template id
	if (!$path) {
		return undef;
	}

	# load the template map
	my $tm = $self->subtemplates;

	if ( !$tm->{ $path } ) {
		return undef;
	}

	my $id = $tm->{ $path }{id};

	my $t = $self->_->new_object( 
		"Template::Subtemplate", 
		%{ $tm->{ $path } },
		look	=> $self
	);

	return $t;
}

#----------

sub load_subtemplate {
	my $id = shift;

	# fail if we don't get a template id
	if (!$id) {
		return undef;
	}

	# load the template map
	my $tm = $self->subtemplates;

	# turn it inside out
	my $by_ids;
	%$by_ids = map { $tm->{ $_ }->{id} => $tm->{ $_ } } keys(%$tm);

	if ( !$by_ids->{ $id } ) {
		warn "no template map entry for id: $id\n";
		return undef;
	}

	my $t = $self->_->new_object( 
		"Template::Subtemplate", 
		%{ $by_ids->{ $id } },
		look	=> $self
	);

	return $t;
}

#----------

sub new_template {
	my $t = $self->_->new_object('Template::Writable');
	$t->look( $self );

	return $t;
}

#----------

sub new_subtemplate {
	my $t = $self->_->new_object('Template::Subtemplate::Writable');
	$t->look( $self );

	return $t;
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

=item templates

	my $tm = $look->templates;

Used internally to load template map.

=item subtemplates

	my $tm = $look->subtemplates;

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
