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
		my $db = $class->{_}->core->get_dbh;
		my $get = $db->prepare("
			select 
				id,password 
			from 
				" . $class->{_}->core->tbl_name("user_headers") . " 
			where 
				user = ?
		");

		$get->execute($user);

		if (!$get->rows) {
			# -- invalid username -- #
			return undef;
		}

		my ($id,$db_pass);
		$get->bind_columns( \($id,$db_pass) );

		$get->fetch;

		my $cpass = crypt($password,$db_pass);

		if ($cpass eq $db_pass) {
			# -- successful authentication -- #
			my $user = $class->{user} 
				= $class->{_}->instance->new_object("User",$id);
			return $user;
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
