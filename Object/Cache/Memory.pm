package eThreads::Object::Cache::Memory;

use strict;

#use Cache::SizeAwareMemoryCache;
use Cache::MemoryCache;
use Cache::FastMemoryCache;

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		cache	=> undef,
	} , $class );

#	$class->{cache} = new Cache::SizeAwareMemoryCache( {
	$class->{cache} = new Cache::FastMemoryCache( {
		namespace		=> "MemCache",
#		max_size		=> 1000000,
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

	#warn "$$ before insert, cache size is: ". $class->{cache}->Size() . "\n";

	$class->{cache}->set($ckey,$val->cachable);
}

#----------

sub set_raw {
	my $class = shift;
	my $type = shift;
	my $key = shift;
	my $val = shift;

	my $ckey = $type . "WOOP" . $key;

	#warn "$$ before insert, cache size is: ". $class->{cache}->Size() . "\n";

	$class->{cache}->set($ckey,$val);
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
