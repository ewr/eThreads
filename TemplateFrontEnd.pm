package eTrevolution::TemplateFrontEnd;

use strict;
use vars qw( $core );

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Const -compile => qw(OK);

use eTrevolution::eThreads::Core;

sub child_init {
	my ($child_pool,$s) = @_;

	$core = new eTrevolution::eThreads::Core;

	return Apache::OK;
}

sub handler {
	my $r = shift;

	$core = new eTrevolution::eThreads::Core if (!$core);

	my $inst = $core->load_instance_objects;

	$inst->{gholders}->register(
		['template', sub { return &handle_template($inst,@_); }]
	);

	$r->content_type("text/html");

	my $content;
	$inst->{gholders}->handle_template_tree(
		$inst->{template}->get_tree,
		$content
	);

	$r->print($content);

	$r->connection->notes->set(
		'container/id'		=> $inst->{container}{id}
	);
	$r->connection->notes->set(
		'container/name'	=> $inst->{container}{name}
	);

	$inst->DESTROY;

	return Apache::OK;
}

sub handle_template {
	my $inst = shift;
	my $i = shift;

	my $tmplt = $inst->new_object("Template",$i->args->{DEFAULT});

	if ($tmplt->load_from_sub($inst)) {
		return $inst->{gholders}->handle_template_tree(
			$tmplt->get_tree,$_[0]
		);
	} else {
		return undef;
	}
}

1;

