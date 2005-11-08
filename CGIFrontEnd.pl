#!/usr/bin/perl

use strict;
use vars qw( $core );

use lib qw( ./ );

use eThreads::Object::Core;

{
	my $core = new eThreads::Object::Core;
	$core->cgi_enable;
	my $inst = $core->new_instance( $core->cgi_r_handler );
	$inst->go();
	$inst->DESTROY;
}

