package eThreads::Object::Template::ShadowItem;

#@ISA = qw( eThreads::Object::Template::Item );

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		item	=> undef,
		notes	=> {},
		@_,
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub note {
	my $class = shift;
	my $key = shift;
	my $val = shift;

	$class->{notes}{$key} = $val if ($val);

	return $class->{notes}{$key};
}

#----------

sub children {
	my $class = shift;

	if ($class->{children}) {
		return $class->{children};
	} else {
		my $shadowc = [];

		@$shadowc = 
			map { 
				$class->{_}->switchboard->new_object(
					"Template::ShadowItem",item=>$_
				);
			} @{ $class->{item}->children };

		$class->{children} = $shadowc;

		return $class->{children};
	}
}

#----------

sub type {
	shift->{item}->type(@_);
}

#----------

sub parent {
	my $class = shift;

	if ($class->{parent}) {
		return $class->{parent};
	} else {
		if (my $p = $class->{item}->parent) {
			$class->{parent} = $class->{_}->switchboard->new_object(
				"Template::ShadowItem",
				item => $p
			);

			return $class->{parent};
		} else {
			return undef;
		}
	}
}

#----------

sub content {
	shift->{item}->content(@_);
}

#----------

sub args {
	shift->{item}->args(@_);
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
