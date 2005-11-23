package eThreads::Object::System::Ping;

use eThreads::Object::System -Base;

#----------

field 'pings' => 
	-init=>q!
		$self->load_pings
			or $self->cache_pings
	!, -ro;

sub ping_all {
	foreach my $p (@{ $self->pings }) {
		my $obj = $self->_->new_object(
			"System::Ping::".$p->{method},
			%$p
		);
		$obj->ping;
	}
}

#----------

sub load_pings {
	$self->_->cache->get(
		tbl		=> "pings",
		first	=> $self->_->container->id,
	);
}

#----------

sub cache_pings {
	my $get = $self->_->core->get_dbh->prepare("
		select 
			id,
			method,
			url,
			func,
			title,
			local
		from 
			" . $self->_->core->tbl_name("pings") . "
		where 
			container = ?
	");

	$get->execute( $self->_->container->id ) 
		or $self->_->bail->("cache pings failure: ".$get->errstr);

	my ($id,$m,$u,$f,$t,$l);
	$get->bind_columns( \($id,$m,$u,$f,$t,$l) );

	my $pings = [];
	while ($get->fetch) {
		push @$pings, {
			id		=> $id,
			method	=> $m,
			url		=> $u,
			func	=> $f,
			title	=> $t,
			local	=> $l
		};
	}

	$self->_->cache->set(
		tbl		=> "pings",
		first	=> $self->_->container->id,
		ref		=> $pings
	);

	return $pings;
}

#----------

1;
