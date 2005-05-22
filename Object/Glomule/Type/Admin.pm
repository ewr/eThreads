package eThreads::Object::Glomule::Type::Admin;

@ISA = qw( eThreads::Object::Glomule::Type );

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;
	my $name = shift;

	$class = bless( { 
		_		=> $data,
		name	=> $name || undef,
		id		=> undef,
	} , $class);

	return $class;
}

#----------

sub activate {
	my $class = shift;

	return $class;
}

#----------

sub f_main {
	my $class = shift;
	my $fobj = shift;

	$fobj->gholders->register(
		[
			"function", 
			['looks','prefs']
		],
		[
			"function.looks", 
			{
				title	=> "Manage Looks",
				link	=> "looks",
				description	=> "Manage Looks for this Container.",
			}
		],
		[
			"function.prefs",
			{
				title	=> "Manage Prefs",
				link	=> "prefs",
				description	=> "Modify container preferences.",
			}
		]
	);
}

#----------

sub f_looks {
	my $class = shift;
	my $fobj = shift;

	# get info on the looks for this container
	my $looks = $class->{_}->ocontainer->get_looks;

	# -- see if we're creating a new look -- #

	# -- see if we're setting a default -- #

	if ( my $id = $fobj->bucket->get("new_default") ) {
		# first, make sure this is a legal value
		if ($looks->{id}{ $id }) {
			# it's legit...  set default
			my $db = $class->{_}->core->get_dbh;

			my $update = $db->prepare("
				update " . 
					$class->{_}->core->tbl_name("looks") . 
				" set is_default = ? where id = ?
			");

			$update->execute( 0 , $looks->{ DEFAULT }->{id} );
			$update->execute( 1 , $id );

			$class->{_}->cache->update_times->set(
				tbl		=> "looks",
				ts		=> time,
			);

			$fobj->gholders->register(
				"message",
				"Successfully set default look to " . $looks->{$id}->{name}
			);

			# now we need to re-retrieve the looks so we get the new default
			$looks = $class->{_}->ocontainer->get_looks;
		} else {
			$class->{_}->bail->("Attempted to make invalid look default.");
		}
	}

	# -- list the looks for this container -- #

	my @o;
	while ( my ($id,$l) = each %{$looks->{id}} ) {
		push @o, $l->{id};

		if ($l->{id} == $looks->{DEFAULT}{id}) {
			# we're not allowed to directly change this copy, since it's cached
			$l = { %$l };
			$l->{is_default} = 1;
		}

		$fobj->gholders->register( "look.".$l->{id} , $l );
	}

	# order the list by look name
	@o = 
		map { $_->[0] }
		sort { $a->[1] cmp $b->[1] } 
		map { [$_ , $looks->{ $_ }->{name}] } 
		@o;

	$fobj->gholders->register("look",\@o);
}

#----------

sub f_templates {
	my $class = shift;
	my $fobj = shift;

	# -- get a list of templates -- #
	my $look = $class->load_look(
		$fobj->bucket->get("look")
	);

	# -- templates -- #

	{
		my $tm = $look->get_templates;

		my @o;
		while ( my ($p,$obj) = each %$tm ) {
			next if ($p =~ m!^\.!);

			my $link = $class->{_}->queryopts->link("/templates/edit",{
				class		=> "templates",
				template	=> $obj->{id},
			});

			$fobj->gholders->register("template.".$obj->{id} , {
				id		=> $obj->{id},
				path	=> $obj->{path},
				type	=> $obj->{type},
				link	=> $link,
			} );

			push @o, [$obj->{id},$p];
		}

		@o = 
			map { $_->[0] } 
			sort { $a->[1] cmp $b->[1] } 
			map { [ $_->[0] , $_->[1] ] } 
			@o;

		$fobj->gholders->register("template",\@o);
	}

	# -- subtemplates -- #

	{
		my $tm = $look->get_subtemplates;

		my @o;
		while ( my ($p,$obj) = each %$tm ) {
			next if ($p =~ m!^\.!);

			my $link = $class->{_}->queryopts->link("/subtemplates/edit",{
				class		=> "templates",
				template	=> $obj->{id},
			});

			$fobj->gholders->register("subtemplate.".$obj->{id} , {
				id		=> $obj->{id},
				path	=> $obj->{path},
				type	=> $obj->{type},
				link	=> $link,
			} );

			push @o, [$obj->{id},$p];
		}

		@o = 
			map { $_->[0] } 
			sort { $a->[1] cmp $b->[1] } 
			map { [ $_->[0] , $_->[1] ] } 
			@o;

		$fobj->gholders->register("subtemplate",\@o);
	}
}

#----------

sub f_templates_new {
	my $class = shift;
	my $fobj = shift;

	# -- load the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("look")
	);

	if ($fobj->bucket->get("submit")) {
		# get our data
		my $path = $fobj->bucket->get("path");
		my $type = $fobj->bucket->get("type");
		my $content = $fobj->bucket->get("content");
		
		# check if path is valid
		$class->{_}->bail->("Invalid Path: $path") 
			if ($path !~ m!^[\w/\.]+$!);

		# make sure path doesn't already exist
		my $tm = $look->get_templates;
		$class->{_}->bail->("Path already exists: $path") 
			if ($tm->{ $path });

		# make sure content type is valid
		$class->{_}->bail->("Invalid content type: $type") 
			if (!$class->{_}->settings->{content_types}{ $type });

		# now create the new template
		my $db = $class->{_}->core->get_dbh;
		my $insert = $db->prepare("
			insert into " . $class->{_}->core->tbl_name("templates") . "(
				id,look,name,c_type,value
			) values(0,?,?,?,?)
		");

		$insert->execute($look->id,$path,$type,$content) 
			or $class->{_}->bail->("new template failed: ".$db->errstr);

		# FIXME - This should be a better interface
		my $id = $class->{_}->core->{db}->get_message_id();

		$class->{_}->cache->update_times->set(
			tbl		=> "templates",
			first	=> $look->id,
			ts		=> time,
		);
	
		$fobj->gholders->register("message","created new template");
	} else {
		# prepare a list of content types

		my @o;
		while ( my ($k,$v) = each %{$class->{_}->settings->{content_types}} ) {
			push @o, $k;
			$fobj->gholders->register(
				"content_type." . $k, 
				{ name => $v , value=> $k }
			);
		}

		@o = sort @o;

		$fobj->gholders->register("content_type",\@o);
	}
}

#----------

sub f_templates_edit {
	my $class = shift;
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("template")
	);

	$class->{_}->bail->("Invalid template") if (!$template);

	if ($fobj->bucket->get("submit")) {
		$class->{_}->utils->set_value(
			tbl		=> "templates",
			keys	=> {
				id	=> $template->id,
			},
			value	=> $fobj->bucket->get("content")
		);

		$class->{_}->cache->update_times->set(
			tbl		=> "templates",
			first	=> $look->id,
			ts		=> time,
		);
	
		$template = $look->load_template(
			$fobj->bucket->get("template")
		);
	
		$fobj->gholders->register("message","updating content...");
	}

	my $safe_data = {};
	my $data = $template->cachable;
	while ( my ($k,$v) = each %$data ) {
		$safe_data->{ $k } = $v;

		$safe_data->{ $k } =~ s!&!&amp;!g;
		$safe_data->{ $k } =~ s!<!&lt;!g;
		$safe_data->{ $k } =~ s!>!&gt;!g;
	}

	$fobj->gholders->register("template",$safe_data);
}

#----------

sub f_subtemplates_new {
	my $class = shift;
	my $fobj = shift;

	# -- load the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("look")
	);

	if ($fobj->bucket->get("submit")) {
		# get our data
		my $path = $fobj->bucket->get("path");
		my $content = $fobj->bucket->get("content");
		
		# check if path is valid
		$class->{_}->bail->("Invalid Path: $path") 
			if ($path !~ m!^[\w/]+$!);

		# make sure path doesn't already exist
		my $tm = $look->get_subtemplates;
		$class->{_}->bail->("Path already exists: $path") 
			if ($tm->{ $path });

		# now create the new template
		my $db = $class->{_}->core->get_dbh;
		my $insert = $db->prepare("
			insert into " . $class->{_}->core->tbl_name("subtemplates") . "(
				id,look,name,value
			) values(0,?,?,?)
		");

		$insert->execute($look->id,$path,$content) 
			or $class->{_}->bail->("new template failed: ".$db->errstr);

		# FIXME - This should be a better interface
		my $id = $class->{_}->core->{db}->get_message_id();

		$class->{_}->cache->update_times->set(
			tbl		=> "subtemplates",
			first	=> $look->id,
			ts		=> time,
		);
	
		$fobj->gholders->register("message","created new template");
	} else {
		# do nothing!
	}
}

#----------

sub f_subtemplates_edit {
	my $class = shift;
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_subtemplate(
		$fobj->bucket->get("template")
	);

	$class->{_}->bail->("Invalid template") if (!$template);

	if ($fobj->bucket->get("submit")) {
		$class->{_}->utils->set_value(
			tbl		=> "subtemplates",
			keys	=> {
				id	=> $template->id,
			},
			value	=> $fobj->bucket->get("content")
		);

		$class->{_}->cache->update_times->set(
			tbl		=> "subtemplates",
			first	=> $look->id,
			ts		=> time,
		);
	
		$template = $look->load_subtemplate(
			$fobj->bucket->get("template")
		);
	
		$fobj->gholders->register("message","updating content...");
	}

	my $safe_data = {};
	my $data = $template->cachable;
	while ( my ($k,$v) = each %$data ) {
		$safe_data->{ $k } = $v;

		$safe_data->{ $k } =~ s!&!&amp;!g;
		$safe_data->{ $k } =~ s!<!&lt;!g;
		$safe_data->{ $k } =~ s!>!&gt;!g;
	}

	$fobj->gholders->register("template",$safe_data);
}

#----------

sub f_qopts {
	my $class = shift;
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("template")
	);

	$class->{_}->bail->("Invalid template") if (!$template);

	# now what we need is to know what glomules and functions are referenced 
	# in the template, so that we can come up with a list of all qopts the 
	# functions want and present the unregistered ones as options

	my $all_qopts = $class->list_available_qopts($template);

	# we'll stop for a second here to do our registers and edits

	if ($fobj->bucket->get("add") || $fobj->bucket->get("edit")) {
		my $g = $fobj->bucket->get("glomule");
		my $o = $fobj->bucket->get("opt");
		my $n = $fobj->bucket->get("name");

		$class->{_}->utils->set_value(
			tbl		=> "qopts",
			keys	=> {
				glomule		=> $g,
				opt			=> $o,
				template	=> $template->id,
			},
			value_field	=> "name",
			value	=> $n,
		);

		$class->{_}->cache->update_times->set(
			tbl		=> "qopts",
			first	=> $template->id,
			ts		=> time,
		);
	}

	# now get a list of qopts defined for the template
	my $def_qopts = $template->qopts;

	my $o = {
		def	=> [],
		all	=> [],
	};

	while ( my ($g,$gref) = each %$all_qopts ) {
		# $g is the glomule name...  make it an id
		my $id = $class->{_}->glomule->name2id($g,$class->{_}->ocontainer->id);

		while ( my ($opt,$oref) = each %$gref ) {
			if ( my $d = $def_qopts->{ $id }{ $opt } ) {
				$fobj->gholders->register(
					"qopt.".$id.".".$opt , {
						gname => $g, 
						gid => $id, 
						opt => $opt, 
						name => $d->{name}
					}
				);

				push @{$o->{def}}, [ $id.".".$opt , $g , $opt ];
			} else {
				$fobj->gholders->register(
					"unregistered.$id.$opt" , {gname=>$g,gid=>$id,opt=>$opt}
				);
				push @{$o->{all}}, [ $id.".".$opt , $g , $opt ];
			}
		}
	}

	foreach my $l ("def","all") {
		@{$o->{$l}} = 
			map { $_->[0] } 
			sort { 
				$a->[1] <=> $b->[1] 
				|| $a->[2] cmp $b->[2]
			}
			@{$o->{$l}};
	}

	$fobj->gholders->register(
		["qopt",$o->{def}],
		["unregistered",$o->{all}]
	);
}

#----------

sub f_qkeys {
	my $class = shift;
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("template")
	);

	$class->{_}->bail->("Invalid template") if (!$template);

	# we need a list of names mapped to qopts so that we know what 
	# names to allow qkeys to be pointed to.  qkey -> name -> qopt.
	my $names = {};

	my $name_options = "";
	{
		my $get_names = $class->{_}->core->get_dbh->prepare("
			select 
				distinct name 
			from 
				" . $class->{_}->core->tbl_name("qopts") . "
			where 
				template = ?
		");

		$get_names->execute($template->id)
			or $class->{_}->bail->("get_names failed: ".$get_names->errstr);

		my $name;
		$get_names->bind_columns(\$name);

		while ($get_names->fetch) {
			$names->{ $name } = 1;
			$name_options .= qq(<option value="$name">$name</option>);
		}
	}

	# get a list of defined qkeys...
	my $qkeys = $template->qkeys;

	# -- check for updates -- #
	if ($fobj->bucket->get("add")) {
		my $name = $fobj->bucket->get("name");

		# make sure this is a legal name
		if (!$names->{ $name }) {
			$class->{_}->bail->("Invalid qkey name: $name");
		}
	
		# we need to know what position to make this
		my $count = @$qkeys + 1;

		$class->{_}->utils->set_value(
			tbl		=> "qkeys",
			keys	=> {
				template	=> $template->id,
				position	=> $count,
			},
			value_field	=> "name",
			value		=> $name
		);
	} elsif ($fobj->bucket->get("edit")) {
		my $name = $fobj->bucket->get("name");
		my $pos = $fobj->bucket->get("pos");

		if ($name) {
			# update it

			# make sure this is a legal name
			if (!$names->{ $name }) {
				$class->{_}->bail->("Invalid qkey name: $name");
			}

			$class->{_}->utils->set_value(
				tbl		=> "qkeys",
				keys	=> {
					template	=> $template->id,
					position	=> $pos,
				},
				value_field	=> "name",
				value		=> $name
			);
		} else {
			# delete it

			# make a copy
			my @keys = @$qkeys;

			# take out our position
			splice(@keys,($pos - 1),1);

			my $i = 1;
			foreach my $n (@keys) {
				$class->{_}->utils->set_value(
					tbl		=> "qkeys",
					keys	=> {
						template	=> $template->id,
						position	=> $i,
					},
					value_field	=> "name",
					value		=> $n
				);
				$i++;
			}

			# now delete the former last position
			my $last = @$qkeys;
			$class->{_}->utils->set_value(
				tbl		=> "qkeys",
				keys	=> {
					template	=> $template->id,
					position	=> $last,
				},
				value_field	=> "name",
				value		=> 0,
			);
		}
	}

	if ($fobj->bucket->get("add") || $fobj->bucket->get("edit")) {
		$class->{_}->cache->update_times->set(
			tbl		=> "qkeys",
			first	=> $template->id,
			ts		=> time,
		);

		# re-get qkeys
		$qkeys = $template->cache_qkeys;
	}

	# -- register qkeys -- #
	{
		my @o;
		my $i = 1;
		foreach my $n (@$qkeys) {
			$fobj->gholders->register(
				["qkey.".$i , { pos => $i , name => $n }]
			);
			push @o, $i;
			$i++;
		}

		$fobj->gholders->register(["qkey",\@o]);
	}

	$fobj->gholders->register("name_options",$name_options);

}

#----------

sub _check_maint_rights {
	my $class = shift;

	if (!$class->{_}->switchboard->knows('user')) {
		$class->{_}->bail->("Invalid rights.");
	}

	if ( !$class->{_}->user->has_rights('maint') ) {
		$class->{_}->bail->("Invalid rights.");
	} 

	return $class;
}

sub f_maint {
	my $class = shift;
	my $fobj = shift;

	$class->_check_maint_rights;

	# do nothing
}

#----------

sub f_maint_containers {
	my $class = shift;
	my $fobj = shift;

	$class->_check_maint_rights;

	# -- get a list of containers -- #

	my $c = $class->{_}->instance->load_containers(0);
	$fobj->gholders->register(['containers',$c]);
}

#----------

sub f_maint_domains {
	my $class = shift;
	my $fobj = shift;

	$class->_check_maint_rights;
}

#----------

sub list_available_qopts {
	my $class = shift;
	my $template = shift;

	# ok, step one is to create a template walker and register glomule 
	# handlers so that we can step through and see what we're dealing 
	# with here

	my $walker = $class->{_}->instance->new_object("Template::Walker");

	my $qopts = {};

	foreach my $t (keys %{$class->{_}->settings->{glomule_types}}) {
		# -- register the walker -- #
		$walker->register(
			[ $t , sub { return $class->_walk_glomule($t,$qopts,@_); } ]
		);
	}

	$walker->walk_template_tree(
		$template->get_tree
	);

	return $qopts;
	
}

#----------

sub _walk_glomule {
	my $class = shift;
	my $type = shift;
	my $qopts = shift;
	my $i = shift;

	my $glomule = $i->args->{name} || $i->args->{glomule};

	my $gc = $class->{_}->controller->get($type);

	if ( my $func = $gc->has_function( $i->args->{function} ) ) {
		foreach my $q (@{ $func->qopts }) {
			$qopts->{ $glomule }{ $q->{key} } = 1;
		}
	} else {
		$class->{_}->bail->(
			"Unknown admin glomule function: "
			. $glomule
			. "/"
			. $i->args->{function}
		);
	}

	return 1;
}

#----------

sub load_look {
	my $class = shift;
	my $id = shift;

	# validate this look
	$class->{_}->ocontainer->is_valid_look($id)
		or $class->{_}->bail->("Look not found/improper ownership: $id");

	my $look = $class->{_}->instance->new_object("Look");
	$look->{id} = $id;

	# look wants the original container, not admin
	$class->{_}->cswitchboard->reroute_calls_for($look);

	return $look;
}

#----------

1;
