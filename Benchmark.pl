#!/usr/bin/perl

use strict;
use vars qw( $core );

use lib qw( /etc/apache2/perl );

#use Apache::RequestRec ();
#use Apache::RequestIO ();
use Apache::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED SERVER_ERROR);
#use ModPerl::Util;

use Benchmark;

use eThreads::Object::Core;

if (0) {
	my $core = new eThreads::Object::Core;
	$core->cgi_enable;

	for (1..20) 
	{
		warn "it\n";
		my $inst = $core->new_object("Instance",$core->cgi_r_handler);
		$inst->go();
		$inst->DESTROY;
	}
}

if (1) {
	my $core = new eThreads::Object::Core;
	$core->cgi_enable;

	timethis(20,sub {
		my $inst = $core->new_object("Instance",$core->cgi_r_handler);
		$inst->go();
		$inst->DESTROY;
	});
}

#----------

sub eThreads::Object::FakeRequestHandler::print {
	return 1;
#	print @_;
}

