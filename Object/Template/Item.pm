package eThreads::Object::Template::Item;

use strict;

use Spiffy -Base;

#----------

field 'children' => -ro;
field 'type';
field 'parent' => -weak;
field 'content';
field 'args';

sub new {
	$self = bless ({
		parent		=> undef,
		type		=> undef,
		content		=> undef,
		args		=> {},
		children	=> [],
	},$self);

	return $self;
}

#----------

sub DESTROY {
	# nothing for now
}

#----------

sub add_child {
	my $child = shift;
	return push @{ $self->{children} } , $child;
}

#----------

sub key_path {
	# build our object's path
	my @path;
	my $p = $self;

	do {
		unshift @path, $p->key if ($p->key);
	} while ($p = $p->parent);

	my $path = join(".",@path);

	return $path;
}

#----------

sub object_path {
	# build our object's path
	my @path;
	my $p = $self;

	do {
		unshift @path, $p;
	} while ($p = $p->parent);

	return @path;
}

#----------

sub dump_deep {
	my $children = [];

	@$children = map { $_->dump_deep } @{ $self->{children} };

	{
		type		=> $self->{type},
		args		=> $self->{args},
		content		=> $self->{content},
		children	=> $children
	};
}

#----------

