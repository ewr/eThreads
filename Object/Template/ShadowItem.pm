package eThreads::Object::Template::ShadowItem;

use Spiffy -Base;
use Scalar::Util;

#----------

field '_' => -ro;

field 'children'	=> 
	-ro,
	-init=>q!
		my $shadowc = [];
		@$shadowc = 
			map { 
				$self->_->switchboard->new_object(
					"Template::ShadowItem",item=>$_,parent=>$self
				);
			} @{ $self->{item}->children };
		$shadowc;
	!;
	
field 'parent'		=> 
	-ro,
	-init=>q!
		if ( my $p = $self->item->parent ) {
			$self->_->switchboard->new_object(
				"Template::ShadowItem",
				item => $p
			);
		} else { 
			undef;
		}
	!;

field 'item' => -ro;

sub new {
	my $data = shift;

	$self = bless ( {
		item	=> undef,
		notes	=> {},
		@_,
		_		=> $data,
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
