package eThreads::Object::Cache::Memory::Instance;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		objects	=> {},
	} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;

	%{$class->{objects}} = ();

	return 1;
}

#----------

sub set {
	my $class = shift;
	my %a = @_;

	my $name = $class->{_}->cache->file_name(%a);

	$class->{_}->core->memcache->set($name,$a{ref},$a{ts});
}

#----------

sub get {
	my $class = shift;
	my %a = @_;

	my $name = $class->{_}->cache->file_name(%a);

	my $data = $class->{_}->core->memcache->get($name);
	return undef if (!$data);

	# now compare update times
	my $cts = $class->{_}->cache->update_times->get(%a);

	if ($data->{u} >= $cts) {
		return $data->{r};
	} else {
		$class->{_}->core->memcache->set($name,undef);
		return undef;
	}
}

#----------

sub set_raw {
	my $class = shift;

	$class->{_}->core->memcache->set_raw(@_);
}

#----------

sub get_raw {
	my $class = shift;

	$class->{_}->core->memcache->get(@_);
}

#----------

1;
