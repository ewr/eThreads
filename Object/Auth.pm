package eThreads::Object::Auth;

use Spiffy -Base;
no warnings;

#----------

field '_' => -ro;
stub 'new';

#----------

sub is_valid_login {
	my $user = shift;
	my $pass = shift;
	my $crypted = shift;

	my $headers = $self->_->users->headers;

	my $ref = $headers->{u}{ $user };

	if (!$ref) {
		# invalid user
		return undef;
	}

	my $cpass = crypt($pass,$ref->{password}) if (!$crypted);

	if ($cpass eq $ref->{password}) {
		# -- successful authentication -- #
		my $obj = $self->{user}
			= $self->_->users->get_obj_for_user( $ref->{id} );
		return $obj;
	} else {
		# -- invalid password -- #
		return undef;
	}
}


#----------

sub allowed {
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
