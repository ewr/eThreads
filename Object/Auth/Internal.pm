package eThreads::Object::Auth::Internal;

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
	
	my $r = $class->{_}->ap_request;

	# -- set up our authentication -- #

	$r->auth_type("Basic");
	$r->auth_name($class->{_}->core->settings->{auth_name});

	# -- try and get user/pass -- #

	my ($status,$password) = $r->get_basic_auth_pw;
	my $user = $r->user;

	# -- if we get a status (most likely 401), send that to the browser -- #

	if ($status) {
		return undef;
	}

	# -- now check that the user is valid -- #

	{
		my $headers = $class->{_}->cache->get(
			tbl		=> "user_headers"
		);

		if (!$headers) {
			$headers = $class->{_}->instance->cache_user_headers;
		}

		my $ref = $headers->{u}{ $user };

		if (!$ref) {
			# invalid user
			return undef;
		}

		my $cpass = crypt($password,$ref->{password});

		if ($cpass eq $ref->{password}) {
			# -- successful authentication -- #
			my $obj = $class->{user} 
				= $class->{_}->instance->new_object("User",id=>$ref->{id});
			return $obj;
		} else {
			# -- invalid password -- #
			return undef;
		}
	}

	# every possibility returns before this point, so this code will never 
	# be reached
	return undef;
}

#----------

sub unauthorized {
	my $class = shift;

	my $r = $class->{_}->ap_request;

	# note that we failed
	$r->note_basic_auth_failure;

	return Apache::HTTP_UNAUTHORIZED;
}

#----------

sub user {
	return shift->{user};
}

#----------

=head1 NAME

eThreads::Object::Auth::Internal

=head1 SYNOPSIS

	my $auth = $inst->new_object("Auth::Internal");

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
