package eThreads::Object::Auth;

use strict;

#----------

sub new {
	die "Cannot call Auth object directly\n";
}

#----------

sub is_valid_login {
	my $class = shift;
	my $user = shift;
	my $pass = shift;
	my $crypted = shift;

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

	my $cpass = crypt($pass,$ref->{password}) if (!$crypted);

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


#----------

sub allowed {
	my $class = shift;

	return 1;
}

#----------

=head1 NAME

eThreads::Object::Auth;

=head1 SYNOPSIS

	# no functionality

=head1 DESCRIPTION

This is the base Auth module.  Will provide common auth routines when there 
are more auth types.

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
