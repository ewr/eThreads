package eTrevolution::GlomuleHandler;

use strict;
use vars qw( $core );

use base qw(Apache::Filter);
use Apache::Const -compile => qw(OK);
use Apache::Connection;
use APR::Table;
use constant BUFF_LEN => 1024;

use eTrevolution::eThreads::Core;

sub init {
	my ($child_pool,$s) = @_;

	$core = new eTrevolution::eThreads::Core;

	return Apache::OK;
}

sub handler {
	my $f = shift;

	$core = new eTrevolution::eThreads::Core if (!$core);

	my $data;
	while ( $f->read( my $buffer, BUFF_LEN ) ) {
		$data .= $buffer;
	}

	# short-curcuit if this is the end
	if (!$data) {
		return Apache::OK;
	}

	my $inst = $core->load_instance_from_notes($f->c);

	$inst->{template} = $inst->new_object("Template");
	$inst->{template}{value} = $data;

	# -- walk the template to see what glomules we're using -- #

	my $walker = $inst->new_object("Template::Walker");

	foreach my $t (keys %{$core->{settings}{glomule_types}}) {
		# -- register the walker -- #
		$walker->register(
			[ $t , sub { return &walk_glomule($t,$inst,@_); } ]
		);

		# -- and also register the handler -- #
		$inst->{gholders}->register(
			[ $t , sub { return &handle_glomule($t,$inst,@_); } ]
		);
	}

	$walker->walk_template_tree(
		$inst->{template}->get_tree
	);

	# -- now actually process the template -- #

	if (0) {
		use Data::Dumper;
		open(DUMP,">/web/perl/eTrevolution/cached/dump");
		print DUMP Data::Dumper->Dump([$inst->{template}->get_tree]);
		close DUMP;
	}

	my $content;
	$inst->{gholders}->handle_template_tree(
		$inst->{template}->get_tree,
		$content
	);
	$f->print($content);

	$inst->DESTROY;

	return Apache::OK;
}

sub walk_glomule {
	my $type = shift;
	my $inst = shift;
	my $i = shift;

	$core->check_rights_for_glomule($inst,$i->args->{glomule});

	my $objname = $core->get_object_for_type($type);

	if (!$objname) {
		$core->bail("Couldn't find object name for $type");
	}

	my $rctx = $inst->new_object(
		"GHolders::RegisterContext"
	)->set($type.".".$i->args->{glomule});

	my $g = $inst->new_object(
		"Glomule::Type::".$objname,
		$i->args->{glomule}
	)->activate;

	$g->connect_to_gholders($rctx);

	if ( my $ref = $g->is_function( $i->args->{function} ) ) {
		$ref->( $i->args );
	} else {
		$core->bail(
			"Unknown glomule function: "
			. $i->args->{glomule}
			. "/"
			. $i->args->{function}
		);
	}
}

sub handle_glomule {
	my $type = shift;
	my $inst = shift;
	my $i = shift;

	my $ctx = $inst->{gholders}->get_context;
	$inst->{gholders}->set_context($type.".".$i->args->{glomule});

	$inst->{gholders}->handle_template_tree($i,$_[0]);

	$inst->{gholders}->set_context($ctx);

	return undef;
}

1;

