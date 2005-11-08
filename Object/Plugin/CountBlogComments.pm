package eThreads::Object::Plugin::CountBlogComments;

@ISA = qw( eThreads::Object::Plugin );

use strict;

#----------

sub activate_walk {
	my $class = shift;

	my $blog = $class->{i}->args->{blog};

	if (!$blog) {
		warn "CountBlogComments: no blog given\n";
		return undef;
	}

	my $bctx = $class->{_}->gholders->exists($blog);

	if (!$bctx) {
		warn "CountBlogComments: invalid blog given: $blog\n";
		return undef;
	}

	# ok, so now we have a valid blog and blog context. now we need to 
	# see if we have a valid comments glomule

	my $comments = $class->{i}->args->{comments};

	if (!$comments) {
		warn "CountBlogComments: no comments glomule given\n";
		return undef;
	}

	# for now we don't have a way to know if a glomule's valid.  we use it 
	# and if it doesn't exist it'll get created

	my $cobj = $class->{_}->glomule->load(
		type	=> "comments",
		name	=> $comments
	);

	my $htbl = $cobj->data('headers');

	if (!$htbl) {
		warn "CountBlogComments: no comments glomule given\n";
		return undef;
	}

	# ok, now we've got a blog context and the headers table for the comments. 
	# that means that we need to find posts registered under $bctx, get their 
	# id, look that id up in the comments table to count the comments, and then 
	# register a comments child (containing the count) to the post.

	my $p = $bctx->has_child("post");

	if (!$p) {
		warn "CountBlogComments: blog doesn't have post child?\n";
		return undef;
	}

	my $ids = [];
	while ( my ($id,$c) = each %{ $p->children } ) {
		push @$ids, [$id,$c,0];
	}

	# lookup comments for these ids
	$class->count_comments_for($ids,$htbl);

	foreach my $post (@$ids) {
		my $gh = $class->{_}->new_object(
			"GHolders::GHolder",
			"comment_count",
			$post->[1]
		);

		$gh->flat($post->[2]);
	}

	return 1;
}

#----------

sub count_comments_for {
	my $class = shift;
	my $ids = shift;
	my $htbl = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			parent,
			count(id)
		from 
			" . $htbl . " 
		where 
			parent in (" . join( "," , map { "?" } @{ $ids } ) . ") 
		group by 
			parent
	");

	$get->execute( map { $_->[0] } @$ids )
		or $class->{_}->bail->("CountBlogComments failure: ".$get->errstr);

	my ($id,$c);
	$get->bind_columns( \($id,$c) );

	my $by_id = {};

	%$by_id = map { $_->[0] => $_ } @$ids;

	while ($get->fetch) {
		$by_id->{$id}[2] = $c;
	}

	return 1;
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
