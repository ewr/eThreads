package eThreads::Object::Auth;

use strict;

#----------

sub new {
	die "Cannot call Auth object directly\n";
}

#----------


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
