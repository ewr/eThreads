package eThreads::Object::Plugin::RecentComments;

@ISA = qw( eThreads::Object::Plugin );

use strict;

#----------

sub activate {
	my $class = shift;

	my $comments = $class->{i}->args->{comments};
	my $count = $class->{i}->args->{count} || 5;

	if (!$comments) {
		warn "CountBlogComments: no comments glomule given\n";
		return undef;
	}

	# for now we don't have a way to know if a glomule's valid.  we use it 
	# and if it doesn't exist it'll get created

	my $cobj = $class->{_}->switchboard->new_object(
		"Glomule::Type::Blog",
		$comments
	);

	my $htbl = $cobj->data("headers");
	my $dtbl = $cobj->data("data");

	if (!$htbl) {
		warn "CountBlogComments: no comments headers table\n";
		return undef;
	}

	# we want the 
	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			h.id,
			h.timestamp,
			h.parent,
			d.value
		from 
			$htbl as h,
			$dtbl as d
		where 
			h.id = d.id 
			and d.ident = 'name'
		order by 
			timestamp desc
		limit $count
	");

	$get->execute() 
		or $class->{_}->bail->("get recent comments failed: ".$get->errstr);
	
	my ($id,$t,$p,$n);
	$get->bind_columns( \($id,$t,$p,$n) );

	my $comments = [];
	while ($get->fetch) {
		push @$comments, [ 'comments.' . $id , {
			id		=> $id,
			timestamp	=> $t,
			parent	=> $p,
			name	=> $n,
		} ];
	}

	$class->{_}->rctx->register(
		[ 'comments' , [ map { $_->[1]{id} } @$comments ] ],
		@$comments,
	);

	1;
}

#----------
