package eThreads::Object::Mode;

use strict;

#----------

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

	my $gh = $class->{_}->cache->load_cache_file(tbl=>"containers");

	if (!$gh) {
		$gh = $class->{_}->instance->cache_containers();
	}

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

	$c->{path} = $container;
	$c->{id} = $gh->{$container};

	return $c;	
}

#----------


#----------

sub walk_glomule {
	my $class = shift;
	my $type = shift;
	my $i = shift;

	my $core = $class->{_}->core;

	$class->{_}->instance->check_rights_for_glomule($i->args->{glomule});

	my $objname = $class->{_}->core->get_object_for_type($type);

	if (!$objname) {
		$class->{_}->bail("Couldn't find object name for $type");
	}

	my $rctx = $class->{_}->instance->new_object(
		"GHolders::RegisterContext"
	)->set($type.".".$i->args->{glomule});

	my $g = $class->{_}->instance->new_object(
		"Glomule::Type::".$objname,
		$i->args->{glomule}
	)->activate;

	$g->connect_to_gholders($rctx);

	if ( my $ref = $g->is_function( $i->args->{function} ) ) {
		$ref->activate->execute( $i->args );
	} else {
		$class->{_}->bail(
			"Unknown glomule function: "
			. $i->args->{glomule}
			. "/"
			. $i->args->{function}
		);
	}
}

#----------

1;
