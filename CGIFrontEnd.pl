#!/usr/bin/perl

use strict;
use vars qw( $core );

#use Apache::RequestRec ();
#use Apache::RequestIO ();
#use Apache::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED SERVER_ERROR);
#use ModPerl::Util;

use eThreads::Object::Core;

{
	my $core = new eThreads::Object::Core;
	my $inst = $core->new_object("Instance",$core->cgi_r_handler);
	$inst->go();
}

