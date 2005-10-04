package eThreads::Object::Plugin::BannedWords;

use eThreads::Object::Plugin -Base;
no warnings;

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

	# put together the match regex
	my $match = 
		eval 
			"sub { \$_ = shift; m!(?:" . 
			join('|',@{$self->cfg}) . 
			")!i; }";

	foreach my $f ( @{ $gtype->edit_fields } ) {
		if ( $match->( $post->{ $f->{name} } ) ) {
			$status = 0;
		} else {
			# ok
		}
	}

	if ($status) {
		return $hooks->PASS;
	} else {
		return ($hooks->FAIL,"Post contains one or more banned words.");
	}
}

#----------

1;
