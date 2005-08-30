package eThreads::Object::Template::Qopts;

use Spiffy -Base, -XXX;

no warnings;

use strict;

#----------

field '_' => -ro;

sub new {
	my $data = shift;

	$self = bless ( {
		g		=> {},
		f		=> {},
		o		=> {},
		n		=> {},
		all		=> [],
		_		=> $data,
	} , $self ); 

	return $self;
}

#----------

sub register {
	my %args = @_;

	# we expect three args here...  glomule, gtype, and function.  Then we 
	# get opts, which is an arrayref to a list of opts.

	return undef if (!$args{glomule});

	foreach my $o ( @{ $args{opts} } ) {
		# create a new Qopt object
		my $obj = $self->_->new_object(
			"Template::Qopts::Opt", 
			orig	=> $o,
			glomule	=> $args{glomule},
			gtype	=> $args{gtype},
			func	=> $args{function}
		);

		# map by glomule
		$self->{g}{ $args{glomule} }{ $args{function} }{ $obj->name } = $obj;

		# map by function
		$self->{f}{ $args{function} }{ $args{glomule} }{ $obj->name } = $obj;

		# map by object key
		$self->{o}{ $obj->name }{ $args{glomule} }{ $args{function} } = $obj;

		# and throw it on the generic all array
		push @{$self->{all}}, $obj;
	}

	return 1;
}

#----------

sub debug {
	warn "debugging $self";
	use YAML;
	YAML::DumpFile("/tmp/namedump",$self->{all});
	die;
}

#----------

sub names {
	my $name = shift;

	my $names = {};
	foreach my $o ( @{ $self->{all} } ) {
		my $n = $o->name;
		if (my $aref = $names->{ $n }) {
			push @$aref, $o;
		} else {
			$names->{ $n } = [ $o ];
		}
	}

	return ($name) ? $names->{ $name } : $names;
}

#----------

sub glomule {
	my $glomule = shift;
	return ( $glomule ) ? $self->{g}{ $glomule } : $self->{g};
}

#----------

sub function {
	my $function = shift;
	return ( defined($function) ) ? $self->{f}{ $function } : $self->{f};
}

#----------

sub opt {
	my $opt = shift;
	return ( $opt ) ? $self->{o}{ $opt } : $self->{o};
}

#----------

sub dump {
	my $qopts = {};

	foreach my $o ( @{ $self->{all} } ) {
		# if we don't have an entry for this glomule/func, create one
		my $f;
		if (!$qopts->{ $o->glomule }{ $o->func }) {
			$f = $qopts->{ $o->glomule }{ $o->func } = {
				gtype	=> $o->gtype,
				opts	=> []
			};
		} else {
			$f = $qopts->{ $o->glomule }{ $o->func };
		}

		push @{ $f->{opts} } , [ $o->opt , $o->name ];
	}

	return $qopts;
}

#----------

sub restore {
	my $qopts = shift;

	# we get an array of arrayrefs.  these inner arrays contain three 
	# elements: glomule, glomule type, and function name.  We need to 
	# basically pretend we're getting a register on each of these, 
	# looking the actual Qopt object up from the Controller for the 
	# glomule type

	while ( my ($g,$gref) = each %$qopts ) {
		while ( my ($f,$fref) = each %$gref ) {
			my $func =
				$self->_->controller->get( $fref->{gtype} )->has_function( $f )
					or $self->_->bail->("Error restoring Template Qopts");

			$self->register(
				glomule		=> $g,
				function	=> $f,
				gtype		=> $fref->{gtype},
				opts		=> scalar $func->qopts,
			);

			foreach my $o ( @{$fref->{opts}} ) {
				$self->{g}{ $g }{ $f }{ $o->[0] }->name( $o->[1] );
			}
		}
	}

	return $self;
}

#----------
#----------

package eThreads::Object::Template::Qopts::Opt;

use Spiffy -Base;

field 'orig'	=> -ro;
field 'name'	=> -init=>q! $self->orig->opt !;
field 'glomule'	=> -ro;
field 'gtype'	=> -ro;
field 'func'	=> -ro;

sub new {
	my $data = shift;

	$self = bless({
		@_,
	} , $self );

	return $self;
}

sub opt 	{ $self->orig->opt 		}
sub allowed { $self->orig->allowed 	}
sub persist { $self->orig->persist 	}
sub default { $self->orig->default	}
sub is_pref { $self->orig->pref		}

sub attributes { 
	my $att = $self->orig->attributes;
	$att->{name} = $self->name;

	return $att;
}

=head1 NAME

eThreads::Object::Template::Qopts

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

