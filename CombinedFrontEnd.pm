package eThreads::CombinedFrontEnd;

use strict;
use vars qw( $core );

use Apache::RequestRec ();
use Apache::Response ();
use Apache::RequestIO ();
use Apache::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED SERVER_ERROR);
use ModPerl::Util;

use eThreads::Object::Core;

sub child_init {
	my ($child_pool,$s) = @_;

	$core = new eThreads::Object::Core;

	return Apache::OK;
}

sub handler {
	my $r = shift;

	$core = new eThreads::Object::Core if (!$core);
	my $inst = $core->new_instance( $r );
	my $status = $inst->go();
	$inst->DESTROY;
	return $status;
}

1;

