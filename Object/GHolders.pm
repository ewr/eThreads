package eThreads::Object::GHolders;

use strict;
use Storable;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( { _=>$data }, $class );

	$class->gholder_init;

	return $class;
}

#----------

sub new_empty {
	my $class = shift;
	my $data = shift;

	$class = bless ( $data , $class );

	my $t = $class->{_}->instance->new_object("GHolders::GHolder");
	$class->{p} = $class->{context} = $t;

	return $class;
}

#----------

sub DESTROY {
	my ($class) = @_;

	$class->cleanup_gholders($class->{p});

	undef $class->{p};
	undef $class->{context};

	return 1;
}

#----------

sub cleanup_gholders {
	my ($class,$gh) = @_;

	while (my ($k,$c) = each %{$gh->children}) {
		$class->_alienate_gholders($c);
	}

	%{$gh->children} = ();

	return 1;
}

sub _alienate_gholders {
	my ($class,$gh) = @_;

	while (my ($k,$c) = each %{$gh->children}) {
		$class->_alienate_gholders($c);
	}

	undef $gh->{parent};

	return 1;
}

#----------

sub gholder_init {
	my $class = shift;

	my $i = $class->{_}->instance;

	my $t = $i->new_object("GHolders::GHolder");
	$class->{p} = $class->{context} = $t;

	my $raw 	= $i->new_object("GHolders::GHolder","raw",$t);
	my $foreach = $i->new_object("GHolders::GHolder","foreach",$t);
	my $if 		= $i->new_object("GHolders::GHolder","if",$t);
	my $context	= $i->new_object("GHolders::GHolder","context",$t);
	my $tmplt	= $i->new_object("GHolders::GHolder","template",$t);
	my $link 	= $i->new_object("GHolders::GHolder","link",$t);
	my $require	= $i->new_object("GHolders::GHolder","require",$t);

	$raw->sub(		sub { return $class->handle_raw(@_) }		);
	$foreach->sub(	sub { return $class->handle_foreach(@_) }	);
	$if->sub( 		sub { return $class->handle_if(@_) }		);
	$context->sub(	sub { return $class->handle_context(@_) }	);
	$tmplt->sub(	sub { return $class->handle_template(@_) }	);
	$link->sub(		sub { return $class->handle_link(@_) }		);
	$require->sub(	sub { return $class->handle_require(@_) }	);

	return 1;
}

#----------

sub register {
	my $class = shift;

	my @gholders;
	if (ref($_[0]) eq "ARRAY") {
		@gholders = @_;
	} else {
		@gholders = ( [ $_[0] , $_[1] ] );
	}

	foreach my $gh (@gholders) {
		my $var;

		if ( my $ref = $class->exists($gh->[0]) ) {
			$var = $ref;
		} elsif ( $gh->[0] =~ /\./ ) {
			my ($h,$k) = $gh->[0] =~ m!^(.*)\.([^\.]+)$!;

			if (my $ref = $class->exists($h)) {
				if ( my $child = $ref->has_child($k) ) {
					$var = $child;
				} else {
					$var = $class->{_}->instance->new_object(
						"GHolders::GHolder",$k,$ref
					);
				}
			} else {
				# we need to create the levels under this
				my $parent = $class->{p};
				foreach my $l (split(/\./,$h)) {
					if ( my $child = $parent->has_child($l) ) {
						$parent = $child;
					} else {
						$parent = $class->{_}->instance->new_object(
							"GHolders::GHolder",$l,$parent
						);
					}
				}

				$var = $class->{_}->instance->new_object(
					"GHolders::GHolder",$k,$parent
				);
			}
		} else {
			$var = $class->{_}->instance->new_object(
				"GHolders::GHolder",$gh->[0],$class->{p}
			);
		}

		# now assign a value
		if ( !ref( $gh->[1] ) ) {
			# flat value
			$var->flat($gh->[1]);
		} elsif (ref($gh->[1]) eq "HASH") {
			# hash ref...  needs to be cloned into our structure
			$class->assimilate_hash($var,$gh->[1]);
		} elsif (ref($gh->[1]) eq "ARRAY") {
			$var->array($gh->[1]);
		} elsif (ref($gh->[1]) eq "CODE") {
			$var->sub($gh->[1]);
		} else {
			$class->bail(0,"Unsupported gholder value: $gh->[0]/$gh->[1]");
		}
	}
}

#----------

sub assimilate_hash {
	my ($class,$obj,$href) = @_;

	my $path = $obj->key_path;

	my $a = [];
	$class->_assimilate_and_return_keys($path,$a,$href);

	$class->register(@$a);
}

sub _assimilate_and_return_keys {
	my ($class,$k,$a,$h) = @_;

	while (my ($e,$v) = each %$h) {
		my $abs = join(".",($k,$e));
		if ( ref($v) eq "HASH" ) {
			$class->_assimilate_and_return_keys($abs,$a,$v);
		} else {
			push @$a, [$abs,$v];
		}
	}
}

#----------

sub dump {
	my $class = shift;
	my $ref = shift;

	if (1) {
		use Data::Dumper;
		my $d = Data::Dumper->Dump($ref);

		open(
			DUMP,
			">".$class->{_}->core->settings->{dir}{cache}."/gholder_dump"
		) or $class->{_}->instance->bail("couldn't dump: $!");

		print DUMP $d;
		close DUMP;
	}
}

#----------

sub exists {
	my ($class,$h) = @_;

	my ($no_context,$force_context,$named_context);

	if ($h =~ s!^/!!) {
		$no_context = 1;
	} elsif ($h =~ s!^\./!!) {
		$force_context = 1;
	} elsif ($h =~ s!^\$([^\.]+)\.!!) {
		# named contextual prefix
		$named_context = $1;
		$force_context = 1;
	} else {
		# no context given or needed
	}

	if ($named_context) {
		# find the context for the given prefix and look only there

		if ( my $ctx = $class->{named}{$named_context} ) {
			return $class->_exists($h,$ctx);
		} else {
			return undef;
		}
	} else {
		# try current context, then try root

		if (!$no_context) {
			my $ref = $class->_exists($h,$class->{context});
			return $ref if ($ref);
		}

		if (!$force_context && ( $class->{context} ne $class->{p}) ) {
			return $class->_exists($h,$class->{p});
		}
	} 

	# ummm, everybody returns, so we can't get here.
}

sub _exists {
	my ($class,$h,$ctx) = @_;

	my $test = 1;

	foreach my $part (split(/\./,$h)) {
		if (my $new = $ctx->has_child($part)) {
			$ctx = $new;
		} else {
			$test = 0;
			last;
		}
	}

	if ($test) {
		return $ctx;
	} else {
		return 0;
	}
}

#----------

sub new_named_ctx {
	my $class = shift;
	my $name = shift;
	my $ctx = shift;

	if (ref($ctx) eq "CODE") {
		$class->{named}{ $name } = $ctx;
		return 1;	
	}

	my $prefix = ($ctx =~ m!^(?:\.?/|\$)!) ? '' : "./";

	if (my $ref = $class->exists($prefix . $ctx)) {
		$class->{named}{ $name } = $ref;
		return 1;
	} else {
		return 0;
	}
}

#----------

sub remove_named_ctx {
	my $class = shift;
	my $name = shift;

	delete $class->{named}{ $name };
}

#----------

sub set_context {
	my $class = shift;
	my $context = shift;

	if (ref($context)) {
		$class->{context} = $context;
		return 1;
	}

	my $prefix = ($context =~ m!^\.?/!) ? '' : "./";

	if (my $ref = $class->exists($prefix . $context)) {
		$class->{context} = $ref;
		return 1;
	} else {
		return 0;
	}
}

#----------

sub get_context {
	my $class = shift;
	return $class->{context};
}

#----------

sub handle_if {
	my $class = shift;
	my $i = shift;

	my $a = $i->args->{DEFAULT};
	my $inv;
	if ($a =~ /^!/) {
		$a =~ s/^!//;
		$inv = 1;
	}

	my $gh = $class->exists($a);

	if (
		(!$inv && $gh && ($gh->flat || $gh->array)) 
		|| ($inv &! ($gh && ($gh->flat || $gh->array)))
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
	my $class = shift;
	my $i = shift;

	my $aname = $i->args->{list} || $i->args->{DEFAULT};

	# see if the arg value is legal
	if ( my $gh = $class->exists( $aname ) ) {
		if ($gh->array) {
			my $ctx = $class->get_context;
			foreach my $el ( @{ $gh->array } ) {
				my $new_ctx = 
						($el =~ m!^/!) 
							? $el : ( $aname . "." . $el );

				if ($i->args->{name}) {
					$class->new_named_ctx($i->args->{name},$new_ctx);
					$class->handle_template_tree($i,$_[0]);
					$class->remove_named_ctx($i->args->{name});
				} else {
					$class->set_context($new_ctx);
					$class->handle_template_tree($i,$_[0]);
					$class->set_context($ctx);
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
	my $class = shift;
	my $i = shift;

	my $level = $i->args->{level} || $i->args->{DEFAULT};

	my ($inv) = $level =~ s/^(!)//;

	# if we don't have a user, we can't have any rights
	if (!$class->{_}->switchboard->knows("user")) {
		# if normal, return 0... if inv return 1
		return ($inv) ? 1 : 0;
	}

	if ($class->{_}->user->has_rights($level)) {
		# if normal, return 1... if inv return 0
		return ($inv) ? 0 : 1;
	} else {
		# if normal, return 0... if inv return 1
		return ($inv) ? 1 : 0;
	}
}

#----------

sub handle_raw {
	my $class = shift;
	my $i = shift;
	
	$_[0] .= $i->content;

	return undef;
}

#----------

sub handle_link {
	my $class = shift;
	my $i = shift;

	my $template = $i->args->{template} || $i->args->{DEFAULT};

	if (!$template) {
		$class->handle_template_tree($i,$template);
	}

	# make a copy of the args
	my $args = {};
	%$args = %{$i->args};

	foreach my $c (@{$i->children}) {
		$class->handle_link_qopt($c,$args);
	}

	$_[0] .= $class->{_}->queryopts->link($template,$args);

	return undef;
}

#----------

sub handle_link_qopt {
	my $class = shift;
	my $i = shift;
	my $opts = shift;

	# only handle qopts
	return 0 if ($i->type ne "qopt"); 

	# make sure we've got an opts hash to throw into
	return 0 if (ref($opts) ne "HASH");

	my $name = $i->args->{name} || $i->args->{DEFAULT};
	return 0 if (!$name);

	#warn "handle link qopt $name\n";

	my $v;
	$class->{_}->gholders->handle_template_tree($i,$v);
	#warn "value: $v\n";

	$opts->{$name} = $v;
}

#----------

sub handle_context {
	my $class = shift;
	my $i = shift;

	my $uctx = $i->args->{context} || $i->args->{DEFAULT};

	return undef if (!$uctx);

	if (my $gh = $class->exists($uctx)) {
		if ($i->args->{name}) {
			$class->new_named_ctx($i->args->{name},$gh);
			$class->handle_template_tree($i,$_[0]);
			$class->remove_named_ctx($i->args->{name});
		} else {
			my $ctx = $class->get_context;
			$class->set_context($gh);
			$class->handle_template_tree($i,$_[0]);
			$class->set_context($ctx);
		}

		return undef;
	} else {
		return undef;
	}
}

#----------

sub handle_template {
	my $class = shift;
	my $i = shift;

	my $name = $i->args->{template} || $i->args->{DEFAULT};

	my $tmplt = $class->{_}->instance->new_object(
		"Template::Subtemplate",
		path=>$name
	);

	if ($tmplt->load_from_sub) {
		return $class->{_}->gholders->handle_template_tree(
			$tmplt->get_tree,$_[0]
		);
	} else {
		return undef;
	}
}

#----------

sub handle_unknown {
	my $class = shift;
	my $i = shift;

	$_[0] .= $class->_handle_unknown($i);

	return undef;
}

sub _handle_unknown {
	my $class = shift;
	my $i = shift;

	my $ret;

	if ($i->type eq "raw") {
		$ret .= $i->content;
	} else {
		# start with the tag
		$ret .= "{" . $i->type . " ";
	
		# add our arguments
		my @args;
		while ( my ($k,$v) = each %{ $i->args } ) {
			next if (!$k);
			push @args, qq($k=>"$v");
		}
		$ret .= join(",",@args) . " ";

		# opening tag or single?  single if no children
		if (!@{ $i->children }) {
			$ret .= "/}";
		} else {
			$ret .= "}";
			foreach my $c (@{ $i->children }) {
				$ret .= $class->_handle_unknown($c);
			}
			$ret .= "{/" . $i->type . "}";
		}
	}

	return $ret;
}

#----------

sub handle {
	my $class = shift;
	my $i = shift;

	# call the handler for this tag
	if ( my $ref = $class->exists( $i->type ) ) {
		if ($ref->sub) {
			return $ref->sub->($i,$_[0]);
		} else {
			my ($ltype) = $i->type =~ m!^.*\.([^\.]+)$!;
			# check for a top-level handler
			if ( my $href = $class->exists( "/".$ltype ) ) {
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
		return $class->handle_unknown($i,$_[0]);
	}
}

#----------

sub handle_template_tree {
	my $class = shift;
	my $tree = shift;

	foreach my $i ( @{ $tree->children } ) {
		if ($class->handle($i,$_[0])) {
			$class->handle_template_tree($i,$_[0]);
		}
	}

	return 1;
}

#----------

sub sever_template_items {
	my ($class,$i) = @_;

	foreach my $c (@{$i->children}) {
		$class->_sever_template_items($c);
	}

	$i->sever_relationships;

	return 1;
}

sub _sever_template_items {
	my ($class,$i) = @_;

	foreach my $c ( @{ $i->children } ) {
		$class->_sever_template_items($c);
	}

	$i->sever_relationships;

	return 1;
}

#----------

1;
