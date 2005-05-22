package eThreads::Object::Cache;

use strict;

use Storable;

use eThreads::Object::Cache::Memory;
use eThreads::Object::Cache::Memory::Instance;
use eThreads::Object::Cache::MultiServer;
#use eThreads::Object::Cache::SingleServer;
use eThreads::Object::Cache::Objects;
use eThreads::Object::Cache::UpdateTimes;

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

sub DESTROY {
	my $class = shift;
	return 1;
}

#----------

sub update_times {
	my $class = shift;

	if (!$class->{update_times}) {
		$class->{update_times} 
			= $class->{_}->new_object("Cache::UpdateTimes");
	}

	return $class->{update_times};
}

#----------

sub memory {
	my $class = shift;

	if (!$class->{memcache}) {
		$class->{memcache}
			= $class->{_}->switchboard->new_object("Cache::Memory::Instance");
	}

	return $class->{memcache};
}

#----------

sub objects {
	my $class = shift;

	if (!$class->{objects}) {
		$class->{objects} 
			= $class->{_}->new_object("Cache::Objects");
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

	if ( my $c = $class->memory->get(%a) ) {
		# memcache hit success
		return $c;
	} else {
		# get from disk
		$c = $class->load_cache_file(%a);

		if ($c) {
			# and cache to mem
			$class->memory->set(
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

	my $name = join('.' , ($a{tbl},$a{first},$a{second}) );
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

sub write_cache_file {
	my $class = shift;
	my %a = @_;

	my $name = $class->file_name(%a);

	# delete our file
	# $class->delete_cache_file($name);

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

	my $file = $class->{_}->core->settings->{dir}{cache}.'/cache.'.$name;

	return undef if (!-e $file);

	return Storable::retrieve(
		$file
	) or $class->{_}->bail->("could not retrieve $file: $!");
}

#----------

sub store {
	my ($class,$file,$dref) = @_;

	$class->{_}->bail->(0,"could not store in $file: $!") unless (
		Storable::store(
			$dref,
			$class->{_}->core->settings->{dir}{cache} . '/cache.' . $file
		)
	);
}

#----------

sub retrieve {
	# functionality moved into get_cached_file
}

#----------

=head1 NAME

eThreads::Object::Cache

=head1 SYNOPSIS

	my $cache = $inst->new_object("Cache");

	my $ref = $cache->get(tbl=>"",first=>"",second=>"");

	$cache->set(
		tbl		=> "",
		first	=> "",
		second	=> "",
		ref		=> ""
	);

=head1 DESCRIPTION

This is the main cache module for eThreads.  

=head1 IMPORTANT

It's important to note that you should never modify the data referenced by a 
cache object.  If you need to modify the data, B<MAKE YOUR OWN COPY>.  The 
referenced data can be global to multiple instances, so consider it read-only.

=head1 GENERAL FUNCTIONS

=over 4

=item new 

Returns a new Cache object.

=item update_times 

Returns a blessed ref to the Cache::UpdateTimes object.

=item memory

Returns a blessed ref to the Cache::Memory::Instance object.

=item objects

Returns a blessed ref to the Cache::Objects object.

=item get

	my $ref = $cache->get(tbl=>"",first=>"",second=>"");

Returns a reference to the cached object from either memory or disk, whichever 
is convenient.  Returns undef if it's a cache miss.  

=item set 

	$cache->set(
		tbl		=> "",
		first	=> "",
		second	=> "",
		ref		=> ""
	);

Writes (or rewrites) the cached object.  

=item expire 

	$cache->expire(tbl=>"",first=>"",second=>"");

Expire the given cache from both memory and disk.

=item file_name 

	my $file = $cache->file_name(tbl=>"",first=>"",second=>"");

Take tbl/first/second args and make a useful filename.  Used by disk cache 
for actual filenames, and by memcache as a flat key name.

=back

=head1 DISK CACHE FUNCTIONS

=over 4

=item load_cache_file

	my $ref = $cache->load_cache_file(tbl=>"",first=>"",second=>"");

Load a cache file from disk.

=item write_cache_file 

	$cache->write_cache_file(
		tbl		=> "",
		first	=> "",
		second	=> "",
		ref		=> ""
	);

Write a cache file to disk.

=item delete_cache_file

	$cache->delete_cache_file($file);

Deletes the given cache file.

=item get_cached_file

Used internally to retrieve disk cache files.

=item retrieve 

Used internally to retrieve disk cache files.

=item store 

Used internally to store disk cache files.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
