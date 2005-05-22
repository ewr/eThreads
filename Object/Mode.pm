package eThreads::Object::Mode;

use strict;

use eThreads::Object::Mode::Admin;
use eThreads::Object::Mode::Auth;
use eThreads::Object::Mode::Normal;

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

sub prewalk_plugin {
	my $class = shift;
	my $i = shift;

	my $type = $i->args->{type} || $i->args->{DEFAULT};
	my $named = $i->args->{ctx};

	my $obj = $class->{_}->plugins->load($type,i=>$i)
		or $class->{_}->bail->("Plugin didn't load: $type");

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

	$swb->register('rctx',$rctx);

	$swb->reroute_calls_for($obj);

	# -- activate the plugin -- #
	
	$class->{_}->objects->activate($obj);

	# -- register plugin in shadow item notes -- #

	$i->note('object',$obj);
}

#----------

sub walk_plugin {
	my $class = shift;
	my $i = shift;

	my $obj = $i->note("object");

	if ($obj->can("activate_walk")) {
		$obj->activate_walk;
	}

	return 1;
}

#----------

sub prewalk_glomule {
	my $class = shift;
	my $type = shift;
	my $i = shift;

	my $glomule = $i->args->{name} || $i->args->{glomule};
	my $named = $i->args->{ctx};

	# -- try to load the glomule -- #

	my $g = $class->{_}->glomule->load(
		type	=> $type,
		name	=> $glomule,
		i		=> $i
	);

	# -- get an empty context under the plugin space -- #

	my $ctx = $class->{_}->gholders->get_unused_child("glomule." . $type);

	my $rctx = $class->{_}->instance->new_object(
		"GHolders::RegisterContext"
	)->set($ctx);

	$g->connect_to_gholders($rctx);

	$class->{_}->gholders->register([$ctx,1]);

	if ($named) {
		$class->{_}->gholders->new_named_ctx($named,$ctx);
	}

	# set our object in the ObjectTree
	$i->note("object",$g);
	$i->note("ctx",$ctx);

	return 1;
}

#----------

sub walk_glomule {
	my $class = shift;
	my $type = shift;
	my $i = shift;

	#$class->{_}->instance->check_rights_for_glomule($glomule);

	my $g = $i->note("object")
		or $class->{_}->bail->("Couldn't find object in walk");

	if ( my $func = $g->has_function( $i->args->{function} ) ) {
		$func->execute( $i->args );
	} else {
		$class->{_}->bail->(
			"Unknown glomule function: "
		#	. $glomule
		#	. "/"
		#	. $i->args->{function}
		);
	}
}

#----------

=head1 NAME

eThreads::Object::Mode

=head1 SYNOPSIS

=head1 DESCRIPTION

The object contains functionality generic to multiple modes.  It cannot be 
used directly, but should instead be used in @ISA for Mode objects.

=over 4

=item IS_ADMIN 

Returns 0.  Only the Admin mode should set this true.

=item path

Return the mode's path string.

=item mode 

Return the name of our mode.

=item determine_container 

Figure out what our container is.  Create and return a new object for it.

=item get_container 

	my $obj = $mode->get_container("/foo");

Get an object for the container at "/foo".  If none is found, returns undef;

=item walk_plugin

Should be registered as the walker for "plugin".  Creates an object for the 
plugin and makes the proper function call.

=item walk_glomule

	$walker->register(['blog',sub { $class->walk_glomule("blog",@_); }]);

Should be registered as the walker for each glomule type.  Creates an 
object for the glomule and makes the proper function call.  

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
