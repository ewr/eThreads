package eThreads::Object::Mode::Auth;

use eThreads::Object::Mode::Normal -Base;

#----------

sub go {
	my $r = shift;

	my $user = $self->_->auth->authenticate
		or return $self->_->auth->unauthorized;

	$self->_->switchboard->register("user",$user);

	super;
}

#----------

=head1 NAME

eThreads::Object::Mode::Auth

=head1 SYNOPSIS

=head1 DESCRIPTION

This is Auth mode, used when a user should be authenticated.  Most of the 
functionality is found in Normal mode.  Auth mode authenticates the user 
and then passes handling off from there.

=over 4

=item go

Authenticates the user and then calls Mode::Normal->go().  Registers "user" 
with the switchboard.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
