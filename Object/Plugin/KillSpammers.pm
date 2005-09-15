package eThreads::Object::Plugin::KillSpammers;

use eThreads::Object::Plugin -Base;

#----------

sub activate {
	# find our glomule
	my $bind = $self->i->args->{bind} || $self->i->args->{DEFAULT};

	my $bctx = $self->_->gholders->exists($bind);

	if (!$bctx) {
		warn "KillSpammers: Unable to find ctx: $bind\n";
		return undef;
	}

	# now check if this ctx has an object note attached to it
	my $g = $bctx->note('object');

	if (!$g) {
		warn "KillSpammers: ctx doesn't have object note\n";
		return undef;
	}
	
	# register our posthook
	$g->posthooks->register( sub { $self->posthook(@_) } );
}

#----------

sub posthook {
	warn "posthook called\n";
}

#----------

1;
