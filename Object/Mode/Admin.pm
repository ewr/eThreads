package eThreads::Object::Mode::Admin;

@ISA = qw( eThreads::Object::Mode );

use strict;

#----------

sub IS_ADMIN { 1; }

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
		$class->{_}->bail->("Insufficient rights");
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
		$class->{_}->bail->(
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

	$r->content_type( $class->{_}->content_type->type );
	$r->print($content);

	return Apache::OK;
}

#----------

sub load_admin_container {
	my $class = shift;

	# load an empty container
	my $c = $class->{_}->instance->new_object("Container");

	# load the container cache...  
	my $gh = $class->{_}->cache->get(tbl=>"containers");

	if (!$gh) {
		$gh = $class->{_}->instance->cache_containers();
	}

	$c->{id} = $gh->{".ADMIN"} 
		or $class->{_}->bail->("Admin Container not found.");

	return $c;
}

#----------

=head1 NAME

eThreads::Object::Mode::Admin

=head1 SYNOPSIS

=head1 DESCRIPTION

The Admin mode is used to administer eThreads.  It is hard-wired to make 
calls into the Admin glomule type.

=over 4

=item go 

In Admin mode, go takes the following steps:

=over 4

=item *

authenticates the user

=item *

determines the container to admin 

=item *

loads the admin container

=item *

creates a custom switchboard

=item *

reroutes the user object to the custom switchboard

=item *

checks if the user has admin rights for this container

=item *

determines look and template for admin container

=item *

creates a Glomule::Type::Admin object and executes the proper function

=item *

handles the template, prints it, and returns an Apache status

=back

The following items are registered to the switchboard:

=over 4

=item *

ocontainer (the container to be admin'ed)

=item *

container (the admin container)

=item *

cswitchboard (the custom switchboard)

=item *

look

=item *

template

=item *

content_type

=back

The custom switchboard has the following registered:

=over 4

=item * 

container (ocontainer from the main switchboard)

=back

=item load_admin_container 

Used internally to load the admin container object.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
