#!/usr/bin/perl

use strict;
use vars qw( $core );

use lib qw( ./ );

#use Apache::RequestRec ();
#use Apache::RequestIO ();
use Apache::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED SERVER_ERROR);
#use ModPerl::Util;

use eThreads::Object::Core;

{
	my $core = new eThreads::Object::Core;
	$core->cgi_enable;

	for (1..20) 
	{
		my $inst = $core->new_object("Instance",$core->cgi_r_handler);
		$inst->go();
		$inst->DESTROY;
	}
}

#----------

sub eThreads::Object::FakeRequestHandler::print {
	return 1;
#	print @_;
}

