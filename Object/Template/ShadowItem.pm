package eThreads::Object::Template::ShadowItem;

use Spiffy -Base;
use Scalar::Util;

#----------

field 'children'	=> 
	-ro,
	-init=>q!
		my $shadowc = new eThreads::Object::Template::List;
		while ( my $c = $self->{item}->children->next ) {
				$shadowc->push( 
					eThreads::Object::Template::ShadowItem->new(
						item => $c , parent => $self
					)
				);
		}
		$shadowc;
	!;

field 'prev' => -weak;
field 'next';
	
field 'parent'		=> 
	-ro,
	-init=>q!
		if ( my $p = $self->item->parent ) {
			my $p = eThreads::Object::Template::ShadowItem->new(
				item => $p
			);
			Scalar::Util::weaken($p);
			$p;
		} else { 
			undef;
		}
	!;

field 'item' => -ro;

sub new {
	$self = bless ( {
		item	=> undef,
		notes	=> {},
		@_,
	} , $self ); 

	Scalar::Util::weaken( $self->{parent} );

	return $self;
}

#----------

sub note {
	my $key = shift;
	my $val = shift;

	$self->{notes}{$key} = $val if ($val);

	return $self->{notes}{$key};
}

#----------

sub type {
	$self->item->type(@_);
}

#----------

sub content {
	$self->item->content(@_);
}

#----------

sub args {
	$self->item->args(@_);
}

#----------

sub key_path {

}

#----------

sub object_path {

}

#----------

=head1 NAME

eThreads::Object::Template::ShadowItem

=head1 SYNOPSIS

=head1 DESCRIPTION


=over 4


=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
