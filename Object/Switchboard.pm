package eThreads::Object::Switchboard;

use strict;
use Symbol;
use eThreads::Object::Switchboard::Custom;

sub new {
	my $class = shift;
	$class = bless({},$class);
	$class->{accessors} = bless({},$class->_ac_pkg);

	# register ourselves
	$class->register("switchboard",$class);

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;

	$class->{accessors}->DESTROY;
	undef $class->{accessors};

	return 1;
}

#----------

sub _ac_pkg {
	return "eThreads::Object::Switchboard::Accessors";
}

#----------

sub accessors {
	return shift->{accessors};
}

#----------

sub injector {
	my $class = shift;
	my $acc = shift;
	my $sub = shift;

	my $injector = $class->new_object(
		"Switchboard::Injector",
		accessor	=> $acc,
		routine		=> $sub
	);

	return $injector;
}

#----------

sub custom {
	my $class = shift;
	
	my $custom = 
		$class->new_object(
			"Switchboard::Custom" , $class->accessors
		);

	return $custom;
}

#----------

sub new_object {
	return shift->accessors->new_object(@_);
}

#----------

sub register {
	my $class = shift;
	my $name = shift;
	my $ref = shift;

	if (!$name || $name =~ /\W/) {
		die "must provide valid accessor name\n";
	}

	if ($class->{$name}) {
		die "can't override existing entry\n";
	}

	my $sub = qualify_to_ref($class->_ac_pkg . "::" . $name);

	if (!*{$sub}{CODE}) {
		$class->_create_accessor($sub,$name);
	}

	$class->accessors->{$name} = $ref;
}

#----------

sub reroute_calls_for {
	my $class = shift;
	my $obj = shift;

	# this is ugly, but i think it'll work
	$obj->{_} = $class->accessors;

	return 1;
}

#----------

sub _create_accessor {
	my $class = shift;
	my $sub = shift;
	my $name = shift;

	*{$sub} = eval qq( sub {
		my \$self = shift;
		if (!\$self->{$name}) {
			my \@caller = caller;
			warn "caller: \@caller\n";
			die "attempt to access invalid accessor: $name\n";
		}

		return 
			(ref(\$self->{$name}) eq 'CODE')
				? ( \$self->{$name} = \$self->{$name}->() )
				: \$self->{$name};
	} );

	return 1;
}

#----------

sub knows {
	my $class = shift;
	return $class->accessors->knows(@_);
}

#----------

package eThreads::Object::Switchboard::Accessors;

sub new_object {
	my $class = shift;
	my $type = shift;

	if (!$type) {
		Carp::confess "no type given to new_object";
	}

	my $obj = $class->objects->create(
		$type,
		$class,
		@_
	);

	return $obj;
}

#----------
sub knows {
	return $_[0]->{ $_[1] } || undef;
}

sub AUTOLOAD {
	our $AUTOLOAD;
	my ($func) = $AUTOLOAD =~ m!::([^:]+)$!;
	my @caller = caller;
	die "invalid accessor access attempted: $func by @caller\n";
}

#----------

sub DESTROY {
	my $class = shift;
	%$class = ();
}

#----------

=head1 NAME

eThreads::Object::Switchboard

=head1 SYNOPSIS

	# create a switchboard object
	my $board = eThreads::Object::Switchboard->new($inst);

	# register an entry
	$board->register("template",$template);

	# register a lazy entry
	$board->register("RequestURI",sub {
		$inst->new_object("RequestURI");
	});

	# get the accessors object
	my $acc = $board->accessors;

	# check and see if an object is available
	if ($acc->knows("template")) {
		# go ahead and use it...
	}

	# call an object
	my $template = $acc->template;

=head1 DESCRIPTION

Switchboard does what its name would imply; it keeps track of what objects 
are where and allows objects to communicate inside the call tree.  Any object 
can be registered with the switchboard, but care should be taken to only 
register those which should genuinely be public.

=over 4

=item new

	my $board = eThreads::Object::Switchboard->new($inst);

Returns a new Switchboard object.  The argument provided needs to be 
something that Switchboard can call bail on when an invalid lookup is 
attempted.

=item register

	$board->register("template",$template);

	$board->register("RequestURI",sub {
		$inst->new_object("RequestURI");
	});

Registers an object with the switchboard.  The only reserved word is "knows".  
If you register a sub ref it'll act as a lazy accessor.  The coderef will be 
stored until the switchboard item is called.  At that time the ref will be run 
and should return the proper ref for the accessor.

=item knows 

	if ($acc->knows("foo")) {
		...
	}

Do some behaviour if the switchboard has an accessor for "foo".

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.

=cut

1;

