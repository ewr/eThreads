package eThreads::Object::Cache::SingleServer;

@ISA = qw( eThreads::Object::Cache );

use strict;

#----------

sub get_max_update_ts {
	my $class = shift;
	my %a = @_;
	return 1;
}

#----------

sub load_cache_file {
	my $class = shift;
	my %a = @_;

	# format for cache file names in tbl.primary.secondary
	# both primary and secondary are optional

	my $name = join(".",($a{tbl},$a{primary},$a{secondary}));
	$name =~ s/(?:^\.|\.\.|\.$)//g;

	# load the cached file if it exists
	if (my $c = $class->get_cached_file($name)) {
		return $c;
	} else {
		return 0;
	}
}

#----------

1;
