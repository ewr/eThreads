package eThreads::Object::Template::Subtemplate;

@ISA = qw( eThreads::Object::Template );

use strict;

#----------

# new comes from Template.pm

#----------

sub type {
	return undef;
}

#----------

sub load_from_sub {
	my $class = shift;

	my @keys = keys %{$class->{_}};

	my $cache = $class->{_}->cache->get(
		tbl		=> "subtemplates",
		first	=> $class->{_}->container->id,
		second	=> $class->{_}->look->id,
	);

	if (!$cache) {
		$cache = $class->{_}->look->cache_subtemplates();
	}

	if (my $tmplt = $cache->{ $class->{path} }) {
		$class->{value} = $tmplt->{value};
		return 1;
	} else {
		return undef;
	}
}

#----------

1;
