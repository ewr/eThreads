package eThreads::Object::System::Ping;

@ISA = qw( eThreads::Object::System );

use strict;

#----------

sub new {
	my $class = shift;
	my $board = shift;

	$class = bless( { 
		@_,
		_		=> $board,
	} , $class );

	return $class;
}

#----------

sub ping_all {
	my $class = shift;

	my $pings = $class->{_}->cache->get(
		tbl		=> "pings",
		first	=> $class->{_}->container->id,
	);

	if (!$pings) {
		$pings = $class->cache_pings;
	}

	foreach my $p (@$pings) {
		my $obj = $class->{_}->instance->new_object(
			"System::Ping::".$p->{method},
			%$p
		);
		$obj->ping;
	}
}

#----------

sub cache_pings {
	my $class = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			method,
			url,
			func,
			title,
			local
		from 
			" . $class->{_}->core->tbl_name("pings") . "
		where 
			container = ?
	");

	$get->execute( $class->{_}->container->id ) 
		or $class->{_}->bail->("cache pings failure: ".$get->errstr);

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

	$class->{_}->cache->set(
		tbl		=> "pings",
		first	=> $class->{_}->container->id,
		ref		=> $pings
	);

	return $pings;
}

#----------

1;
