package eThreads::Object::Mode::Admin;

@ISA = qw( eThreads::Object::Mode );

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;
	my $path = shift;

	$class = bless({
		_		=> $data,
		path	=> $path || undef,
	},$class);

	return $class;
}

#----------

sub activate {
	my $class = shift;

	# activate our functions
	
}

#----------

sub go {
	my $class = shift;

	# authenticate is responsible for checking if they've already provided 
	# the proper authentication tokens.  if they haven't we call unauthorized, 
	# which is responsible for printing a login (be it a page or just sending 
	# WWW-Authenticate) for the user.

	my $user = $class->{_}->auth->authenticate
		or return $class->{_}->auth->unauthorized;

	# if we've gotten here they authenticated fine, now we need to figure 
	# out what container we're accessing before we check admin rights

	$class->{_}->switchboard->register("ocontainer",
		$class->determine_container()
	);

	# we also load our default admin container

	$class->{_}->switchboard->register("container",
		$class->load_admin_container
	);

	# create a custom switchboard with container as container for modules that 
	# need things that way

	my $cswitchboard = $class->{_}->switchboard->custom;
	$cswitchboard->register("container",$class->{_}->ocontainer);

	$class->{_}->switchboard->register("cswitchboard",$cswitchboard);

	# give this custom board to the user object
	$cswitchboard->reroute_calls_for($user);

	# now check if they have rights

	if (!$user->has_rights("admin")) {
		$class->{_}->core->bail("Insufficient rights");
	}

	# if we made it this far, we're ok to be here and we can go ahead 
	# and show a menu

	# use the admin container to determine look and then the 
	# appropriate template

	$class->{_}->switchboard->register("look",
		$class->{_}->container->determine_look()
	);

	$class->{_}->switchboard->register("template",
		$class->{_}->look->determine_template()
	);

	# load the content type module
	$class->{_}->switchboard->register("content_type",
		$class->{_}->template->type
	);

	# now let our content run so there'll be something to run through

	my $g = $class->{_}->instance->new_object(
		"Glomule::Type::Admin",'.ADMIN'
	)->activate;

	$g->connect_to_gholders($class->{_}->gholders);

	if ( my $ref = $g->is_function( $class->{_}->template->path ) ) {
		$ref->activate->execute();
	} else {
		$class->{_}->core->bail(
			"Unknown admin glomule function: "
			. $class->{_}->template->path
		);
	}

	# now handle the template tree and generate our actual content
	
	my $content;
	$class->{_}->gholders->handle_template_tree(
		$class->{_}->template->get_tree,
		$content
	);

	my $r = $class->{_}->ap_request;

	$r->content_type( $class->{_}->template->type->type );
	$r->print($content);

	return Apache::OK;
}

#----------

sub load_admin_container {
	my $class = shift;

	# load an empty container
	my $c = $class->{_}->instance->new_object("Container");

	# load the container cache...  this should already be in mem
	my $gh = $class->{_}->cache->load_cache_file(tbl=>"containers");

	if (!$gh) {
		$gh = $class->{_}->instance->cache_containers();
	}

	$c->{id} = $gh->{".ADMIN"} 
		or $class->{_}->core->bail("Admin Container not found.");

	return $c;
}

#----------

1;
