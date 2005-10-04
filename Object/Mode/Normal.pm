package eThreads::Object::Mode::Normal;

use eThreads::Object::Mode -Base;

#----------

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
	# figure out container, look, and then template
	$self->_->switchboard->register("container",
		$self->determine_container()
	);

	$self->_->switchboard->register("look",
		$self->_->container->determine_look()
	);

	my $content;
	if ( $self->_->xmlfunc->uri_has_xml_prefix ) {
		$content = $self->handle_xml_function;
	} else {
		$content = $self->handle_template;
	}

	my $r = $self->_->ap_request;

	$r->set_last_modified( $self->_->last_modified->get );

	$r->content_type( $self->_->content_type->type );
	$r->print($content);

	return $self->_->core->code('OK');
}

#----------

sub handle_xml_function {
	my $xmlfunc = $self->_->xmlfunc->determine_function;


}

#----------

sub handle_template {
	$self->_->switchboard->register("template",
		$self->_->look->determine_template()
	);

	# load the content type module
	$self->_->switchboard->register("content_type",
		$self->_->template->type
	);

	# the walker phase of operation here has to be broken up into two steps.  
	# in step one you initialize the modules for glomules and plugins that 
	# are going to need to run.  we load them and activate them, but don't 
	# handle running the glomule functions.  we do this so that the plugins 
	# can sink their teeth into the appropriate places before the glomules 
	# have a chance to run.  

	# then we walk back through and run functions for both glomules and 
	# plugins.

	# first, though, we need a clone of our template tree so that we can 
	# store information like objects in their proper places

	my $shadow = $self->_->template->shadow_tree;

	# -- walk the template to see what we're using -- #

	{
		my $walker = $self->_->instance->new_object("Template::Walker");

		foreach my $t (keys %{$self->_->settings->{glomule_types}}) {
			# -- register the walker -- #
			$walker->register(
				[ $t , sub { return $self->prewalk_glomule($t,@_); } ]
			);
		}

		# register plugin walker
		$walker->register(
			['plugin', sub { return $self->prewalk_plugin(@_); } ]
		);

		$walker->walk_template_tree(
			$shadow
		);
	}

	{
		my $walker = $self->_->instance->new_object("Template::Walker");

		foreach my $t (keys %{$self->_->settings->{glomule_types}}) {
			# -- register the walker -- #
			$walker->register(
				[ $t , sub { return $self->walk_glomule($t,@_); } ]
			);

			# -- and also register the handler -- #
			$self->_->gholders->register(
				[ $t , sub { return $self->handle_glomule($t,@_); } ]
			);
		}

		# register plugin walker
		$walker->register(['plugin', sub { return $self->walk_plugin(@_); } ]);
		$self->_->gholders->register(
			['plugin',sub { return undef; }]
		);

		$walker->walk_template_tree(
			$shadow
		);
	}

	# -- now actually process the template -- #

	my $content;
	$self->_->gholders->handle_template_tree(
		$shadow,
		$content
	);

	return $content;
}

#----------

sub handle_glomule {
	my $type = shift;
	my $i = shift;

	my $glomule = $i->args->{name} || $i->args->{glomule};

	my $ctx = $self->_->gholders->get_context;
	my $gctx = $i->note('ctx');

	$self->_->gholders->set_context($gctx) 
		if ($gctx);

	$self->_->gholders->handle_template_tree($i,$_[0]);

	$self->_->gholders->set_context($ctx)
		if ($gctx);;

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
