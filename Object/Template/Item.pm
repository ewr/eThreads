package eThreads::Object::Template::Item;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;
	
	$class = bless ({
		_			=> $data,
		parent		=> undef,
		type		=> undef,
		content		=> undef,
		args		=> {},
		children	=> [],
		
	},$class);

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
	%{$class->{_}} = ();

	return $class->sever_relationships;
}

#----------

sub add_child {
	my $class = shift;
	my $child = shift;
	return push @{ $class->{children} } , $child;
}

#----------

sub sever_relationships {
	my $class = shift;

	@{$class->{children}} = ();
	$class->{parent} = undef;
}

#----------

sub children {
	my $class = shift;
	return $class->{children};
}

#----------

sub type {
	my $class = shift;
	my $type = shift;
	$class->{type} = $type if ($type);
	return $class->{type};
}

#----------

sub parent {
	my $class = shift;
	my $parent = shift;
	$class->{parent} = $parent if ($parent);
	return $class->{parent};
}

#----------

sub content {
	my $class = shift;
	my $content = shift;
	$class->{content} = $content if ($content);
	return $class->{content};
}

#----------

sub args {
	my $class = shift;
	my $args = shift;
	$class->{args} = $args if ($args);
	return $class->{args};
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
