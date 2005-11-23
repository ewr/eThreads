package eThreads::Object::Auth::Cookies;

use eThreads::Object::Auth -Base;

use CGI::Cookie;
use Digest::MD5;

#----------

field 'user' => -ro;

sub new {
	my $data = shift;

	$self = bless ({
		_		=> $data,
		user	=> undef,
	},$self);

	return $self;
}

#----------

sub authenticate {
	my ($u,$p);
	my $f = CGI::Cookie->fetch;
	if ($self->_->raw_queryopts->get("cookie_user")) {
		$u = $self->_->raw_queryopts->get("cookie_user");
		$p = $self->_->raw_queryopts->get("cookie_pass");
	} elsif ($f && $f->{user}) {
		($u) = CGI::Cookie->fetch->{user} =~ /user=([^;]+);/;
		($p) = CGI::Cookie->fetch->{pass} =~ /pass=([^;]+);/;
	} else {
		# we have nothing
	}

	if (my $obj = $self->is_valid_login($u,$p)) {
		if ($self->_->raw_queryopts->get("cookie_user")) {
			# set our auth cookies
			my $c_u = new CGI::Cookie(
				-name	=> "user",
				-value	=> $u
			);

			my $c_p = new CGI::Cookie(
				-name	=> "pass",
				-value	=> $p
			);

			$self->_->ap_request->headers_out->set('Set-Cookie' => $c_u);
			$self->_->ap_request->headers_out->set('Set-Cookie' => $c_p);
		}

		return $obj;
	} else {
		return undef;
	}
	
	return undef;
}

#----------

sub unauthorized {
	$self->_->messages->print("CookieLogin","");

	exit;
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
