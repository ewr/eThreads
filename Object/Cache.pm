package eThreads::Object::Cache;

use strict;

use Storable;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_	=> $data,
		cache	=> {},
	} , $class ); 

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
	$class->{cache} = undef;
	return 1;
}

#----------

sub get_update_ts {
	my $class = shift;
	my %a = @_;

	my $db = $class->{_}->core->get_dbh;

	$a{first} = 0 if (!$a{first});
	$a{second} = 0 if (!$a{second});

	my $get_updated = $db->prepare("
		select 
			ts 
		from 
			" . $class->{_}->core->tbl_name("update_time") . "
		where 
			tbl = ? 
			and first = ?
			and second = ?
	"); 

	$get_updated->execute($a{tbl},$a{first},$a{second})
		or $class->{_}->core->bail("get_update_ts: ".$db->errstr);
	my ($ts) = $get_updated->fetchrow_array;
    
	return $ts;
}

#----------

sub get_max_update_ts {
	my $class = shift;
	my %a = @_;

	my $db = $class->{_}->core->get_dbh;

	my $gtree;
	if ($a{gtree}) {
		$gtree = "and first in (".join(",",@{$a{ptree}}).")";
	}

	my $ktree;
	if ($a{ktree}) {
		$ktree = "and second in (".join(",",@{$a{stree}}).")";
	}

	my $get_max = $db->prepare("
		select 
			max(ts) 
		from 
			" . $class->{_}->core->tbl_name("update_time") . "
		where 
			tbl = ? 
			$gtree 
			$ktree
	");

	$class->{_}->core->bail(0,"get_max_update_ts failure: ".$db->errstr) 
		if (!$get_max->execute($a{tbl}));

	my $ts;
	$get_max->bind_columns(\$ts);
	$get_max->fetch;

	return $ts;
}

#----------

sub set_update_ts {
	my $class = shift;
	my %a = @_;

	# -- update the value in the db -- #

	$class->{_}->core->set_value(
		tbl		=> $class->{_}->core->tbl_name("update_time"),
		keys	=> {
			tbl		=> $a{tbl},
			first	=> $a{first} || 0,
			second	=> $a{second} || 0,
		},
		value_field	=> "ts",
		value		=> $a{ts}
	);

	# -- also delete our cache file locally -- #

	my $name = join(".",($a{tbl},$a{first},$a{second}));
	$name =~ s/(?:^\.|\.\.|\.$)//g;

	$class->delete_cache_file($name);

	# -- and delete in mem -- #

	undef $class->{cache}{ $a{tbl} }{ $a{first} }{ $a{second} };

	return 1;
}

#----------

sub load_cache_file {
	my $class = shift;
	my %a = @_;

	my $name = join(".",($a{tbl},$a{first},$a{second}));
	$name =~ s/(?:^\.|\.\.|\.$)//g;

	if (my $c = $class->{cache}{ $a{tbl} }{ $a{first} }{ $a{second} }) {
		return $c;
	}

	# load the cached file if it exists
	if (my $c = $class->get_cached_file($name)) {
		my $ts = 
			$a{ts} || $class->get_update_ts(
				tbl			=> $a{tbl},
				first		=> $a{first},
				second	=> $a{second}
			);

		my $cts;
		if ( ref($c) eq "HASH" ) {
			$cts = $c->{ ".updated" };

			# and delete the update ts
			delete $c->{ ".updated" };
		} elsif ( ref($c) eq "ARRAY" ) {
			$cts = pop @$c;
		} else {
			$class->{_}->core->bail("cache ref unknown type ".ref($a{ref}));
		}

		if ($ts > $cts) {
			return 0;
		} else {
			# keep this cache object open in case we need it again later
			$class->{cache}{ $a{tbl} }{ $a{first} }{ $a{second} } = $c;

			return $c;
		}
	} else {
		return 0;
	}
}

#----------

=item B<write_cache_file>

	$e{modules}{cache}->write_cache_file(
		tbl		=> $tbl,
		glomule	=> $glomule, (optional)
		ref		=> $ref,
		ts		=> $ts, (optional)
	);

=cut

sub write_cache_file {
	my $class = shift;
	my %a = @_;

	my $ts = 
		$a{ts} || $class->get_update_ts(
			tbl		=> $a{tbl},
			first	=> $a{first},
			second	=> $a{second},
		);

	if ( ref($a{ref}) eq "HASH" ) {
		$a{ref}{ ".updated" } = $ts;
	} elsif ( ref($a{ref}) eq "ARRAY" ) {
		push @{ $a{ref} }, $ts;
	} else {
		$class->{_}->core->bail("cache ref unknown type ".ref($a{ref}));
	}

	my $name = join(".",($a{tbl},$a{first},$a{second}));
	$name =~ s/(?:^\.|\.\.|\.$)//g;

	$class->store($name , $a{ref});

	if ( ref($a{ref}) eq "HASH" ) {
		# delete the update ts
		delete $a{ref}{ ".updated" };
	} elsif ( ref($a{ref}) eq "ARRAY" ) {
		# get ts back off the end
		pop @{ $a{ref} };
	}
}

#----------

sub delete_cache_file {
	my ($class,$name) = @_;

	$class->{_}->core->bail(
		"delete_cache_file: Improper characters in file name: $name"
	) if ($name !~ m!^[\w\d\.]+$!);

	my $file = $class->{_}->core->settings->{dir}{cache} . "/cache." . $name;
	`rm $file`;
}

#----------

sub get_cached_file {
	my $class = shift;
	my $name = shift;

	my $file = $class->{_}->core->settings->{dir}{cache}."/cache.".$name;

	if (-e $file) {
		return $class->retrieve($file);
	} else {
		return 0;
	}
}

#----------

sub store {
	my ($class,$file,$dref) = @_;

	$class->{_}->core->bail(0,"could not store in $file: $!") unless (
		Storable::store(
			$dref,
			$class->{_}->core->settings->{dir}{cache} . "/cache." . $file
		)
	);
}

#----------

sub retrieve {
	my ($class,$file) = @_;
	return Storable::retrieve($file) or $class->bail(
		0,"could not retrieve $file: $!"
	);
}

#----------

1;
