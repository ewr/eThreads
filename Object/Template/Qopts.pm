package eThreads::Object::Template::Qopts;

use Spiffy -Base;

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

	return undef if (!$args{glomule});

	foreach my $o ( @{ $args{opts} } ) {
		# create a new Qopt object
		my $obj = $self->_->new_object("Template::Qopts::Opt",$o);

		# map by glomule
		$self->{g}{ $args{glomule} }{ $args{function} }{ $obj->name } = $obj;

		# map by function
		$self->{f}{ $args{function} }{ $args{glomule} }{ $obj->name } = $obj;

		# map by object key
		$self->{o}{ $obj->name }{ $args{glomule} }{ $args{function} } = $obj;

		# and throw it on the generic all array
		push @{$self->{all}}, [
			$obj,
			$args{glomule},
			$args{gtype},
			$args{function}
		];
	}

	return 1;
}

#----------

sub names {
	my $name = shift;

	my $names = {};
	foreach my $o ( @{ $self->{all} } ) {
		my $n = $o->[0]->name;
		if (my $aref = $names->{ $n }) {
			push @$aref, $o->[0];
		} else {
			$names->{ $n } = [ $o->[0] ];
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
	my $qopts = [];

	foreach my $o ( @{ $self->{all} } ) {
		push @$qopts, [ @{$o}[1..3] ];
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

	foreach my $o ( @$qopts ) {
		my $func = 
			$self->_->controller->get( $o->[1] )->has_function( $o->[2] )
				or $self->_->bail->("Error restoring Template Qopts");

		$self->register(
			glomule		=> $o->[0],
			function	=> $func->name,
			gtype		=> $o->[1],
			opts		=> scalar $func->qopts
		);
	}

	return $self;
}

#----------
#----------

package eThreads::Object::Template::Qopts::Opt;

use Spiffy -Base;

field 'orig'	=> -ro;
field 'name'	=> -init=>q! $self->orig->opt !;

sub new {
	my $data = shift;
	my $orig = shift;

	$self = bless({
		name	=> $orig->opt,
		orig	=> $orig,
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

