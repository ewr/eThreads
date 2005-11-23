package eThreads::Object::Plugin::KillSpammers;

use eThreads::Object::Plugin -Base;

use URI::Find::Schemeless;
use Net::DNS;

#----------

sub activate {
	# get our parent...  
	my $p = $self->i->parent;

	# now check if this ctx has an object note attached to it
	my $g = $p->note('object');

	if (!$g) {
		$self->_->bail->("KillSpammers: parent doesn't have object note");
	}
	
	# register our posthook
	$g->posthooks->register( sub { $self->posthook($g,@_) } );
}

#----------

sub posthook {
	my $g = shift;
	my $hooks = shift;
	my $post = shift;
	my $gtype = shift;

	if (!$self->cfg) {
		# nothing we can do without a cfg
		return $hooks->PASS;
	}

	# now we need to look for urls in the body of the post
	my $status = 1;

	# init our resolver
	my $res = Net::DNS::Resolver->new;
	$res->tcp_timeout(2);
	$res->udp_timeout(2);

	my $find = URI::Find::Schemeless->new( sub {
		my $uri = shift;
		my $orig_uri = shift;
		my $host = $uri->host;

		my $a = $res->query($host);

		if ($a) {
			my $addr;

			foreach my $rr ($a->answer) {
				next unless $rr->type eq "A";
				$addr = $rr->address;
				last;
			}

			if ( $self->cfg->{ $addr } ) {
				# DIE SPAMMER
				$status = 0;
			} else {
				warn "ok by url ip lookup: $host\n";
			}
		} else {
			warn "resolve failed: $host\n";
		}

		return $orig_uri;
	} );

	foreach my $f ( @{ $gtype->edit_fields } ) {
		$find->find( \$post->{ $f->{name} } );
	}

	if ($status) {
		return $hooks->PASS;
	} else {
		return ($hooks->FAIL,"Domain known as spammer.");
	}
}

#----------

1;
