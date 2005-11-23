package eThreads::Object::Template::Item;

use strict;

use Spiffy -Base;

use eThreads::Object::Template::List;

#----------

field 'type';
field 'parent' => -weak;
field 'content';
field 'args';

field 'children' => -ro, -init=>q! new eThreads::Object::Template::List !;
field 'next';
field 'prev' => -weak;

sub new {
	$self = bless ({
		parent		=> undef,
		type		=> undef,
		content		=> undef,
		args		=> {},
	},$self);

	return $self;
}

#----------

sub DESTROY {
	# nothing for now
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

	if ( $self->{children} ) {
		while ( my $c = $self->children->next ) {
			push @$children, $c->dump_deep;
		}
	}

	{
		type		=> $self->{type},
		args		=> $self->{args},
		content		=> $self->{content},
		children	=> $children
	};
}

#----------

