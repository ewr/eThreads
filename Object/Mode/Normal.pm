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

	$r->content_type( $class->{_}->template->type->type );
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

1;
