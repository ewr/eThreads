package eThreads::Object::Controller::Function;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		name	=> undef,
		object	=> undef,
		system	=> undef,
		sub		=> undef,
		qopts	=> undef,
		modes	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub name 	{ shift->{name}; 	}
sub object 	{ shift->{object}; 	}
sub system 	{ shift->{system}; 	}
sub sub 	{ shift->{sub}; 	}

sub qopts {
	my $class = shift;
	wantarray ? @{ $class->{qopts} } : $class->{qopts};
}

sub modes {
	my $class = shift;
	wantarray ? @{ $class->{modes} } : $class->{modes};
}

#----------

package eThreads::Object::Controller::Function::Qopt;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		key		=> undef,
		allowed	=> undef,
		persist	=> undef,
		default	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

sub opt 	{ shift->{key} }
sub allowed { shift->{allowed} }
sub persist { shift->{persist} }
sub default { shift->{default} }
sub is_pref { shift->{pref} }

sub attributes {
	my $class = shift;

	{
		opt		=> $class->{key},
		allowed	=> $class->{allowed},
		persist	=> $class->{persist},
		default	=> $class->{default},
		is_pref	=> $class->{pref}
	};
}

package eThreads::Object::Controller::Function::Mode;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		name	=> undef,
		value	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

sub name { shift->{name} }
sub value { shift->{value} }

sub attributes {
	my $class = shift;

	{
		name	=> $class->{name},
		value	=> $class->{value}
	};
}

#----------

=head1 NAME

eThreads::Object::Controller::Function

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
