package eThreads::Object::Template::Subtemplate;

use eThreads::Object::Template -Base;
use eThreads::Object::Template::Subtemplate::Writable;

#----------

const 'TABLE'	=> 'subtemplates';

field 'writable'	=> 
	-ro,
	-init=>q! 
		bless { %$self } , 'eThreads::Object::Template::Subtemplate::Writable';
	!;

#----------

# new comes from Template.pm

#----------

sub type {
	return undef;
}

sub qopts {
	my @caller = caller;
	$self->_->bail("called qopts on subtemplate: @caller");
}

#----------

sub load_from_sub {
	my $cache = $self->{_}->cache->get(
		tbl		=> "subtemplates",
		first	=> $self->{_}->container->id,
		second	=> $self->{_}->look->id,
	);

	if (!$cache) {
		$cache = $self->{_}->look->cache_subtemplates();
	}

	if (my $tmplt = $cache->{ $self->{path} }) {
		$self->{value} = $tmplt->{value};
		return 1;
	} else {
		return undef;
	}
}

#----------

1;
