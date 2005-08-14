package eThreads::Object::Template;

use strict;

use eThreads::Object::Template::Item;
use eThreads::Object::Template::Qopts;
use eThreads::Object::Template::ShadowItem;
use eThreads::Object::Template::Subtemplate;
use eThreads::Object::Template::Walker;

sub TABLE { "templates" }

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class =  bless ( {
		_		=> $data,
		id		=> undef,
		path	=> undef,
		tree	=> undef,
		type	=> undef,
		look	=> undef,
		@_,

	} , $class );

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub cachable {
	my $class = shift;

	return {
		path	=> $class->path,
		id		=> $class->id,
		value	=> $class->value,
		type	=> $class->{type},
		#qopts	=> $class->qopts,
	};
}

#----------

sub look 	{ shift->{look}	}
sub id 		{ shift->{id} 	}
sub path 	{ shift->{path}	}

#----------

sub type {
	my $class = shift;

	return 
		$class->{type_obj}
		|| ($class->{type_obj} 
			= $class->{_}->new_object( 
				'ContentType::' . $class->{type}
			)->activate);
}

#----------

sub value {
	return shift->{value};
}

#----------

sub qkeys {
	my $class = shift;

	if ($class->{qkeys}) {
		return $class->{qkeys};
	}

	my $q = $class->{_}->cache->get(
		tbl		=> "qkeys",
		first	=> $class->id,
	);

	if (!$q) {
		$q = $class->cache_qkeys;
	}

	$class->{qkeys} = $q;

	return $class->{qkeys};
}

#----------

sub qopts {
	my $class = shift;

	if ($class->{nqopts}) {
		return $class->{nqopts};
	}

	# we need to look through the template to find what functions are inside.
	# we then need to know what qopts those functions define so that we can 
	# assemble a master list of qopts.  once we have that we call named_qopts 
	# to get the qopts whose names have been changed.  We merge those new 
	# names into the list. we'll end up returning a Template::Qopts object.

	my $qopts = $class->{_}->new_object('Template::Qopts');

	my $all = $class->list_available_qopts;

	foreach my $q ( @$all ) {
		$qopts->register( %$q );
	}

	# now merge in the named qopts

	my $named = $class->named_qopts;

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

	$class->{nqopts} = $qopts;

	return $qopts;
}

#----------

sub named_qopts {
	my $class = shift;

	# -- if we've already got them, return now -- #

	if ($class->{qopts}) {
		return $class->{qopts};
	}

	# -- otherwise we need to load them -- #

	my $q = $class->{_}->cache->get(
		tbl		=> "qopts",
		first	=> $class->id,
	);

	if (!$q) {
		$q = $class->cache_qopts;
	}

	$class->{qopts} = $q;

	return $q;
}

#----------

sub cache_qkeys {
	my $class = shift;

	my $db = $class->{_}->core->get_dbh;

	my $get = $db->prepare("
		select
			name
		from 
			" . $class->{_}->core->tbl_name("qkeys") . "
		where 
			template = ?
		order by 
			position
	");

	$get->execute( $class->id ) or
		$class->{_}->bail->("cache_qkeys failure: ".$db->errstr);

	my ($n);
	$get->bind_columns( \($n) );

	my $qkeys = [];
	while ($get->fetch) {
		push @$qkeys, $n;
	}

	$class->{_}->cache->set(
		tbl		=> "qkeys",
		first	=> $class->id,
		ref		=> $qkeys
	);

	return $qkeys;
}

#----------

sub cache_qopts {
	my $class = shift;

	# start with the values that are in the database

	my $get = $class->{_}->core->get_dbh->prepare("
		select
			glomule,
			function,
			opt,
			name
		from 
			" . $class->{_}->core->tbl_name("qopts") . "
		where 
			template = ?
	");

	$get->execute( $class->id ) or
		$class->{_}->bail->("cache_qopts failure: ".$get->errstr);

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

	$class->{_}->cache->set(
		tbl		=> "qopts",
		first	=> $class->id,
		ref		=> $qopts
	);

	return $qopts;
}

#----------

sub list_available_qopts {
	my $class = shift;

	# ok, step one is to create a template walker and register glomule 
	# handlers so that we can step through and see what we're dealing 
	# with here.  each function we walk will append its qopts to the 
	# $qopts array.  we'll return these to our caller.  each element 
	# of this array will be a hash containing the glomule id and a ref 
	# to the array of Controller::Function::Qopt objects, which 
	# is of the standard Generic::Qopt form.

	my $walker = $class->{_}->new_object("Template::Walker");

	my $qopts = [];

	foreach my $t (keys %{$class->{_}->settings->{glomule_types}}) {
		# -- register the walker -- #
		$walker->register(
			[ $t , sub { return $class->_walk_glomule($t,$qopts,@_); } ]
		);
	}

	$walker->walk_template_tree(
		$class->get_tree
	);

	return $qopts;
	
}

#----------

sub _walk_glomule {
	my $class = shift;
	my $type = shift;
	my $qopts = shift;
	my $i = shift;

	my $glomule = $i->args->{name} || $i->args->{glomule};

	my $gc = $class->{_}->controller->get($type);

	if ( my $func = $gc->has_function( $i->args->{function} ) ) {
		# $func->qopts will give us an array ref that points to the qopts 
		# definition in the controller.  we append the contents of this 
		# array to the $qopts arrayref that was passed in to us

		my $gqopts = {
			glomule		=> scalar $class->{_}->glomule->name2id( $glomule ),
			function	=> $func->name,
			opts		=> scalar $func->qopts
		};

		push @$qopts, $gqopts;
	} else {
		$class->{_}->bail->(
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
	my $class = shift;

	return $class->{_}->switchboard->new_object(
		'Template::ShadowItem',
		item => $class->get_tree
	);
}

#----------

sub get_tree {
	my $class = shift;

	if ($class->{tree}) {
		return $class->{tree};
	}

	# try cache

	my $deep = $class->{_}->cache->get(
		tbl			=> $class->TABLE,
		first		=> $class->look->id,
		second		=> $class->id,
		nomemcache	=> 1
	);

	my $tree;
	if ($deep) {
		# restore to Template::Item objects
		$tree = $class->_restore_tree($deep);
	} else {
		$tree = $class->cache_tree;
	}

	$class->{tree} = $tree;

	return $class->{tree};
}

#-----------

sub _restore_tree {
	my ($class,$i) = @_;
	@{$i->{children}} = map { $class->_restore_tree($_) } @{$i->{children}};
	CORE::bless $i , 'eThreads::Object::Template::Item';
}

#-----------

sub cache_tree {
	my $class = shift;

	# get the raw template from the db
	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			value 
		from 
			" . $class->{_}->core->tbl_name($class->TABLE) . "
		where id = ?
	");

	$get->execute( $class->id )
		or $class->{_}->bail->("Couldn't get raw template: " . $get->errstr);

	$class->{_}->bail->("No raw template found for template ".$class->id)
		if (!$get->rows);

	my $v = $get->fetchrow_array;

	my $tree = $class->new_tree_root;

	$class->parse_into_tree( $tree , $v );

	# create deep structure to cache
	my $deep = $tree->dump_deep;

	$class->{_}->cache->set(
		tbl			=> $class->TABLE,
		first		=> $class->look->id,
		second		=> $class->id,
		ref			=> $deep,
		nomemcache	=> 1
	);

	return $tree;
}

#-----------

sub new_tree_root {
	my $class = shift;
	return $class->{_}->new_object("Template::Item");
}

#-----------

sub parse_into_tree {
	my ($class,$t,$content) = @_;

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
		my $r = $class->{_}->new_object("Template::Item");

		$r->type( 		"raw"		);
		$r->parent( 	$t			);
		$r->content( 	$content	);

		$t->add_child($r);
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

			my $lt = $class->{_}->new_object('Template::Item');

			$lt->type(		lc($m[1])	);
			$lt->args(		$args		);
			$lt->parent(	$cx			);

			$cx->add_child($lt);

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
		
			my $lt = $class->{_}->new_object('Template::Item');

			$lt->type(		'raw'	);
			$lt->parent(	$cx		);
			$lt->content(	$m[5]	);	

			$cx->add_child($lt);
		}
	}

	return 1;
}

#----------

1;
