package eThreads::Object::Plugin::LimitCommentsByDate;

use strict;

#----------

sub activate {
	my $class = shift;

	my $i = $class->{i};

	# first we need to make sure we know who our key glomule is

	my $key = $i->args->{key} || $i->args->{blog}
		or $class->{_}->bail->("LimitCommentsByDate must be given a key.");

	# and who our comments are

	my $comments = $i->args->{comments}
		or $class->{_}->bail->("LimitCommentsByDate must be given comments.");

	# -- put a register trigger on this glomule for 

	return $class;
}

sub activate_walk {
	my $class = shift;

	my $i = $class->{i};

	
	
	return 1;
}

#----------

=head1 NAME

eThreads::Object::Plugin::LimitCommentsByDate

=head1 SYNOPSIS

=head1 DESCRIPTION

This plugin allows comments to be limited to posts that are less than x 
days old.  To do this a number of things need to happen: 

First, the plugin needs to know the key glomule.  For instance, if comments 
are being attached to a blog, the plugin needs to have access to the blog 
to look up age information for the posts.  

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
