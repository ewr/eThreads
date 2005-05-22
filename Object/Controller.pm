package eThreads::Object::Controller;

use eThreads::Object::Controller::Object;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub get {
	my $class = shift;
	my $type = shift;

	return $class->{controllers}{ $type };
}

#----------

sub activate {
	my $class = shift;

	# -- list files in Controllers dir -- #

	opendir(DIR,$class->{_}->settings->{dir}{controllers})
		or $class->{_}->bail->("couldn't open controller dir: $!");
	
	my @files = grep { /xml$/ } readdir(DIR);
	
	closedir DIR;

	foreach my $f (@files) {
		my $c = $class->{_}->new_object("Controller::Object",$f);

		$class->{controllers}{ $c->type } = $c;
	}

	return $class;
}

#----------

=head1 NAME

eThreads::Object::Controller::Cache

=head1 SYNOPSIS

=head1 DESCRIPTION

Glomule controllers are defined in XML files.  These files need to be parsed 
into memory in order to be usable by eThreads.  They don't change much, 
though, so we do this just once when the core is started and keep the cached 
controller objects in memory so that we can use them many times.

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
