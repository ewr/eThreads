package eThreads::Object::Glomule::Type::Admin;

@ISA = qw( eThreads::Object::Glomule );

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

	$class->load_info;

	return $class;
}

#----------

sub activate {
	my $class = shift;

	$class->register_functions(
		{
			name	=> "/",
			sub		=> sub { $class->f_main(@_); },
			qopts	=> $class->qopts_main,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/looks",
			sub		=> sub { $class->f_looks(@_); },
			qopts	=> $class->qopts_looks,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/templates",
			sub		=> sub { $class->f_templates(@_); },
			qopts	=> $class->qopts_templates,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/templates/new",
			sub		=> sub { $class->f_templates_new(@_); },
			qopts	=> $class->qopts_templates_new,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/templates/edit",
			sub		=> sub { $class->f_templates_edit(@_); },
			qopts	=> $class->qopts_templates_edit,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/subtemplates/new",
			sub		=> sub { $class->f_subtemplates_new(@_); },
			qopts	=> $class->qopts_templates_new,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/subtemplates/edit",
			sub		=> sub { $class->f_subtemplates_edit(@_); },
			qopts	=> $class->qopts_templates_edit,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/qopts",
			sub		=> sub { $class->f_qopts(@_); },
			qopts	=> $class->qopts_qopts,
			modes	=> { Admin => 1 },
		},
		{
			name	=> "/qkeys",
			sub		=> sub { $class->f_qkeys(@_); },
			qopts	=> $class->qopts_qkeys,
			modes	=> { Admin => 1 },
		},
	);

	return $class;
}

#----------

sub f_main {
	my $class = shift;
	my $fobj = shift;

	$class->gholders->register(
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
		if ($looks->{ $id }) {
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

			$class->gholders->register(
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
	while ( my ($id,$l) = each %$looks ) {
		# this'll skip the DEFAULT look
		next if ($id =~ /\D/);

		push @o, $l->{id};

		if ($l->{id} == $looks->{DEFAULT}{id}) {
			# we're not allowed to directly change this copy, since it's cached
			$l = { %$l };
			$l->{is_default} = 1;
		}

		$class->gholders->register( "look.".$l->{id} , $l );
	}

	# order the list by look name
	@o = 
		map { $_->[0] }
		sort { $a->[1] cmp $b->[1] } 
		map { [$_ , $looks->{ $_ }->{name}] } 
		@o;

	$class->gholders->register("look",\@o);
}

#----------

sub f_templates {
	my $class = shift;
	my $fobj = shift;

	# -- get a list of templates -- #
	my $look;
	{
		my $id = $fobj->bucket->get("templates/look");

		$look = $class->{_}->instance->new_object("Look");
		$look->{id} = $id;

		# look wants the original container, not admin
		$class->{_}->cswitchboard->reroute_calls_for($look);
	}

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

			$class->gholders->register("template.".$obj->{id} , {
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

		$class->gholders->register("template",\@o);
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

			$class->gholders->register("subtemplate.".$obj->{id} , {
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

		$class->gholders->register("subtemplate",\@o);
	}
}

#----------

sub f_templates_new {
	my $class = shift;
	my $fobj = shift;

	# -- load the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("templates/look")
	);

	if ($fobj->bucket->get("submit")) {
		# get our data
		my $path = $fobj->bucket->get("path");
		my $type = $fobj->bucket->get("type");
		my $content = $fobj->bucket->get("content");
		
		# check if path is valid
		$class->{_}->bail->("Invalid Path: $path") 
			if ($path !~ m!^[\w/]+$!);

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
	
		$class->gholders->register("message","created new template");
	} else {
		# prepare a list of content types

		my @o;
		while ( my ($k,$v) = each %{$class->{_}->settings->{content_types}} ) {
			push @o, $k;
			$class->gholders->register(
				"content_type." . $k, 
				{ name => $v , value=> $k }
			);
		}

		@o = sort @o;

		$class->gholders->register("content_type",\@o);
	}
}

#----------

sub f_templates_edit {
	my $class = shift;
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("templates/look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("templates/template")
	);

	$class->{_}->bail->("Invalid template") if (!$template);

	if ($fobj->bucket->get("submit")) {
		$class->{_}->core->set_value(
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
			$fobj->bucket->get("templates/template")
		);
	
		$class->gholders->register("message","updating content...");
	}

	my $safe_data = {};
	my $data = $template->cachable;
	while ( my ($k,$v) = each %$data ) {
		$safe_data->{ $k } = $v;

		$safe_data->{ $k } =~ s!&!&amp;!g;
		$safe_data->{ $k } =~ s!<!&lt;!g;
		$safe_data->{ $k } =~ s!>!&gt;!g;
	}

	$class->gholders->register("template",$safe_data);
}

#----------

sub f_subtemplates_new {
	my $class = shift;
	my $fobj = shift;

	# -- load the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("templates/look")
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
	
		$class->gholders->register("message","created new template");
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
		$fobj->bucket->get("templates/look")
	);

	my $template = $look->load_subtemplate(
		$fobj->bucket->get("templates/template")
	);

	$class->{_}->bail->("Invalid template") if (!$template);

	if ($fobj->bucket->get("submit")) {
		$class->{_}->core->set_value(
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
			$fobj->bucket->get("templates/template")
		);
	
		$class->gholders->register("message","updating content...");
	}

	$class->gholders->register("template",$template->cachable);
}

#----------

sub f_qopts {
	my $class = shift;
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $class->load_look(
		$fobj->bucket->get("templates/look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("templates/template")
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

		$class->{_}->core->set_value(
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
		my @keys = keys(%{$def_qopts->{$g}});
		while ( my ($opt,$oref) = each %$gref ) {
			if ( my $d = $def_qopts->{ $g }{ $opt } ) {
				$class->gholders->register("qopt.".$g.".".$opt , $d);
				push @{$o->{def}}, [ "$g".".".$opt , $g , $opt ];
			} else {
				$class->gholders->register(
					"unregistered.$g.$opt" , {glomule=>$g,opt=>$opt}
				);
				push @{$o->{all}}, [ "$g".".".$opt , $g , $opt ];
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

	$class->gholders->register(
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
		$fobj->bucket->get("templates/look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("templates/template")
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

		$class->{_}->core->set_value(
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

			$class->{_}->core->set_value(
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
				$class->{_}->core->set_value(
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
			$class->{_}->core->set_value(
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
			$class->gholders->register(
				["qkey.".$i , { pos => $i , name => $n }]
			);
			push @o, $i;
			$i++;
		}

		$class->gholders->register(["qkey",\@o]);
	}

	$class->gholders->register("name_options",$name_options);

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

	my $objname = $class->{_}->core->get_object_for_type($type);

	if (!$objname) {
		$class->{_}->bail("Couldn't find object name for $type");
	}

	my $g = $class->{_}->objects->create(
		"Glomule::Type::".$objname,
		$class->{_}->cswitchboard->accessors,
		$glomule
	)->activate_functions;

	if ( my $ref = $g->_is_function( $i->args->{function} ) ) {
		my $q = $ref->qopts;

		foreach my $q (@{ $ref->qopts }) {
			$qopts->{ $g->id }{ $q->{opt} } = 1;
		}
	} else {
		$class->{_}->bail->(
			"Unknown glomule function: "
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

	my $look = $class->{_}->instance->new_object("Look");
	$look->{id} = $id;

	# look wants the original container, not admin
	$class->{_}->cswitchboard->reroute_calls_for($look);

	return $look;
}

#----------

sub qopts_main {
	my $class = shift;

	return [

	];
}

sub qopts_looks {
	my $class = shift;

	return [
		{
			opt		=> "new_default",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "New Default Look ID",
		},
	];
}

#----------

sub qopts_templates {
	my $class = shift;

	return [
		{
			opt		=> "look",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Look",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "template",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Template",
			class	=> "templates",
			persist	=> 1,
		},
	];
}

#----------

sub qopts_templates_new {
	my $class = shift;

	return [
		{
			opt		=> "look",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Look",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "submit",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Submit New Template",
			persist	=> 0,
		},
		{
			opt		=> "path",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Path",
			persist	=> 0,
		},
		{
			opt		=> "type",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Type",
			persist	=> 0,
		},
		{
			opt		=> "content",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Content",
			persist	=> 0,
		},
	];
}

#----------

sub qopts_templates_edit {
	my $class = shift;

	return [
		{
			opt		=> "look",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Look",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "template",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Template",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "submit",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Submit Edited Template",
			persist	=> 0,
		},
		{
			opt		=> "content",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Content of Edited Template",
			persist	=> 0,
		},
	];
}

#----------

sub qopts_qopts {
	my $class = shift;
	return [
		{
			opt		=> "look",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Look",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "template",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Template",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "edit",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Edit Query Option",
			persist	=> 0,
		},
		{
			opt		=> "add",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Add Query Option",
			persist	=> 0,
		},
		{
			opt		=> "glomule",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Option",
			persist	=> 1,
		},
		{
			opt		=> "opt",
			allowed	=> '\w+',
			d_value	=> undef,
			desc	=> "Option",
			persist	=> 1,
		},
		{
			opt		=> "name",
			allowed	=> '\w+',
			d_value	=> undef,
			desc	=> "Option",
			persist	=> 0,
		},
	];
}

#----------

sub qopts_qkeys {
	my $class = shift;
	return [
		{
			opt		=> "look",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Look",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "template",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Template",
			class	=> "templates",
			persist	=> 1,
		},
		{
			opt		=> "add",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Add Query Key",
			persist	=> 0,
		},
		{
			opt		=> "edit",
			allowed	=> '.*',
			d_value	=> undef,
			desc	=> "Edit Query Key",
			persist	=> 0,
		},
		{
			opt		=> "name",
			allowed	=> '\w+',
			d_value	=> undef,
			desc	=> "Name",
			persist	=> 0,
		},
		{
			opt		=> "pos",
			allowed	=> '\d+',
			d_value	=> undef,
			desc	=> "Position",
			persist	=> 0,
		},
	];
}

#----------

1;
