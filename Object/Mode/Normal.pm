package eThreads::Object::Mode::Normal;

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
		container	=> undef,
		look		=> undef,
		template	=> undef,
	},$class);

	return $class;
}

#----------

sub go {
	my $class = shift;
	my $r = shift;

	# figure out container, look, and then template
	$class->{_}->switchboard->register("container",
		$class->determine_container()
	);

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

	# -- walk the template to see what glomules we're using -- #

	my $walker = $class->{_}->instance->new_object("Template::Walker");

	foreach my $t (keys %{$class->{_}->settings->{glomule_types}}) {
		# -- register the walker -- #
		$walker->register(
			[ $t , sub { return $class->walk_glomule($t,@_); } ]
		);

		# -- and also register the handler -- #
		$class->{_}->gholders->register(
			[ $t , sub { return $class->handle_glomule($t,@_); } ]
		);
	}

	# register plugin walker
	$walker->register(['plugin', sub { return $class->walk_plugin(@_); } ]);
	$class->{_}->gholders->register(
		['plugin',sub { return undef; }]
	);

	$walker->walk_template_tree(
		$class->{_}->template->get_tree
	);

	# -- now actually process the template -- #

	my $content;
	$class->{_}->gholders->handle_template_tree(
		$class->{_}->template->get_tree,
		$content
	);

	my $r = $class->{_}->ap_request;

	$r->set_last_modified( $class->{_}->last_modified->get );

	$r->content_type( $class->{_}->content_type->type );
	$r->print($content);

	return Apache::OK;
}

#----------

sub handle_glomule {
	my $class = shift;
	my $type = shift;
	my $i = shift;

	my $glomule = $i->args->{name} || $i->args->{glomule};

	my $ctx = $class->{_}->gholders->get_context;
	$class->{_}->gholders->set_context($type.".".$glomule);

	$class->{_}->gholders->handle_template_tree($i,$_[0]);

	$class->{_}->gholders->set_context($ctx);

	return undef;
}

#----------

#----------

#----------

=head1 NAME

eThreads::Object::Mode::Normal

=head1 SYNOPSIS

	my $mode = $inst->new_object("Mode::Normal");

	$mode->go;

=head1 DESCRIPTION

This is the Normal mode, which is the default.  The mode object executes 
the core of eThreads functionality.

=over 4

=item new 

Returns a new blessed ref for a Mode::Normal object.

=item go 

Determine container, look, and template.  Create and execute a walker and then 
a handler for plugin and glomule types.  Returns an Apache status.  Gets the 
last_modified time and sets it with Apache.  Prints the handled template 
content.  Basically makes things go.  Duh.

Registers the following Switchboard objects:

	* container
	* look
	* template
	* content_type

=item handle_glomule 

Registered internally as a handler for glomule types.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
