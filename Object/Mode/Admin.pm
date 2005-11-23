package eThreads::Object::Mode::Admin;

use eThreads::Object::Mode -Base;
no warnings;

#----------

const 'IS_ADMIN' => 1;

sub new {
	my $data = shift;
	my $path = shift;

	$self = bless({
		_		=> $data,
		path	=> $path || undef,
	},$self);

	return $self;
}

#----------

sub go {
	# authenticate is responsible for checking if they've already provided 
	# the proper authentication tokens.  if they haven't we call unauthorized, 
	# which is responsible for printing a login (be it a page or just sending 
	# WWW-Authenticate) for the user.

	my $user = $self->_->auth->authenticate
		or return $self->_->auth->unauthorized;

	$self->_->switchboard->register("user",$user);

	# if we've gotten here they authenticated fine, now we need to figure 
	# out what container we're accessing before we check admin rights

	$self->_->switchboard->register("ocontainer",
		$self->determine_container()
	);

	# we also load our default admin container

	$self->_->switchboard->register("container",
		$self->load_admin_container
	);

	# create a custom switchboard with container as container for modules that 
	# need things that way

	my $cswitchboard = $self->_->switchboard->custom;
	$cswitchboard->register("container",$self->_->ocontainer);

	$self->_->switchboard->register("cswitchboard",$cswitchboard);

	# give this custom board to the user object
	$cswitchboard->reroute_calls_for($user);

	# now check if they have rights

	if (!$user->has_rights("admin")) {
		$self->_->bail->("Insufficient rights");
	}

	# if we made it this far, we're ok to be here and we can go ahead 
	# and show a menu

	# use the admin container to determine look and then the 
	# appropriate template

	$self->_->switchboard->register("look",
		$self->_->container->determine_look()
	);

	$self->_->switchboard->register("template",
		$self->_->look->determine_template()
	);

	# load the content type module
	$self->_->switchboard->register("content_type",
		$self->_->template->type
	);

	# now let our content run so there'll be something to run through

	my $g = $self->_->glomule->load(
		type	=> 'admin',
		name	=> '.ADMIN',
	);

	$g->gholders($self->_->gholders);

	if ( my $func = $g->has_function( $self->_->template->path ) ) {
		$func->activate->execute();
	} else {
		$self->_->bail->(
			"Unknown admin glomule function: "
			. $self->_->template->path
		);
	}

	# now handle the template tree and generate our actual content
	
	my $content;
	$self->_->gholders->handle_template_tree(
		$self->_->template->get_tree,
		$content
	);

	my $r = $self->_->ap_request;

	$r->content_type( $self->_->content_type->type );
	$r->print($content);

	return $self->_->core->code('OK');
}

#----------

sub load_admin_container {
	# load an empty container
	my $c = $self->_->new_object("Container");

	my $d = 
		( $self->_->domain->id == $self->_->settings->{default_domain}{id} )
			? $self->_->domain
			: $self->_->new_object('Domain',
				%{$self->_->core->get_default_domain}
			  );

	my $containers = $d->load_containers;

	$c->{id} = $containers->{'.ADMIN'}
		or $self->_->bail->("Admin Container not found.");

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
