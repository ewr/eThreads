package eThreads::Object::System::Ping::XMLRPC;

@ISA = qw( eThreads::Object::System::Ping::BaseMethod );

use strict;

use RPC::XML::Client;

#----------

sub ping {
	my $class = shift;

	my $cli = RPC::XML::Client->new($class->url);
	my $resp = $cli->send_request(
		$class->func,$class->title,$class->local
	);
					    
	warn "ping $class->{id} failed: $resp" if (!ref($resp));
}

#----------

1;
