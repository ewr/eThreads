package eThreads::Object::Template::List;

use Spiffy -Base;
no warnings;

field 'first'	=> -ro;
field 'last'	=> -ro;
field 'count'	=> -ro;
field 'iter'	=> -ro;

sub new {
	$self = bless {} , $self;
	return $self;
}

sub unshift {
	my $item = shift;

	if ( my $f = $self->{first} ) {
		$f->prev( $item );
		$item->next( $f );
	} else {
		# first item?
		if (!$self->{last}) {
			$self->{last} = $item;
		}
	}

	$self->{count}++;
	$self->{first} = $item;
}

sub push {
	my $item = shift;

	if ( my $l = $self->{last} ) {
		$l->next( $item );
		$item->prev( $l );
	} else {
		# first item?
		if ( !$self->{first} ) {
			$self->{first} = $item;
		}
	}

	$self->{count}++;
	$self->{last} = $item;
}

sub before {
	my $existing = shift;
	my $new = shift;

	return undef if ( !$existing || !$new );

	if ( $existing->prev ) {
		$existing->prev->next( $new );
		$new->prev( $existing->prev );
		$existing->prev( $new );
		$new->next( $existing );
	} else {
		$self->unshift( $new );
	}

	$self->{count}++;
}

sub after {
	my $existing = shift;
	my $new = shift;

	return undef if ( !$existing || !$new );

	if ( $existing->next ) {
		$existing->next->prev($new);
		$new->next( $existing->next );
		$existing->next( $new );
		$new->prev( $existing );
	} else {
		$self->push( $new );
	}

	$self->{count}++;
}

sub reset {
	undef $self->{iter};
}

sub next {
	if (!$self->iter) {
		return $self->first;
	}

	if ( my $n = $self->iter->next ) {
		$self->{iter} = $n;
		return $n;
	} else {
		$self->reset;
		return undef;
	}
}

sub prev {
	if ( !$self->iter) {
		return $self->last;
	}

	if ( my $p = $self->iter->prev ) {
		$self->{iter} = $p;
		return $p;
	} else {
		$self->reset;
		return undef;
	}
}

sub first {
	my $f = $self->{first};
	$self->{iter} = $f;
	return $f;
}

sub last {
	my $l = $self->{last};
	$self->{iter} = $l;
	return $l;
}


