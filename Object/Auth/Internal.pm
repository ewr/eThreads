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

1;
