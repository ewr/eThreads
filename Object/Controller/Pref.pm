package eThreads::Object::Controller::Pref;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		name		=> undef,
		default		=> undef,
		allowed		=> undef,
		hidden		=> undef,
		descript	=> undef,
		toggle		=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub name 		{	shift->{name}		}
sub default		{	shift->{default}	}
sub allowed		{	shift->{allowed}	}
sub descript	{	shift->{descript}	}
sub hidden		{	shift->{hidden}		}
sub toggle		{	shift->{toggle}		}

sub attributes {
	my $class = shift;

	{
		name		=> $class->{name},
		default		=> $class->{default},
		allowed		=> $class->{allowed},
		hidden		=> $class->{hidden},
		descript	=> $class->{descript},
		toggle		=> $class->{toggle}
	};
}

#----------

=head1 NAME

eThreads::Object::Controller::Pref

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
