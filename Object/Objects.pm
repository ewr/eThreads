package eThreads::Object::Objects;

use strict;

use Spiffy -Base;

use Scalar::Util;

#----------

field '_'		=> -ro;

sub new {
	my $data = shift;

	$self = bless({
		_	=> $data,
		o	=> [],
		counts	=> {},
	},$self);

	return $self;
}

#----------

sub register {
	my $obj = shift;

	if ( !ref($obj) ) {
		$self->_->bail->("Invalid object register: $obj");
	} 

	push @{$self->{o}} , $obj;
}

#----------

sub DESTROY {
	foreach my $obj (@{$self->{o}}) {
		next if (!$obj);
		$obj->DESTROY if ( $obj->can("DESTROY") );
	}

	@{$self->{o}} = ();

	return 1;
}

#----------

sub create {
	my $type = shift;
	my $data = shift;

	if (!$type) {
		Carp::carp "no type given to create\n";
	}

	Scalar::Util::weaken($data);

	my $module = "eThreads::Object::$type";
	my $obj = $module->new($data,@_);

	$self->register($obj);

	return $obj;
}

#----------

sub activate {
	my $obj = shift;

	$obj->activate() if ($obj->can("activate"));
}

#----------

=head1 NAME

eThreads::Object::Objects

=head1 SYNOPSIS

	# create an Objects object
	my $objs = eThreads::Object::Objects->new($inst);

	# create and register a new object
	my $obj = $objs->create("type",$data);

	# just register
	$objs->register($myobj);

	# activate our new object
	$objs->activate($obj);

	# destroy all objects
	$objs->DESTROY;

=head1 DESCRIPTION

The eThreads Objects object is in charge of creating and keeping track of 
all instance objects.  When its DESTROY handler is called, Objects goes 
through and calls DESTROY on each registered object, allowing you to break 
structures that might not naturally fall out of scope.  Most of the time 
this will be entirely transparent to you, and handled entirely by the 
Instance object.

=over 4

=item new

	my $objs = eThreads::Object::Objects->new($inst);

Create a new Objects object.  

=item create 

	my $obj = $objs->create("type",$data);

Creates and registers a new object of type "type".  Most objects expect $data 
to be a reference to $inst.

=item register 

	$objs->register($myobj);

Just register an object that's already been created.

=item activate 

	$objs->activate($obj);

Calls activate on the object if the object has that functionality.

=item DESTROY

	$objs->DESTROY;

Destroys all registered objects and the $objs data itself.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2004 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.

=cut

1;
