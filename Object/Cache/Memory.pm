package eThreads::Object::Cache::Memory;

use strict;

use Cache::SizeAwareMemoryCache;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		cache	=> undef,
	} , $class );

	$class->{cache} = new Cache::SizeAwareMemoryCache( {
		namespace		=> "MemCache",
		max_size		=> 1000000,
	} );

	return $class;
}

#----------

sub set {
	my $class = shift;
	my $type = shift;
	my $key = shift;
	my $val = shift;

	my $ckey = $type . "WOOP" . $key;

	$class->{cache}->set($ckey,$val->cachable);
}

#----------

sub get {
	my $class = shift;
	my $type = shift;
	my $key = shift;

	my $ckey = $type . "WOOP" . $key;

	my $data = $class->{cache}->get($ckey);

	return $data;
}

#----------

1;
