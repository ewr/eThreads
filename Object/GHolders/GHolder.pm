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

#	if (!$key) {
#		Carp::cluck "gholder with no key\n";
#	}

	if ($parent) {
		$parent->add_child($class);
	}

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;

	$class->{parent} = undef;
	%{$class->{children}} = ();

	return 1;
}

#----------

sub add_child {
	my $class = shift;
	my $child = shift;

	if (!$child->{key}) {
		my @caller = caller;
		warn "bad key from: @caller\n";
	}

	$class->{children}{ $child->{key} } = $child;
}

#----------

sub children {
	my $class = shift;

	$class->{children};
}

#----------

sub has_child {
	return $_[0]->{children}{ $_[1] } || undef;
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
	return shift->{parent};
}

#----------

sub key {
	return shift->{key};
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
