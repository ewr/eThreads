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
	my $ts = shift || time;

	# if they're caching it, it's current as of right now.  so we'll use 
	# now as our updated time

	$class->{cache}->set($name, { u => $ts , r => $ref } );
}

#----------

sub remove {
	my $class = shift;
	my $name = shift;

	$class->{cache}->remove( $name );
}

#----------

sub set_raw {
	my $class = shift;
	my $type = shift;
	my $key = shift;
	my $val = shift;

	my $ckey = $type . "WOOP" . $key;

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

=head1 NAME

eThreads::Object::Cache::Memory

=head1 SYNOPSIS

=head1 DESCRIPTION

This is the low-level persistant memory cache object.  It should be used 
through the Cache::Memory::Instance wrapper.

=over 4

=item new

Return a new memory cache.

=item set 

	$memcache->set($name,$ref,$ts);

Store an item ($ref) with key $name and update time $ts.

=item set_raw 

	$memcache->set_raw($type,$key,$val);

Store an abnormal item of type $type with key $key and value $val.

=item get 

	my $ref = $memcache->get($name);

Get an item with key $name.

=item remove 

	$memcache->remove($name);

Remove an item with name $name.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
