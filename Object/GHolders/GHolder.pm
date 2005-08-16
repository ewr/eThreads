package eThreads::Object::GHolders::GHolder;

use Spiffy -Base;

use Scalar::Util;

use strict;

field 'children'	=> -ro;
field 'flat';
field 'array';
field 'sub';
field 'parent'		=> -ro;
field 'key'			=> -ro;

sub new {
	my $data = shift;
	my $key = shift;
	my $parent = shift;

	$self = bless({
		_			=> $data,
		key			=> $key || undef,
		parent		=> $parent || undef,
		flat		=> undef,
		sub			=> undef,
		array		=> undef,
		children	=> {},
	} , $self);

	if ($parent) {
		$parent->add_child($self);
		Scalar::Util::weaken($self->{parent});
	}

	return $self;
}

#----------

sub add_child {
	my $child = shift;

	if (!$child->{key}) {
		my @caller = caller;
		warn "bad key from: @caller\n";
	}

	$self->{children}{ $child->{key} } = $child;
}

#----------

sub _exists {
	my $key = shift;

	my ($root,$remain) = $key =~ /^(.+?)\.(.+)?$/;

	if ( my $c = $self->has_child($root) ) {
		if ($remain) {
			return $c->_exists($remain);
		} else {
			return $c;
		}
	} else {
		return undef;
	}
}

#----------

sub has_child () {
	return $_[0]->{children}{ $_[1] } || undef;
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

1;
