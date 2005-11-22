package eThreads::Object::GHolders;

use Spiffy -Base;

use strict;
no warnings;

use eThreads::Object::GHolders::GHolder;
use eThreads::Object::GHolders::Link;
use eThreads::Object::GHolders::RegisterContext;

#----------

const 'valid_objects'	=> {
	'Link'		=> 1,
};

field '_'		=> -ro;
field 'root'	=> -ro;

sub new {
	my $data = shift;

	$self = bless ( { _=>$data }, $self );

	$self->gholder_init;

	return $self;
}

#----------

sub DESTROY {
	undef $self->{root};
	undef $self->{context};

	return 1;
}

#----------

sub gholder_init {
	my $i = $self->_;

	my $t = $i->new_object('GHolders::GHolder');
	$self->{root} = $self->{context} = $t;

	my $raw 	= $i->new_object('GHolders::GHolder','raw',$t);
	my $foreach = $i->new_object('GHolders::GHolder','foreach',$t);
	my $if 		= $i->new_object('GHolders::GHolder','if',$t);
	my $context	= $i->new_object('GHolders::GHolder','context',$t);
	my $tmplt	= $i->new_object('GHolders::GHolder','template',$t);
	my $link 	= $i->new_object('GHolders::GHolder','link',$t);
	my $require	= $i->new_object('GHolders::GHolder','require',$t);

	$raw->sub(		sub { return $self->handle_raw(@_) }		);
	$foreach->sub(	sub { return $self->handle_foreach(@_) }	);
	$if->sub( 		sub { return $self->handle_if(@_) }		);
	$context->sub(	sub { return $self->handle_context(@_) }	);
	$tmplt->sub(	sub { return $self->handle_template(@_) }	);
	$link->sub(		sub { return $self->handle_link(@_) }		);
	$require->sub(	sub { return $self->handle_require(@_) }	);

	return 1;
}

#----------

sub register {
	my @gholders;
	if (ref($_[0]) eq 'ARRAY') {
		@gholders = @_;
	} else {
		@gholders = ( [ $_[0] , $_[1] ] );
	}

	foreach my $gh (@gholders) {
		$self->root->register( $gh->[0] , $gh->[1] );
	}

	1;
}

#----------

sub is_gh_object {
	my $val = shift;

	if ( ref($val) =~ m!^eThreads::Object::GHolders::(.*)! ) {
		my $type = $1;
		if ( $self->_->gholders->valid_objects->{ $type } ) {
			return 1;
		} else {
			$self->_->bail->("Invalid GHolder object type as data: $type");
		}
	} else {
		return undef;
	}
}

#----------

sub register_blank {
	my $ctx = shift;
	$self->register([$ctx,'']);
}

#----------

sub exists {
	my $h = shift;
	my ($no,$force,$named);
	
	($no,$force,$named,$h) = $h =~ m!^(?:(\./)|(/)|\$([^\.]+)\.?)?(.*)$!;

	if ($named) {
		# find the context for the given prefix and look only there
		if ( my $ctx = $self->get_named_ctx($named) ) {
			# they gave us a named context but nothing else
			# we'll just return that
			return $ctx if ( !$h );

			# otherwise look for $h under our context
			#return $ctx->_exists($h);
			return $self->_exists($h,$ctx);
		} else {
			return undef;
		}
	} elsif (!$force && !$no) {
		# try current context, then try root
		return 
			$self->_exists($h,$self->{context})
			|| $self->_exists($h,$self->root);
	} elsif ($force) {
		return $self->_exists($h,$self->root); 
	} elsif ($no) {
		return $self->_exists($h,$self->{context});
	} else {
		return undef;
	} 

	# ummm, everybody returns, so we can't get here.
}

#sub _exists {
#	my ($h,$ctx) = @_;
#	$ctx->_exists($h);
#}

sub _exists {
	my ($h,$ctx) = @_;

	my $test = 1;

	if ($h =~ m!\.!) {
		foreach my $part (split(/\./,$h)) {
			warn "checking for child $part\n";
			if (my $new = $ctx->has_child($part)) {
				$ctx = $new;
			} else {
				$test = 0;
				last;
			}
		}

		return ($test) ? $ctx : undef;
	} else {
		warn "checking for child $h\n";
		return $ctx->has_child($h);
	}
}

#----------

sub get_unused_child {
	my $parent = shift;

	my $ctx;
	do {
		my $key = $self->_->utils->random('4');
		$ctx = $parent . '.' . $key;
	} until (!$self->exists($ctx));

	return $ctx;
}

#----------

sub new_link {
	my $key = shift;
	my $path = shift;
	return $self->_->new_object('GHolders::Link',$key,$path);
}

#----------

sub new_named_ctx {
	my $name = shift;
	my $ctx = shift;

	if (ref($ctx) eq 'CODE') {
		$self->{named}{ $name } = $ctx;
		return 1;	
	}

	my $prefix = ( $ctx =~ m!^(?:\.?/|\$)! ) ? '' : './';

	if (my $ref = $self->exists($prefix . $ctx)) {
		$self->{named}{ $name } = $ref;
		return 1;
	} else {
		return 0;
	}
}

#----------

sub get_named_ctx {
	my $name = shift;
	return $self->{named}{ $name } || undef;
}

#----------

sub remove_named_ctx {
	my $name = shift;
	delete $self->{named}{ $name };
}

#----------

sub set_context {
	my $context = shift;

	if (ref($context)) {
		$self->{context} = $context;
		return 1;
	}

	my $prefix = ($context =~ m!^\.?/!) ? '' : './';

	if (my $ref = $self->exists($prefix . $context)) {
		$self->{context} = $ref;
		return 1;
	} else {
		return 0;
	}
}

#----------

sub get_context {
	return $self->{context};
}

#----------

sub handle_if {
	my $i = shift;

	my $a = $i->args->{DEFAULT};
	my $inv;
	if ($a =~ /^!/) {
		$a =~ s/^!//;
		$inv = 1;
	}

	my $gh = $self->exists($a);

	if (
		(!$inv && $gh && ($gh->flat || $gh->array)) 
		|| ($inv && !($gh && ($gh->flat || $gh->array)))
	) {
		# we let the flow continue
		return 1;
	} else {
		# we remove the subitems
		return undef;
	}
}

#----------

sub handle_foreach {
	my $i = shift;

	my $aname = $i->args->{list} || $i->args->{DEFAULT};

	# see if the arg value is legal
	if ( my $gh = $self->exists( $aname ) ) {
		if ($gh->array) {
			my $ctx = $self->get_context;
			foreach my $el ( @{ $gh->array } ) {
				my $new_ctx = 
						($el =~ m!^/!) 
							? $el : ( $aname . '.' . $el );

				if ($i->args->{name}) {
					$self->new_named_ctx($i->args->{name},$new_ctx);
					$self->handle_template_tree($i,$_[0]);
					$self->remove_named_ctx($i->args->{name});
				} else {
					$self->set_context($new_ctx);
					$self->handle_template_tree($i,$_[0]);
					$self->set_context($ctx);
				}
			}
			return undef;
		} else {
			return undef;
		}
	} else {
		return undef;
	}
}

#----------

sub handle_require {
	my $i = shift;

	my $level = $i->args->{level} || $i->args->{DEFAULT};

	my ($inv) = $level =~ s/^(!)//;

	# if we don't have a user, we can't have any rights
	if (!$self->_->switchboard->knows('user')) {
		# if normal, return 0... if inv return 1
		return ($inv) ? 1 : 0;
	}

	if ($self->_->user->has_rights($level)) {
		# if normal, return 1... if inv return 0
		return ($inv) ? 0 : 1;
	} else {
		# if normal, return 0... if inv return 1
		return ($inv) ? 1 : 0;
	}
}

#----------

sub handle_raw {
	my $i = shift;
	
	$_[0] .= $i->content;

	return undef;
}

#----------

sub handle_link {
	my $i = shift;

	my $template = $i->args->{template} || $i->args->{DEFAULT};

	if (!$template) {
		$self->handle_template_tree($i,$template);
	}

	# make a copy of the args
	my $args = {};
	%$args = %{$i->args};

	while ( my $c = $i->children->next ) {
		$self->handle_link_qopt($c,$args);
	}

	$_[0] .= $self->_->queryopts->link($template,$args);

	return undef;
}

#----------

sub handle_link_qopt {
	my $i = shift;
	my $opts = shift;

	# only handle qopts
	return 0 if ($i->type ne 'qopt'); 

	# make sure we've got an opts hash to throw into
	return 0 if (ref($opts) ne 'HASH');

	my $name = $i->args->{name} || $i->args->{DEFAULT};
	return 0 if (!$name);

	my $v;
	$self->_->gholders->handle_template_tree($i,$v);

	$opts->{$name} = $v;
}

#----------

sub handle_context {
	my $i = shift;

	my $uctx = $i->args->{context} || $i->args->{DEFAULT};

	return undef if (!$uctx);

	if (my $gh = $self->exists($uctx)) {
		if ($i->args->{name}) {
			$self->new_named_ctx($i->args->{name},$gh);
			$self->handle_template_tree($i,$_[0]);
			$self->remove_named_ctx($i->args->{name});
		} else {
			my $ctx = $self->get_context;
			$self->set_context($gh);
			$self->handle_template_tree($i,$_[0]);
			$self->set_context($ctx);
		}

		return undef;
	} else {
		return undef;
	}
}

#----------

sub handle_template {
	my $i = shift;

	my $name = $i->args->{template} || $i->args->{DEFAULT};

	my $t = $self->_->look->load_subtemplate_by_path($name)
		or return undef;

	return $self->_->gholders->handle_template_tree(
		$t->get_tree,$_[0]
	);
}

#----------

sub handle_unknown {
	my $i = shift;

	$_[0] .= $self->_handle_unknown($i);

	return undef;
}

sub _handle_unknown {
	my $i = shift;

	my $ret;

	if ($i->type eq 'raw') {
		$ret .= $i->content;
	} else {
		# start with the tag
		$ret .= '{' . $i->type . ' ';
	
		# add our arguments
		my @args;
		while ( my ($k,$v) = each %{ $i->args } ) {
			next if (!$k);
			push @args, qq($k=>"$v");
		}
		$ret .= join(',',@args) . ' ';

		# opening tag or single?  single if no children
		if (!$i->children->count) {
			$ret .= '/}';
		} else {
			$ret .= '}';
			while ( my $c = $i->children->next ) {
				$ret .= $self->_handle_unknown($c);
			}
			$ret .= '{/' . $i->type . '}';
		}
	}

	return $ret;
}

#----------

sub handle {
	my $i = shift;

	# call the handler for this tag
	if ( my $ref = $self->exists( $i->type ) ) {
		if ($ref->sub) {
			return $ref->sub->($i,$_[0]);
		} else {
			my ($ltype) = $i->type =~ m!^.*\.([^\.]+)$!;
			# check for a top-level handler
			if ( my $href = $self->exists( '/'.$ltype ) ) {
				if ($href->sub) {
					return $href->sub->($i,$ref->flat,$_[0]);
				} else {
					$_[0] .= $ref->flat;
					return 1;
				}
			} else {
				$_[0] .= $ref->flat;
				return 1;
			}
		}
	} else {
		return $self->handle_unknown($i,$_[0]);
	}
}

#----------

sub handle_template_tree {
	my $tree = shift;

	while ( my $i = $tree->children->next ) {
		$self->handle( $i , $_[0] ) 
			and $self->handle_template_tree( $i , $_[0] );
	}

	return 1;
}

#----------

1;
