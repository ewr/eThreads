package eThreads::Object::Switchboard::Custom;

@ISA = qw( eThreads::Object::Switchboard );

use strict;

sub new {
	my $class = shift;
	my $data = shift;
	my $accessors = shift;

	$class = bless({},$class);

	$class->{paccessors} = $accessors;
	$class->{accessors} = bless({},$class->_ac_pkg);
	$class->{accessors}->{parent} = $class->{paccessors};

	return $class;
}

#----------

sub _ac_pkg {
	return "eThreads::Object::Switchboard::Custom::Accessors";
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

package eThreads::Object::Switchboard::Custom::Accessors;

sub AUTOLOAD {
	my $class = shift;
	our $AUTOLOAD;
	my ($func) = $AUTOLOAD =~ m!::([^:]+)$!;
	return $class->{parent}->$func;
}

#----------

1;
