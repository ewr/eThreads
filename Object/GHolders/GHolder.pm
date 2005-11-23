package eThreads::Object::GHolders::GHolder;

use Spiffy -Base;

no warnings;

use Scalar::Util;

use strict;

const 'valid_objects'	=> {
	'Link'		=> 1,
	'GHolder'	=> 1,
};

field '_'			=> -ro;
field 'children'	=> -ro;
field 'flat';
field 'array';
field 'sub';
field 'parent'		=> -ro;
field 'key'			=> -ro;

sub new () {
	my $self = shift;
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

sub _parent {
	my $parent = shift;

	$self->{parent} = $parent;
	Scalar::Util::weaken($self->{parent});

	return 1;
}

sub add_child {
	my $child = shift;

	if (!$child->{key}) {
		my @caller = caller;
		warn "bad key from: @caller\n";
	}

	$self->{children}{ $child->{key} } = $child;
}

#----------

sub has_child () {
	return $_[0]->{children}{ $_[1] } || undef;
}

#----------

sub is_gh_object {
	my $val = shift;

	if ( ref($val) =~ m!^eThreads::Object::GHolders::(.*)! ) {
		my $type = $1;
		if ( $self->valid_objects->{ $type } ) {
			return 1;
		} else {
			$self->_->bail->("Invalid GHolder object type as data: $type");
		}
	} else {
		return undef;
	}
}

#----------

sub register {
	my $key = shift;
	my $val = shift;

	if ( my ($base,$rest) = $key =~ m!^(.+?)\.(.+)$! ) {
		# we're not the end register...  she if we have the child as a base; 
		# if not, create it
		my $child = 
			$self->has_child( $base )
			|| $self->_->new_object('GHolders::GHolder',$base,$self);

		$child->register( $rest , $val );
	} else {
		# this is a register occuring directly under us.  first check and see 
		# if the val is an object

		if ( $self->is_gh_object( $val ) ) {
			$self->register_object( $key , $val );
		} else {
			my $child = 
				$self->has_child( $key )
				|| $self->_->new_object('GHolders::GHolder',$key,$self);

			$child->set_value( $val );
		}
	}
}

#----------

sub register_object {
	my $key = shift;
	my $val = shift;

	if ( my $child = $self->has_child( $key ) ) {
		# have to replace existing child
		die "need to replace existing child\n";
	} else {
		# adding object as child
		$self->add_child( $val );
		$val->_parent( $self );
	}
}

#----------

sub set_value {
	my $val = shift;

	# now figure out how to handle the value
	if ( !ref( $val ) ) {
		# flat value
		$self->flat( $val );
	} elsif (ref( $val ) eq 'HASH') {
		# hash ref...  needs to be cloned into the child's structure
		$self->assimilate_hash( $val );
	} elsif (ref( $val ) eq 'ARRAY') {
		$self->array( $val );
	} elsif (ref( $val ) eq 'CODE') {
		$self->sub( $val );
	} else {
		$self->_->bail->("Unsupported gholder value: $val");
	}
}

#----------

sub assimilate_hash {
	my $hash = shift;

	while ( my ( $key,$val ) = each %$hash ) {
		if ( $self->is_gh_object( $val ) ) {
			$self->register_object($key,$val);
		} else {
			my $child 
				= $self->has_child($key) 
					|| $self->_->new_object('GHolders::GHolder',$key,$self);
				
			$child->set_value($val);
		}
	}

	return 1;
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
