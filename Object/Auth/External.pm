package eThreads::Object::Auth::External;

@ISA = qw( eThreads::Object::Auth );

use Apache::Access ();
use Apache::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);
use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ({
		_		=> $data,
		user	=> undef,
	},$class);

	return $class;
}

#----------

sub authenticate {
	my $class = shift;
	
}

#----------

sub unauthorized {
	my $class = shift;

}

#----------

sub user {
	return shift->{user};
}

#----------

=head1 NAME

eThreads::Object::Auth::External

=head1 SYNOPSIS

	my $auth = $inst->new_object("Auth::External");

	my $user = $auth->authenticate 
		or return $auth->unauthorized;

	my $user = $auth->user;

=head1 DESCRIPTION

Auth::Internal provides apache basic authentication without having to use 
.htaccess files or any sort of mod_auth mechanism.

=over 4

=item new 

Create a new Auth::Internal object.

=item authenticate

Returns a user object if the user authenticated, false otherwise.  Also returns 
false if basic authentication headers aren't present.

=item unauthorized

Calls note_basic_auth_failure and then returns HTTP_UNAUTHORIZED.

=item user

Returns an object for the authenticated user.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
