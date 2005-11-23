package eThreads::Object::Template;

use strict;

use Scalar::Util;

use Spiffy -Base, -XXX;

use eThreads::Object::Template::Item;
use eThreads::Object::Template::Qopts;
use eThreads::Object::Template::ShadowItem;
use eThreads::Object::Template::Subtemplate;
use eThreads::Object::Template::Walker;
use eThreads::Object::Template::Writable;

sub TABLE { "templates" }

#----------

field '_'		=> -ro;

field 'look' 	=> -ro;
field 'id' 		=> -ro;
field 'path'	=> -ro;
field 'value'	=> -ro,-init=>q! $self->load_raw !;;
field 'type'	=> 
	-ro, 
	-key=>'type_obj',
	-init=>q!$self->_->new_object('ContentType::'.$self->{type})->activate!;

field 'qopts'	=> 
	-ro,
	-init=>q! 
		if (my $q = $self->_->cache->get(tbl=>'qopts',first=>$self->id)) {
			$self->_->new_object('Template::Qopts')->restore($q)
		} else {
			$self->cache_qopts 
		}
	!;

# can't write on this object
stub 'write';

field 'writable'	=> 
	-ro, 
	-init=>q! bless { %$self } , 'eThreads::Object::Template::Writable'; !;

#----------

sub new {
	my $data = shift;

	$self =  bless ( {
		_		=> $data,
		id		=> undef,
		path	=> undef,
		tree	=> undef,
		type	=> undef,
		look	=> undef,
		@_,

	} , $self );

	return $self;
}

#----------

sub DESTROY {
	# nothing right now
}

#----------

sub cachable {
	return {
		path	=> $self->path,
		id		=> $self->id,
		value	=> $self->value,
		type	=> $self->{type},
		#qopts	=> $self->qopts,
	};
}

#----------

sub qkeys {
	if ($self->{qkeys}) {
		return $self->{qkeys};
	}

	my $q = $self->_->cache->get(
		tbl		=> "qkeys",
		first	=> $self->id,
	);

	if (!$q) {
		$q = $self->cache_qkeys;
	}

	$self->{qkeys} = $q;

	return $self->{qkeys};
}

#----------

sub cache_qopts {
	# we need to look through the template to find what functions are inside.
	# we then need to know what qopts those functions define so that we can 
	# assemble a master list of qopts.  once we have that we call named_qopts 
	# to get the qopts whose names have been changed.  We merge those new 
	# names into the list. we'll end up returning a Template::Qopts object.

	my $qopts = $self->_->new_object('Template::Qopts');

	my $all = $self->list_available_qopts;

	foreach my $q ( @$all ) {
		$qopts->register( %$q );
	}

	# now merge in the named qopts

	my $named = $self->named_qopts;

	while ( my ($g,$gref) = each %$named ) {
		while ( my ($f,$fref) = each %$gref ) {
			while ( my ($o,$oref) = each %$fref ) {
				if (!$qopts->glomule($g)->{$f}{$o}) {
					warn "ERROR: named qopt not in all -- $g - $f - $o\n";
					next;
				}

				$qopts->glomule($g)->{$f}{$o}->name( $oref->{name} );
			}
		}
	}

	$self->_->cache->set(
		tbl		=> "qopts",
		first	=> $self->id,
		ref		=> $qopts->dump
	);

	return $qopts;
}

#----------

sub named_qopts {
	# -- if we've already got them, return now -- #

	if ($self->{nqopts}) {
		return $self->{nqopts};
	}

	# -- otherwise we need to load them -- #

	my $get = $self->_->core->get_dbh->prepare("
		select
			glomule,
			function,
			opt,
			name
		from 
			" . $self->_->core->tbl_name("qopts") . "
		where 
			template = ?
	");

	$get->execute( $self->id ) or
		$self->_->bail->("cache_qopts failure: ".$get->errstr);

	my ($g,$f,$o,$n);
	$get->bind_columns( \($g,$f,$o,$n) );

	my $qopts = {};
	while ($get->fetch) {
		$qopts->{ $g }{ $f }{ $o } = {
			glomule		=> $g,
			function	=> $f,
			opt			=> $o,
			name		=> $n,
		};
	}

	$self->{nqopts} = $qopts;

	return $qopts;
}

#----------

sub cache_qkeys {
	my $db = $self->_->core->get_dbh;

	my $get = $db->prepare("
		select
			name
		from 
			" . $self->_->core->tbl_name("qkeys") . "
		where 
			template = ?
		order by 
			position
	");

	$get->execute( $self->id ) or
		$self->_->bail->("cache_qkeys failure: ".$db->errstr);

	my ($n);
	$get->bind_columns( \($n) );

	my $qkeys = [];
	while ($get->fetch) {
		push @$qkeys, $n;
	}

	$self->_->cache->set(
		tbl		=> "qkeys",
		first	=> $self->id,
		ref		=> $qkeys
	);

	return $qkeys;
}

#----------

sub list_available_qopts {
	# ok, step one is to create a template walker and register glomule 
	# handlers so that we can step through and see what we're dealing 
	# with here.  each function we walk will append its qopts to the 
	# $qopts array.  we'll return these to our caller.  each element 
	# of this array will be a hash containing the glomule id and a ref 
	# to the array of Controller::Function::Qopt objects, which 
	# is of the standard Generic::Qopt form.

	my $qopts = [];

	if ($self->look->is_admin) {
		# we're the template of an admin look, so we're not going to have 
		# a normal function inside.  Our function is our template name.

		my ($name) = $self->path =~ m!^/(.*)!;

		my $func = $self->_->controller->get('admin')->has_function( $name );

		if ($func) {
			my $gqopts = {
				glomule		=> 'ADMIN',
				gtype		=> 'admin',
				function	=> $func->name,
				opts		=> scalar $func->qopts
			};

			push @$qopts, $gqopts;
		} else {
			# this shouldn't happen, but there's always the possibility of 
			# a bad setup
			$self->_->bail->(
				"Admin template doesn't have matching function: " . $name
			);
		}

		return $qopts;
	}

	# -- now walk non-admin templates -- #

	my $walker = $self->_->new_object("Template::Walker");

	foreach my $t (keys %{$self->_->settings->{glomule_types}}) {
		# -- register the walker -- #
		$walker->register(
			[ $t , sub { return $self->_walk_glomule($t,$qopts,@_); } ]
		);
	}

	$walker->walk_template_tree(
		$self->get_tree
	);

	return $qopts;
	
}

#----------

sub _walk_glomule {
	my $type = shift;
	my $qopts = shift;
	my $i = shift;

	my $glomule = $i->args->{name} || $i->args->{glomule};

	my $gc = $self->_->controller->get($type);

	if ( my $func = $gc->has_function( $i->args->{function} ) ) {
		# $func->qopts will give us an array ref that points to the qopts 
		# definition in the controller.  we append the contents of this 
		# array to the $qopts arrayref that was passed in to us

		my $id = $self->_->container->glomule_n2id( $glomule );

		my $gqopts = {
			glomule		=> scalar $self->_->container->glomule_n2id($glomule),
			function	=> $func->name,
			gtype		=> $type,
			opts		=> scalar $func->qopts
		};

		push @$qopts, $gqopts;
	} else {
		$self->_->bail->(
			"Unknown glomule function: "
			. $glomule
			. "/"
			. $i->args->{function}
		);
	}

	return 1;
}

#----------

sub shadow_tree {
	eThreads::Object::Template::ShadowItem->new(
		item => $self->get_tree
	);
}

#----------

sub get_tree {
	if ($self->{tree}) {
		return $self->{tree};
	}

	# try cache

	my $deep = $self->_->cache->get(
		tbl			=> $self->TABLE,
		first		=> $self->look->id,
		second		=> $self->id,
		nomemcache	=> 1,
	);

	my $tree;
	if ($deep) {
		# restore to Template::Item objects
		$tree = $self->_restore_tree($deep);
	} else {
		$tree = $self->cache_tree;
	}

	$self->{tree} = $tree;

	return $self->{tree};
}

#-----------

sub _restore_tree {
	my ($i,$p) = @_;
	my $children = $i->{children};
	undef $i->{children};
	$i = CORE::bless $i , 'eThreads::Object::Template::Item';

	if ( $children ) {
		foreach my $c ( @$children ) {
			$i->children->push(
				$self->_restore_tree( $c , $i )
			);
		}
	}
	$i->{parent} = $p;
	Scalar::Util::weaken($i->{parent});
	return $i;
}

#----------

sub load_raw {
	# get the raw template from the db
	my $get = $self->_->core->get_dbh->prepare("
		select 
			value 
		from 
			" . $self->_->core->tbl_name($self->TABLE) . "
		where id = ?
	");

	$get->execute( $self->id )
		or $self->_->bail->("Couldn't get raw template: " . $get->errstr);

	$self->_->bail->("No raw template found for template ".$self->id)
		if (!$get->rows);

	my $v = $get->fetchrow_array;

	return $v;
}

#----------

sub cache_tree {
	my $v = $self->load_raw;

	my $tree = $self->new_tree_root;

	$self->parse_into_tree( $tree , $v );

	# create deep structure to cache
	my $deep = $tree->dump_deep;

	$self->_->cache->set(
		tbl			=> $self->TABLE,
		first		=> $self->look->id,
		second		=> $self->id,
		ref			=> $deep,
		nomemcache	=> 1,
	);

	return $tree;
}

#-----------

sub new_tree_root {
	$self->_->new_object("Template::Item");
}

#-----------

sub parse_into_tree {
	my ($t,$content) = @_;

	# this is our main parsing regex.  It returns six items.
	# 0 - preceding slash...  if present can indicate closing tag 
	#     or a rooted placeholder name
	# 1 - the placeholder name.  It must begin and end with a word 
	#     character, and in between can contain word characters or 
	#     spaces
	# 2 - args if given with quotes
	# 3 - args if given without quotes
	# 4 - trailing slash.  if present, indicates a single tag
	# 5 - raw content (will be the only thing present if it matches)

	my @f = $content =~
		m!\G
			(?:
				{
				(/?)
				(
					[\$\w]
					[\w\.]*
					\w
				)
				(?:
					\s+
					(?:
						"([^"]+)"
					|
						([^}]+)\s+
					)
				)?
				\s*
				(/?)
				}
			| 
				(.*?)(?:(?={[\w\$/])|$)
			)
		!gisx;

	# if the content contains no placeholders, we make the entire 
	# thing a raw and return it.
	if (!@f) {
		# the whole thing is a raw
		my $r = $self->_->new_object("Template::Item");

		$r->type( 		"raw"		);
		$r->parent( 	$t			);
		$r->content( 	$content	);

		$t->children->push($r);
	}

	# figure out how many items are in our matched list
	my $l = @f;

	# make our context the root
	my $cx = $t;

	# six items in each match, so divide the match list up accordingly
	for (my $i = 0;$i <= $l;$i+=6) {
		my @m = splice(@f,0,6);
		if ($m[0] && !$m[4]) {
			# closing tag

			# there should be a check to make sure we're closing the 
			# open tag here.  right now we don't care
			$cx = $cx->{parent} if ($cx->{parent});
		} elsif ($m[1]) {
			# opening tag or single

			my $args = {};
			if (!$m[2] && !$m[3]) {
				# do nothing
			} elsif ($m[2]) {
				$args->{DEFAULT} = $m[2];
			} else {
				my @ma = $m[3] =~ m!(\w+)\s*=>\s*("[^"]*"|[^,]+)!g;

				while (@ma) {
					my @a = splice(@ma,0,2);
					next if (!$a[0]);
					$a[1] =~ s/(?:^"|"$)//g;
					$args->{$a[0]} = $a[1];
				}
			}

			my $lt = $self->_->new_object('Template::Item');

			$lt->type(		lc($m[1])	);
			$lt->args(		$args		);
			$lt->parent(	$cx			);

			$cx->children->push($lt);

			# if this is an opening tag (not a single), make it the 
			# current context.  otherwise context is unchanged.
			if ($m[4] && $m[0]) {
				# rooted single tag
				$lt->{type} = '/'.$lt->{type};
			} elsif (!$m[4]) {
				# opening tag
				$cx = $lt;
			} else {
				# do nothing
			}
		} else {
			# raw match

			# matched nothing?
			next if (!$m[5]);

			# if we matched only whitespace, just replace with a single space
			$m[5] =~ s/^\s+$/ /;
		
			my $lt = $self->_->new_object('Template::Item');

			$lt->type(		'raw'	);
			$lt->parent(	$cx		);
			$lt->content(	$m[5]	);	

			$cx->children->push($lt);
		}
	}

	return 1;
}

#----------

1;
