package eThreads::Object::Template::Qopts;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		g		=> {},
		f		=> {},
		o		=> {},
		n		=> {},
		all		=> [],
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub register {
	my $class = shift;
	my %args = @_;

	return undef if (!$args{glomule});

	foreach my $o ( @{ $args{opts} } ) {
		# create a new Qopt object
		my $obj = $class->{_}->new_object("Template::Qopts::Opt",$o);

		# map by glomule
		$class->{g}{ $args{glomule} }{ $args{function} }{ $obj->name } = $obj;

		# map by function
		$class->{f}{ $args{function} }{ $args{glomule} }{ $obj->name } = $obj;

		# map by object key
		$class->{o}{ $obj->name }{ $args{glomule} }{ $args{function} } = $obj;

		# and throw it on the generic all array
		push @{$class->{all}}, $obj;
	}

	return 1;
}

#----------

sub names {
	my $class = shift;
	my $name = shift;

	my $names = {};
	foreach my $o ( @{$class->{all}} ) {
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
	my $class = shift;
	my $glomule = shift;

	return ( $glomule ) ? $class->{g}{ $glomule } : $class->{g};
}

#----------

sub function {
	my $class = shift;
	my $function = shift;

	return ( defined($function) ) ? $class->{f}{ $function } : $class->{f};
}

#----------

sub opt {
	my $class = shift;
	my $opt = shift;

	return ( $opt ) ? $class->{o}{ $opt } : $class->{o};
}

#----------
#----------

package eThreads::Object::Template::Qopts::Opt;

sub new {
	my $class = shift;
	my $data = shift;
	my $ref = shift;

	$class = bless({
		_		=> $data,
		orig	=> $ref,
		name	=> $ref->opt,
	} , $class );

	return $class;
}

sub name {
	my $class = shift;
	my $name = shift;

	if ($name) {
		$class->{name} = $name;
	}

	return $class->{name};
}

sub opt 	{ shift->{orig}->opt 		}
sub allowed { shift->{orig}->allowed 	}
sub persist { shift->{orig}->persist 	}
sub default { shift->{orig}->default	}
sub is_pref { shift->{orig}->pref 		}

sub attributes { 
	my $class = shift;

	my $att = $class->{orig}->attributes;
	$att->{name} = $class->name;

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

