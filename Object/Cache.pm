package eThreads::Object::Cache;

use strict;

use Storable;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_	=> $data,
	} , $class ); 

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
	return 1;
}

#----------

sub update_times {
	my $class = shift;

	if (!$class->{update_times}) {
		$class->{update_times} 
			= $class->{_}->instance->new_object("Cache::UpdateTimes");
	}

	return $class->{update_times};
}

#----------

sub memory {
	my $class = shift;

	return $class->{_}->memcache;
}

#----------

sub objects {
	my $class = shift;

	if (!$class->{objects}) {
		$class->{objects} 
			= $class->{_}->instance->new_object("Cache::Objects");
	}

	return $class->{objects};
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

	$class->{_}->bail->(0,"get_max_update_ts failure: ".$db->errstr) 
		if (!$get_max->execute($a{tbl}));

	my $ts;
	$get_max->bind_columns(\$ts);
	$get_max->fetch;

	return $ts;
}

#----------

sub get {
	my $class = shift;
	my %a = @_;

	if ( my $c = $class->{_}->memcache->get(%a) ) {
		# memcache hit success
		return $c;
	} else {
		# get from disk
		$c = $class->load_cache_file(%a);

		if ($c) {
			# and cache to mem
			$class->{_}->memcache->set(
				%a,
				ref	=> $c,
				ts	=> $class->update_times->get(%a)
			);

			return $c;
		} else {
			# cache miss
			return undef;
		}
	}
}

#----------

sub expire {
	my $class = shift;
	my %a = @_;

	# expire from mem
	$class->memory->expire(%a);

	# and delete off disk
	my $name = $class->file_name(%a);
	$class->delete_cache_file($name);
}

#----------

sub set {
	my $class = shift;
	my %a = @_;

	# make sure we have a ts
	$a{ts} = time if (!$a{ts});

	# write disk cache
	$class->write_cache_file(%a);

	# and stick in memcache
	$class->memory->set(%a);

	return 1;
}

#----------

sub file_name {
	my $class = shift;
	my %a = @_;

	$a{first} = 0 if (!$a{first} && $a{second});

	my $name = join("." , ($a{tbl},$a{first},$a{second}) );
	$name =~ s/(?:^\.|\.\.|\.$)//g;

	return $name;
}

#----------

sub load_cache_file {
	my $class = shift;
	my %a = @_;

	my $name = $class->file_name(%a);

	# load the cached file if it exists
	if (my $data = $class->get_cached_file($name)) {
		my $ts = $class->update_times->get(%a);

		if ($ts > $data->{u}) {
			return undef;
		} else {
			return $data->{r};
		}
	} else {
		return undef;
	}
}

#----------

=item B<write_cache_file>

	$e{modules}{cache}->write_cache_file(
		tbl		=> $tbl,
		ref		=> $ref,
	);

=cut

sub write_cache_file {
	my $class = shift;
	my %a = @_;

	my $name = $class->file_name(%a);

	# delete our file
	$class->delete_cache_file($name);

	# and then rewrite it 
	$class->store($name , { u => $a{ts} , r => $a{ref} } );
}

#----------

sub delete_cache_file {
	my ($class,$name) = @_;

	$class->{_}->bail->(
		"delete_cache_file: Improper characters in file name: $name"
	) if ($name !~ m!^[\w\d\.]+$!);

	my $file = $class->{_}->core->settings->{dir}{cache} . "/cache." . $name;

	if (-e $file) {
		`rm $file`;
	}
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

	$class->{_}->bail->(0,"could not store in $file: $!") unless (
		Storable::store(
			$dref,
			$class->{_}->core->settings->{dir}{cache} . "/cache." . $file
		)
	);
}

#----------

sub retrieve {
	my ($class,$file) = @_;
	return Storable::retrieve($file) or $class->{_}->bail->(
		0,"could not retrieve $file: $!"
	);
}

#----------

1;
