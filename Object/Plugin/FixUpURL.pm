package eThreads::Object::Plugin::FixUpURL;

@ISA = qw( eThreads::Object::Plugin );

use strict;

#----------

sub activate {
	my $class = shift;

	$class->{_}->gholders->register(
		['fixupurl',sub { return $class->handle_url(@_) }]
	);

	return $class;
}

#----------

sub handle_url {
	my $class = shift;
	my $i = shift;

	my $url;
	
	$class->{_}->gholders->handle_template_tree($i,$url);

	if ($url !~ /^http/) {
		$url = "http://" . $url;
	}

	$_[0] .= $url;

	return 0;
}

#----------

=head1 NAME

eThreads::Object::Plugin::CountBlogComments

=head1 DESCRIPTION

This plugin counts comments for each post in a blog.

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
