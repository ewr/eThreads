package eThreads::Object::Mode;

use strict;

#----------

sub IS_ADMIN { 0; }

sub new {
	die "Cannot directly load Mode object\n";
}

#----------

sub path {
	return shift->{path};
}

#----------

sub mode {
	my $class = shift;
	my ($mode) = ref($class) =~ m!::([^:]+)$!;
	return $mode;
}

#----------

sub determine_container {
	my $class = shift;

	# -- load a blank container object -- #

	my $c = $class->{_}->instance->new_object("Container");

	# -- load our container cache -- #

	my $gh = $class->{_}->instance->load_containers();

	# -- match as much container as possible -- #

	my $container = $class->{root}{name};
	{
		my @parts = split( "/" , $class->{_}->RequestURI->unclaimed );

		foreach my $p (@parts) {
			next if (!$p);
			my $test = $container . "/" . $p;
			if ($gh->{$test}) {
				$container = $test;
			} else {
				last;
			}
		}

		$container = "/" if (!$container);
	}

	$class->{_}->RequestURI->claim($container);

	my $c = $class->get_container($container);

	#$c->{path} = $container;
	#$c->{id} = $gh->{$container};

	return $c;	
}

#----------

sub get_container {
	my $class	= shift;
	my $path 	= shift;

	my $gh = $class->{_}->instance->load_containers();

	my $c = $class->{_}->instance->new_object(
		"Container",
		path	=> $path,
		id		=> $gh->{ $path },
	);

	return $c;
}

#----------

sub walk_plugin {
	my $class = shift;
	my $i = shift;

	my $type = $i->args->{type} || $i->args->{DEFAULT};
	my $named = $i->args->{ctx};
	
	my $module = $class->{_}->settings->{plugins}{ $type };

	if (!$module) {
		warn "invalid plugin type called: $type\n";
		return undef;
	}

	# -- get an empty context under the plugin space -- #

	my $ctx = $class->{_}->gholders->get_unused_child("plugin." . $type);

	# -- if we want a named context, create that -- #

	if ($named) {
		$class->{_}->gholders->register_blank($ctx);
		$class->{_}->gholders->new_named_ctx($named,$ctx);
	}

	# -- create a register context for the plugin -- #

	my $rctx = $class->{_}->instance->new_object(
		"GHolders::RegisterContext"
	)->set($ctx);

	# -- create a custom switchboard for the plugin -- #

	my $swb = $class->{_}->switchboard->custom;

	# -- connect the pieces together -- #

	$swb->register("rctx",$rctx);

	my $obj = $swb->new_object("Plugin::".$module,i=>$i);

	# -- activate the plugin -- #
	
	$class->{_}->objects->activate($obj);
}

#----------

sub walk_glomule {
	my $class = shift;
	my $type = shift;
	my $i = shift;

	my $core = $class->{_}->core;

	my $glomule = $i->args->{name} || $i->args->{glomule};
	my $named = $i->args->{ctx};

	$class->{_}->instance->check_rights_for_glomule($glomule);

	my $objname = $class->{_}->settings->{glomule_types}{ $type };

	if (!$objname) {
		$class->{_}->bail->("Couldn't find object name for $type");
	}

	my $ctx = $type.".".$glomule;

	my $rctx = $class->{_}->instance->new_object(
		"GHolders::RegisterContext"
	)->set($ctx);

	$class->{_}->gholders->register([$ctx,1]);

	if ($named) {
		$class->{_}->gholders->new_named_ctx($named,$ctx);
	}

	my $g = $class->{_}->instance->new_object(
		"Glomule::Type::".$objname,
		$glomule,
		$i
	)->activate;

	$g->connect_to_gholders($rctx);

	if ( my $ref = $g->functions->knows( $i->args->{function} ) ) {
		$ref->activate->execute( $i->args );
	} else {
		$class->{_}->bail->(
			"Unknown glomule function: "
			. $glomule
			. "/"
			. $i->args->{function}
		);
	}
}

#----------

1;
