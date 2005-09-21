package eThreads::Object::Plugin::KillSpammers;

use eThreads::Object::Plugin -Base;

use URI::Find::Schemeless;

#----------

sub activate {
	# get our parent...  
	my $p = $self->i->parent;

	warn "p: ".$p->type ."\n";

	# now check if this ctx has an object note attached to it
	my $g = $p->note('object');

	if (!$g) {
		$self->_->bail->("KillSpammers: parent doesn't have object note");
	}
	
	# register our posthook
	$g->posthooks->register( sub { $self->posthook(@_) } );
}

#----------

sub posthook {
	my $hooks = shift;
	my $post = shift;

	warn "posthook called\n";

	if (!$self->cfg) {
		# nothing we can do without a cfg
		return $hooks->PASS;
	}

	# now we need to look for urls in the body of the post
	my $status = 1;

	my $find = URI::Find::Schemeless->new( sub {
		my ($uri, $orig_uri) = @_;
		warn "host: " . $uri->host . "\n";
	} );

	while ( my ( $k,$v ) = each %$post ) {
		$find->find( \$v );
	}

	if ($status) {
		return $hooks->PASS;
	} else {
		return $hooks->FAIL;
	}
}

#----------

1;
