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
	my $name = shift;
	my $ref = shift;

	# if they're caching it, it's current as of right now.  so we'll use 
	# now as our updated time

	$class->{cache}->set($name, { u => time , r => $ref } );
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
	my $name = shift;

	my $data = $class->{cache}->get($name);

	return $data;
}

#----------

1;
