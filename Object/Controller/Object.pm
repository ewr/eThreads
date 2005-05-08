package eThreads::Object::Controller::Object;

use strict;

use eThreads::Object::Controller::Function;
use eThreads::Object::Controller::Pref;
use eThreads::Object::Controller::System;

use XML::XPath;

#----------

sub new {
	my $class = shift;
	my $data = shift;
	my $file = shift;

	$class = bless ( {
		file		=> undef,
		type		=> undef,
		object		=> undef,
		default		=> undef,
		systems		=> undef,
		functions	=> undef,
		_		=> $data,
	} , $class ); 

	$class->load($file);

	return $class;
}

#----------

sub type { shift->{type} }
sub object { shift->{object} }
sub default { shift->{default} }

#----------

sub functions {
	my $class = shift;

	# ok, so i really don't know if this is the best way to do this here, 
	# but i'm going to give it a shot for now.  Bottom line API-wise is 
	# that scalar context returns a hashref, while array context returns 
	# an array
	
	wantarray 
		? @{ $class->{functions} }
		: $class->{hfunctions};
}

#----------

sub has_function {
	my $class = shift;
	my $func = shift;

	$class->{hfunctions}{ $func };
}

#----------

sub systems {
	my $class = shift;
	wantarray ? @{ $class->{systems} } : $class->{systems};
}

#----------

sub prefs {
	my $class = shift;
	wantarray ? @{ $class->{prefs} } : $class->{prefs};
}

#----------

sub load {
	my $class 	= shift;
	my $file	= shift;

	# -- first load our controller file -- #

	my $cfile = 
		$class->{_}->settings->{dir}{controllers} . 
		"/" . 
		$file;

	my $xp = XML::XPath->new( filename => $cfile ) 
		or $class->{_}->bail("couldn't load xml controller: $cfile");

	my $c = $xp->find('/glomule')->get_node(1);

	$class->{type}		= $c->getAttribute( 'type' );
	$class->{object}	= $c->getAttribute( 'object' );

	$class->{systems} 		= $class->_parse_systems($c);
	$class->{functions}		= $class->_parse_functions($c);
	$class->{prefs}			= $class->_parse_prefs($c);

	$class->{hfunctions} = {};
	%{$class->{hfunctions}} = map { $_->name => $_ } @{ $class->{functions} };

	return $class;
}

#----------

sub _parse_systems {
	my $class = shift;
	my $c = shift;

	my $xsystems = $c->find('system');

	my $systems = [];

	foreach my $xs ($xsystems->get_nodelist) {
		my $svalues = {};

		# get attributes
		my $attrs = $xs->getAttributes;
		foreach my $a (@$attrs) {
			$svalues->{ $a->getName } = $a->getNodeValue;
		}

		push @$systems, $class->{_}->new_object(
			"Controller::System",%$svalues
		);
	}

	return $systems;
}

#----------

sub _parse_functions {
	my $class = shift;
	my $c = shift;

	my $xfunctions = $c->find('function');

	my $functions = [];

	foreach my $xf ($xfunctions->get_nodelist) {
		my $fvalues = {};

		# get attributes
		my $attrs = $xf->getAttributes;
		foreach my $a (@$attrs) {
			$fvalues->{ $a->getName } = $a->getNodeValue;
		}

		# now do children

		foreach my $c ( $xf->getChildNodes ) {
			next if ($c->getNodeType == XML::XPath::Node::TEXT_NODE);

			my $v;
			if ($c->getName eq "qopts") {
				$v = $class->_parse_qopts($c);
			} elsif ($c->getName eq "modes") {
				$v = $class->_parse_modes($c);
			} else {
				$v = $c->string_value;
			}

			$fvalues->{ $c->getName } = $v;
		}

		#$functions->{ $fvalues->{name} } = $class->{_}->new_object(
		push @$functions, $class->{_}->new_object(
			"Controller::Function",%$fvalues
		);
	}

	return $functions;
}

#----------

sub _parse_qopts {
	my $class = shift;
	my $xq = shift;

	my $opts = [];
	foreach my $o ( $xq->find('./opt')->get_nodelist ) {
		my $ovalues = {};

		# get attributes
		foreach my $a ( $o->getAttributes ) {
			$ovalues->{ $a->getName } = $a->getNodeValue;
		}

		foreach my $c ( $o->getChildNodes ) {
			next if ($c->getNodeType == XML::XPath::Node::TEXT_NODE);

			my $v;
			if (my $p = $c->find('.//pref')) {
				$v = $p->get_node(1)->string_value;
				$ovalues->{pref} = 1;
			} else {
				$v = $c->string_value;
			}

			$ovalues->{ $c->getName } = $v;
		}

		push @$opts, $class->{_}->new_object(
			"Controller::Function::Qopt",
			%$ovalues
		);
	}

	return $opts;
}

#----------

sub _parse_modes {
	my $class = shift;
	my $xm = shift;

	my $modes = [];
	foreach my $m ( $xm->find('./mode')->get_nodelist ) {
		my $mvalues = {};

		# get attributes
		foreach my $a ( $m->getAttributes ) {
			$mvalues->{ $a->getName } = $a->getNodeValue;
		}

		push @$modes, $class->{_}->new_object(
			"Controller::Function::Mode",
			%$mvalues
		);
	}

	return $modes;
}

#----------

sub _parse_prefs {
	my $class = shift;
	my $c = shift;

	my $xprefs = $c->find('./prefs/*');

	my $prefs = [];

	foreach my $xp ($xprefs->get_nodelist) {
		my $pvalues = {};

		# get attributes
		my $attrs = $xp->getAttributes;
		foreach my $a (@$attrs) {
			$pvalues->{ $a->getName } = $a->getNodeValue;
		}

		# now do children

		foreach my $c ( $xp->getChildNodes ) {
			next if ($c->getNodeType == XML::XPath::Node::TEXT_NODE);

			my $v;
			if ($c->getName eq "toggle") {
				$v = $class->_parse_toggle($c);
			} else {
				$v = $c->string_value;
			}

			$pvalues->{ $c->getName } = $v;
		}

		push @$prefs, $class->{_}->new_object(
			"Controller::Pref",%$pvalues
		);
	}

	return $prefs;
}

#----------

sub _parse_toggle {
	# TODO: ummm, this
}

#----------

=head1 NAME

eThreads::Object::Controller::Object;

=head1 SYNOPSIS

=head1 DESCRIPTION


=over 4


=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
