package eThreads::Object::Template;

use strict;

sub new {
	my $class = shift;
	my $data = shift;

	$class =  bless ( {
		_		=> $data,
		id		=> undef,
		path	=> undef,
		tree	=> undef,
		value	=> undef,
		type	=> undef,

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

sub id {
	return shift->{id};
}

#----------

sub path {
	return shift->{path};
}

#----------

sub type {
	my $class = shift;

	if (!$class->{type_obj}) {
		$class->{type_obj} 
			= $class->{_}->instance->new_object( 
				"ContentType::" . $class->{type}
			);

		$class->{_}->objects->activate($class->{type_obj});
	}

	return $class->{type_obj};
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
		$class->{_}->core->bail("cache_qkeys failure: ".$db->errstr);

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

	my $db = $class->{_}->core->get_dbh;

	my $get = $db->prepare("
		select
			glomule,
			opt,
			name
		from 
			" . $class->{_}->core->tbl_name("qopts") . "
		where 
			template = ?
	");

	$get->execute( $class->id ) or
		$class->{_}->core->bail("cache_qopts failure: ".$db->errstr);

	my ($g,$o,$n);
	$get->bind_columns( \($g,$o,$n) );

	my $qopts = {};
	while ($get->fetch) {
		$qopts->{ $g }{ $o } = {
			glomule		=> $g,
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

sub get_tree {
	my $class = shift;

	if ($class->{tree}) {
		return $class->{tree};
	} else {
		return $class->generate_tree;
	}
}

#-----------

sub generate_tree {
	my $class = shift;

	$class->{tree} = $class->new_tree_root;

	$class->parse_into_tree($class->{tree},$class->{value});

	return $class->{tree};
}

#-----------

sub new_tree_root {
	my $class = shift;
	return $class->{_}->instance->new_object("Template::Item");
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
		my $r = $class->{_}->instance->new_object("Template::Item");

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

			my $lt = $class->{_}->instance->new_object("Template::Item");

			$lt->type(		lc($m[1])	);
			$lt->args(		$args		);
			$lt->parent(	$cx			);

			$cx->add_child($lt);

			# if this is an opening tag (not a single), make it the 
			# current context.  otherwise context is unchanged.
			if ($m[4] && $m[0]) {
				# rooted single tag
				$lt->{type} = "/".$lt->{type};
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
		
			my $lt = $class->{_}->instance->new_object("Template::Item");

			$lt->type(		"raw"	);
			$lt->parent(	$cx		);
			$lt->content(	$m[5]	);	

			$cx->add_child($lt);
		}
	}

	return 1;
}

#----------

1;
