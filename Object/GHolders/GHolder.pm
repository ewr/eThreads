package eThreads::Object::GHolders::GHolder;

use strict;

sub new {
	my $class = shift;
	my $data = shift;
	my $key = shift;
	my $parent = shift;

	$class = bless({
		_			=> $data,
		key			=> $key || undef,
		parent		=> $parent || undef,
		flat		=> undef,
		sub			=> undef,
		array		=> undef,
		children	=> {},
	} , $class);

	if ($parent) {
		$parent->add_child($class);
	}

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;

#	$class->{parent} = undef;
#	%{$class->{children}} = ();

	return 1;
}

#----------

sub add_child {
	my $class = shift;
	my $child = shift;

	$class->{children}{ $child->{key} } = $child;
}

#----------

sub children {
	my $class = shift;

	return $class->{children};
}

#----------

sub has_child {
	my $class = shift;
	my $name = shift;

	if ($class->{children}{$name}) {
		return $class->{children}{$name};
	} else {
		return undef;
	}
}

#----------

sub flat {
	my $class = shift;

	$class->{flat} = shift if ($_[0]);

	return $class->{flat};
}

#----------

sub array {
	my $class = shift;

	$class->{array} = shift if ($_[0]);

	return $class->{array};
}

#----------

sub sub {
	my $class = shift;

	$class->{sub} = shift if ($_[0]);

	return $class->{sub};
}

#----------

sub parent {
	my $class = shift;
	return $class->{parent};
}

#----------

sub key {
	my $class = shift;
	return $class->{key};
}

#----------

sub key_path {
	my $class = shift;

	# build our object's path
	my @path;
	my $p = $class;

	do {
		unshift @path, $p->key if ($p->key);
	} while ($p = $p->parent);

	my $path = join(".",@path);

	return $path;
}

#----------

sub object_path {
	my $class = shift;

	# build our object's path
	my @path;
	my $p = $class;

	do {
		unshift @path, $p;
	} while ($p = $p->parent);

	return @path;
}

#----------

1;
