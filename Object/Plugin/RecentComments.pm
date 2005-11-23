package eThreads::Object::Plugin::RecentComments;

use eThreads::Object::Plugin -Base;

#----------

sub activate {
	my $comments = $self->{i}->args->{comments};
	my $count = $self->{i}->args->{count} || 5;

	if (!$comments) {
		warn "RecentComments: no comments glomule given\n";
		return undef;
	}

	# for now we don't have a way to know if a glomule's valid.  we use it 
	# and if it doesn't exist it'll get created

	my $cobj = $self->_->glomule->load(
		name	=> $comments,
		type	=> "comments",
	);

	my $htbl = $cobj->data("headers");
	my $dtbl = $cobj->data("data");

	if (!$htbl) {
		warn "RecentComments: no comments headers table\n";
		return undef;
	}

	my $tget;
	if ( my $titles = $self->{i}->args->{titles} ) {
		my $tobj = $self->_->glomule->load(
			name	=> $titles
		);

		my $theaders = $tobj->data('headers');

		$tget = $self->_->core->get_dbh->prepare("
			select 
				title
			from 
				$theaders
			where 
				id = ?
		");
	}

	my $get = $self->_->core->get_dbh->prepare("
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
			and h.status = 1
		order by 
			timestamp desc
		limit $count
	");

	$get->execute() 
		or $self->_->bail->("get recent comments failed: ".$get->errstr);
	
	my ($id,$t,$p,$n);
	$get->bind_columns( \($id,$t,$p,$n) );

	my $recent = [];
	while ($get->fetch) {
		my ($title,$stitle);
		if ($tget) {
			$tget->execute( $p );
			$title = $tget->fetchrow_array;

			$stitle = 
				length( $title ) > 16
					? substr( $title , 0 , 16 ) . '...'
					: $title;
		}
	
		push @$recent, [ 'comments.' . $id , {
			id		=> $id,
			timestamp	=> $t,
			parent	=> $p,
			name	=> $n,
			title	=> $title,
			shorttitle	=> $stitle,
		} ];
	}

	$self->_->rctx->register(
		[ 'comments' , [ map { $_->[1]{id} } @$recent ] ],
		@$recent,
	);

	1;
}

#----------
