package eThreads::Object::Template::Walker;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_			=> $data, 
		registers	=> {},
	} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;

	%{$class->{registers}} = ();

	return 1;
}

#----------

sub register {
	my $class = shift;

	foreach my $gh (@_) {
		if (ref($gh->[1]) eq "CODE") {
			$class->{registers}{ $gh->[0] } = $gh->[1];
		} else {
			$class->{_}->core->bail("Walker Must be Coderef");
		}
	}
}

#----------

sub exists {
	my ($class,$h) = @_;

	if (my $ref = $class->{registers}{ $h }) {
		return $ref;
	} else {
		return undef;
	}
}

#----------

sub walk {
	my $class = shift;
	my $i = shift;

	# call the handler for this tag
	if ( my $ref = $class->exists( $i->type ) ) {
			return $ref->($i);
	} else {
		return 1;
	}
}

#----------

sub walk_template_tree {
	my ($class,$tree) = @_;

	foreach my $i ( @{ $tree->children } ) {
		my $s = $class->walk($i);
		$class->walk_template_tree($i) if ( $s && @{ $i->children } );
	}
}

#----------

1;
