package eThreads::Object::Glomule::Type::Admin;

use Spiffy -Base;

use base 'eThreads::Object::Glomule::Type';

no warnings;

#----------

field '_'		=> -ro;

sub new {
	my $data = shift;
	my $name = shift;

	$self = bless( { 
		_		=> $data,
		name	=> $name || undef,
		id		=> undef,
	} , $self);

	return $self;
}

#----------

sub activate {
	return $self;
}

#----------

sub f_main {
	my $fobj = shift;

	# do nothing for now
}

#----------

sub f_looks {
	my $fobj = shift;

	# get info on the looks for this container
	my $looks = $self->_->ocontainer->get_looks;

	# -- see if we're creating a new look -- #

	if ( $fobj->bucket->get('create') ) {
		warn "creating look\n";
		if ( $self->_create_look($fobj->bucket->get('name')) ) {
			$fobj->gholders->register('message',"New look created");
			warn "created look\n";
			$looks = $self->_->ocontainer->get_looks;
		} else {
			warn "no look created\n";
		}
	} else {
		# do nothing
	}

	# -- see if we're setting a default -- #

	if ( my $id = $fobj->bucket->get("new_default") ) {
		# first, make sure this is a legal value
		if ($looks->{id}{ $id }) {
			# it's legit...  set default
			my $db = $self->_->core->get_dbh;

			my $update = $db->prepare("
				update " . 
					$self->_->core->tbl_name("looks") . 
				" set is_default = ? where id = ?
			");

			$update->execute( 0 , $looks->{ DEFAULT }->{id} );
			$update->execute( 1 , $id );

			$self->_->cache->update_times->set(
				tbl		=> "looks",
				ts		=> time,
			);

			$fobj->gholders->register(
				"message",
				"Successfully set default look to " . $looks->{$id}->{name}
			);

			# now we need to re-retrieve the looks so we get the new default
			$looks = $self->_->ocontainer->get_looks;
		} else {
			$self->_->bail->("Attempted to make invalid look default.");
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
	my $fobj = shift;

	# -- get a list of templates -- #
	my $look = $self->load_look(
		$fobj->bucket->get("look")
	);

	# -- templates -- #

	{
		my $tm = $look->get_templates;

		my @o;
		while ( my ($p,$obj) = each %$tm ) {
			next if ($p =~ m!^\.!);

			my $link = $self->_->queryopts->link("/templates/edit",{
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

			my $link = $self->_->queryopts->link("/subtemplates/edit",{
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
	my $fobj = shift;

	# -- load the look -- #
	my $look = $self->load_look(
		$fobj->bucket->get("look")
	);

	if ($fobj->bucket->get("submit")) {
		# get our data
		my $path = $fobj->bucket->get("path");
		my $type = $fobj->bucket->get("type");
		my $content = $fobj->bucket->get("content");
		
		# check if path is valid
		$self->_->bail->("Invalid Path: $path") 
			if ($path !~ m!^[\w/\.]+$!);

		# make sure path doesn't already exist
		my $tm = $look->get_templates;
		$self->_->bail->("Path already exists: $path") 
			if ($tm->{ $path });

		# make sure content type is valid
		$self->_->bail->("Invalid content type: $type") 
			if (!$self->_->settings->{content_types}{ $type });

		# now create the new template
		my $db = $self->_->core->get_dbh;
		my $insert = $db->prepare("
			insert into " . $self->_->core->tbl_name("templates") . "(
				id,look,name,c_type,value
			) values(0,?,?,?,?)
		");

		$insert->execute($look->id,$path,$type,$content) 
			or $self->_->bail->("new template failed: ".$db->errstr);

		# FIXME - This should be a better interface
		my $id = $self->_->core->{db}->get_message_id();

		$self->_->cache->update_times->set(
			tbl		=> "templates",
			first	=> $look->id,
			ts		=> time,
		);
	
		$fobj->gholders->register("message","created new template");
	} else {
		# prepare a list of content types

		my @o;
		while ( my ($k,$v) = each %{$self->_->settings->{content_types}} ) {
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
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $self->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("template")
	);

	$self->_->bail->("Invalid template") if (!$template);

	if ($fobj->bucket->get("submit")) {
		$self->_->utils->set_value(
			tbl		=> "templates",
			keys	=> {
				id	=> $template->id,
			},
			value	=> $fobj->bucket->get("content")
		);

		$self->_->cache->update_times->set(
			tbl		=> "templates",
			first	=> $look->id,
			second	=> $template->id,
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
	my $fobj = shift;

	# -- load the look -- #
	my $look = $self->load_look(
		$fobj->bucket->get("look")
	);

	if ($fobj->bucket->get("submit")) {
		# get our data
		my $path = $fobj->bucket->get("path");
		my $content = $fobj->bucket->get("content");
		
		# check if path is valid
		$self->_->bail->("Invalid Path: $path") 
			if ($path !~ m!^[\w/]+$!);

		# make sure path doesn't already exist
		my $tm = $look->get_subtemplates;
		$self->_->bail->("Path already exists: $path") 
			if ($tm->{ $path });

		# now create the new template
		my $db = $self->_->core->get_dbh;
		my $insert = $db->prepare("
			insert into " . $self->_->core->tbl_name("subtemplates") . "(
				id,look,name,value
			) values(0,?,?,?)
		");

		$insert->execute($look->id,$path,$content) 
			or $self->_->bail->("new template failed: ".$db->errstr);

		# FIXME - This should be a better interface
		my $id = $self->_->core->{db}->get_message_id();

		$self->_->cache->update_times->set(
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
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $self->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_subtemplate(
		$fobj->bucket->get("template")
	);

	$self->_->bail->("Invalid template") if (!$template);

	if ($fobj->bucket->get("submit")) {
		$self->_->utils->set_value(
			tbl		=> "subtemplates",
			keys	=> {
				id	=> $template->id,
			},
			value	=> $fobj->bucket->get("content")
		);

		$self->_->cache->update_times->set(
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
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $self->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("template")
	);

	$self->_->bail->("Invalid template") if (!$template);

	# now what we need is to know what glomules and functions are referenced 
	# in the template, so that we can come up with a list of all qopts the 
	# functions want and present the unregistered ones as options

	my $qopts = $template->qopts;

	# we'll stop for a second here to do our registers and edits

	if ($fobj->bucket->get("add") || $fobj->bucket->get("edit")) {
		my $g = $fobj->bucket->get("glomule");
		my $o = $fobj->bucket->get("opt");
		my $f = $fobj->bucket->get("func");
		my $n = $fobj->bucket->get("name");

		$self->_->utils->set_value(
			tbl		=> "qopts",
			keys	=> {
				glomule		=> $g,
				opt			=> $o,
				function	=> $f,
				template	=> $template->id,
			},
			value_field	=> "name",
			value	=> $n,
		);

		$self->_->cache->update_times->set(
			tbl		=> "qopts",
			first	=> $template->id,
			ts		=> time,
		);
	}

	my $nameref = $qopts->names;
	
	my @names;
	while ( my ($name,$opts) = each %$nameref ) {
		my @nameopts;
		# run through each opt registered to this name
		foreach my $o (@$opts) {
			my $ctx = $fobj->gholders->get_unused_child('qopt.'.$name);

			my $gname = $self->_->ocontainer->glomule_id2n( $o->glomule );

			$fobj->gholders->register($ctx,{
				glomule	=> {
					name	=> $gname,
					id		=> $o->glomule,
				},
				func	=> $o->func,
				opt		=> $o->opt,
				name	=> $name
			});
			push @nameopts, [$gname,$o->func,$o->opt,'/'.$ctx];
		}

		my $registeropts;
		if (@nameopts > 1) {
			@nameopts = 
				map { $_->[3] } 
				sort { $a->[0].$a->[1].$a->[2] cmp $b->[0].$b->[1].$b->[2] }
				@nameopts;

			$registeropts = \@nameopts;
		} else {
			$registeropts = [ $nameopts[0][3] ];
		}

		$fobj->gholders->register( 'qopt.'.$name , {
			opts	=> $registeropts,
			name	=> $name
		} );

		push @names, '/qopt.'.$name;
	}

	$fobj->gholders->register( 'qopt' , [ sort @names ] );
}

#----------

sub f_qkeys {
	my $fobj = shift;

	# -- load the template, but first the look -- #
	my $look = $self->load_look(
		$fobj->bucket->get("look")
	);

	my $template = $look->load_template(
		$fobj->bucket->get("template")
	);

	$self->_->bail->("Invalid template") if (!$template);

	# we need a list of names mapped to qopts so that we know what 
	# names to allow qkeys to be pointed to.  qkey -> name -> qopt.

	my $qopts = $template->qopts;

	my $names = {};
	my $name_options = '';
	foreach my $name ( sort keys %{ $qopts->names } ) {
		$names->{ $name } = 1;
		$name_options .= qq(<option value="$name">$name</option>);
	}

	# get a list of defined qkeys...
	my $qkeys = $template->qkeys;

	# -- check for updates -- #
	if ($fobj->bucket->get("add")) {
		my $name = $fobj->bucket->get("name");

		# make sure this is a legal name
		if (!$names->{ $name }) {
			$self->_->bail->("Invalid qkey name: $name");
		}
	
		# we need to know what position to make this
		my $count = @$qkeys + 1;

		$self->_->utils->set_value(
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
				$self->_->bail->("Invalid qkey name: $name");
			}

			$self->_->utils->set_value(
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
				$self->_->utils->set_value(
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
			$self->_->utils->set_value(
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
		$self->_->cache->update_times->set(
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
	if (!$self->_->switchboard->knows('user')) {
		$self->_->bail->("Invalid rights.");
	}

	if ( !$self->_->user->has_rights('maint') ) {
		$self->_->bail->("Invalid rights.");
	} 

	return $self;
}

sub f_maint {
	my $fobj = shift;

	$self->_check_maint_rights;

	# do nothing
}

#----------

sub f_maint_containers {
	my $fobj = shift;

	$self->_check_maint_rights;

	# -- get a list of containers -- #

	my $c = $self->_->instance->load_containers(0);
	$fobj->gholders->register(['containers',$c]);
}

#----------

sub f_maint_domains {
	my $fobj = shift;

	$self->_check_maint_rights;
}

#----------

sub _create_look {
	my $name = shift;

	# -- make sure we got a name -- #
	
	if (!$name) {
		$self->_->gholders->register('message','Illegal name for new look.');
		return undef;
	}

	# -- make sure look name doesn't already exist -- #

	if ( my $look = $self->_->ocontainer->is_valid_look_name($name) ) {
		$self->_->gholders->register(
			'message',
			'A look with that name already exists.'
		);

		return undef;
	}

	# -- if we're still here, create the look -- #

	my $create = $self->_->core->get_dbh->prepare("
		insert into 
			" . $self->_->core->tbl_name('looks') . "
		(container,name,is_default) 
		values(?,?,0)
	");

	$create->execute($self->_->ocontainer->id,$name)
		or $self->_->bail->("create_look failure: " . $create->errstr);

	# update timestamp on looks
	$self->_->cache->update_times->set(
		tbl	=> "looks",
		ts	=> time,
	);

	return 1;
}

#----------

sub load_look {
	my $id = shift;

	# validate this look
	$self->_->ocontainer->is_valid_look($id)
		or $self->_->bail->("Look not found/improper ownership: $id");

	my $look = $self->_->instance->new_object("Look");
	$look->{id} = $id;

	# look wants the original container, not admin
	$self->_->cswitchboard->reroute_calls_for($look);

	return $look;
}

#----------

1;
