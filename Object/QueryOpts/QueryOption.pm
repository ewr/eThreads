package eThreads::Object::QueryOpts::QueryOption;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		opt		=> undef,
		name	=> undef,
		class	=> undef,
		value	=> undef,
		allowed	=> undef,
		default	=> undef,
		toggle	=> undef,
		select	=> undef,
		persist	=> undef,
		@_
	} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub get {
	my $class = shift;

	return $class->{value} || $class->{default};
}

#----------

sub opt {
	return shift->{opt};
}

#----------

sub class {
	return shift->{class};
}

#----------

sub name {
	my $class = shift;

	if ($class->{name}) {
		return $class->{name};
	} else {
		$class->{name} = $class->{_}->queryopts->get_name_for_opt(
			$class->{glomule},
			$class->opt
		);

		return $class->{name};
	}
}

#----------

sub default {
	return shift->{default};
}

#----------

sub persist {
	my $class = shift;
	return $class->{persist};
}

#----------

sub alter {
	my $class 	= shift;
	my $key		= shift;
	my $val 	= shift;

	$class->{ $key } = $val;

	return 1;
}

#----------

sub set {
	my ($class,$val) = @_;

	if ($val =~ m!$class->{allowed}! && $val ne $class->{value}) {
		$class->{value} = $val;
	} elsif ($val eq $class->{default}) {
		$class->{value} = $class->{default};
	}

	return 1;
}

#----------

sub toggle {
	my $class = shift;

	$class->{_}->bail->(
		"Tried to toggle untogglable query_opt: $class->{class}/$class->{name}"
	) unless ($class->{toggle});

	return (
		$class->{toggle}[0][1] eq $class->get
	) ? $class->{toggle}[1][1] : $class->{toggle}[0][1];
}

#----------

#----------

#----------

1;
