package eThreads::Object::Controller;

use Spiffy -Base;
no warnings;

use eThreads::Object::Controller::Object;

#----------

field '_' => -ro;

field 'controllers' => 
	-init=>q!
		$self->read_controllers
	!, -ro;

field 'list' => 
	-init=>q!
		my $c = [];
		@$c = map { $_ } keys %{ $self->controllers };
		$c;
	!, -ro;

sub new {
	my $data = shift;

	$self = bless ( {
		_		=> $data,
	} , $self ); 

	return $self;
}

#----------

sub get {
	my $type = shift;
	return $self->controllers->{ $type };
}

#----------

sub read_controllers {
	# -- list files in Controllers dir -- #

	opendir(DIR,$self->_->settings->{dir}{controllers})
		or $self->_->bail->("couldn't open controller dir: $!");
	
	my @files = grep { /xml$/ } readdir(DIR);
	
	closedir DIR;

	my $controllers = {};
	foreach my $f (@files) {
		my $c = $self->_->new_object("Controller::Object",$f);

		$controllers->{ $c->type } = $c;
	}

	$controllers;
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
