package eThreads::Object::Cache::UpdateTimes;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_	=> $data,
	} , $class ); 

	return $class;
}

#----------

sub get {
	my $class = shift;
	my %a = @_;

	my $times = $class->_get_times;

	my $ts = $times->{ $a{tbl} }{ $a{first} || 0 }{ $a{second} || 0 };

	return $ts;
}

#----------

sub set {
	my $class = shift;
	my %a = @_;

	# -- update the value in the db -- #

	$class->{_}->utils->set_value(
		tbl		=> $class->{_}->core->tbl_name("update_time"),
		keys	=> {
			tbl		=> $a{tbl},
			first	=> $a{first} || 0,
			second	=> $a{second} || 0,
		},
		value_field	=> "ts",
		value		=> $a{ts}
	);

	$class->{_}->utils->set_value(
		tbl		=> $class->{_}->core->tbl_name("update_time"),
		keys	=> {
			tbl		=> "update_time",
			first	=> 0,
			second	=> 0,
		},
		value_field	=> "ts",
		value		=> time
	);

	$class->{_}->cache->expire(%a);

	$class->_load_times;

	return 1;
}

#----------

sub _get_times {
	my $class = shift;

	my $data = $class->{_}->core->memcache->get("update_time");

	# if we've got cached times, we want to check their timestamp once 
	# per instance.  We'll do that by setting $class->{_checked}

	if ($data && $class->{_checked} ) {
		# we have the table and we've checked it in the last 5 secs
		return $data->{r};
	} elsif ($data) {
		# we have the table, but we need to check its time
		my $ts = $class->_get_table_ts;

		if ($data->{u} >= $ts) {
			# we're current
			$class->{_checked} = 1;
			
			return $data->{r};
		} else {
			return $class->_load_times;
		}
	} else {
		# we don't have the table

		# we'll consider loading the times from db to be the same as 
		# checking the ts
		$class->{_checked} = 2;
		
		return $class->_load_times;
	}

	# everyone returns
}

#----------

sub _get_table_ts {
	my $class = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			ts
		from 
			" . $class->{_}->core->tbl_name("update_time") . "
		where 
			tbl = 'update_time'
	");

	$get->execute 
		or $class->{_}->bail->("get_table_ts failure: ".$get->errstr);

	my ($ts) = $get->fetchrow_array;

	return $ts;
}

#----------

sub _load_times {
	my $class = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			tbl,first,second,ts 
		from 
			" . $class->{_}->core->tbl_name("update_time") . "
	");

	$get->execute() 
		or $class->{_}->bail->("_load_times failure: ".$get->errstr);

	my ($tbl,$f,$s,$ts);
	$get->bind_columns( \($tbl,$f,$s,$ts) );

	my $times = {};
	while ($get->fetch) {
		$times->{ $tbl }{ $f }{ $s } = $ts;
	}

	# -- now throw this into the memcache -- #
	$class->{_}->core->memcache->set(
		"update_time",
		$times,
		$times->{update_time}{0}{0}
	);

	return $times;
}

#----------

1;
