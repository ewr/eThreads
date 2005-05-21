package eThreads::Object::Glomule::Type::Comments;

@ISA = qw( eThreads::Object::Glomule::Type );

use strict;

#----------

sub TYPE { "comments" }

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub activate {
	my $class = shift;

	return $class;
}

#----------

sub f_view {
	my $class = shift;
	my $fobj = shift;

	my $id = $fobj->bucket->get("id");

	my $posts = $class->posts_by_parent($fobj,$id);

	my $format = $fobj->glomule->system('format');

	my $comments = [];
	my @data;

	if ($posts) {
		foreach my $p (@{ $posts->posts }) {
			$class->{_}->last_modified->nominate($p->{timestamp});
			foreach my $f (@{ $class->fields }) {
				if ($format && $f->{format}) {
					$p->{ $f->{name} } 
						= $format->format( $p->{ $f->{name} } );
				} else {
					# do nothing
				}
			}

			push @$comments, $p->{id};
			push @data, ['comments.'.$p->{id} , $p ];
		}

		$fobj->gholders->register(
			['count' , $posts->count],
			@data
		);
	}

	# create a blank compose hash
	my $compose = {};
	%$compose = map { $_->{name} => "" } @{ $class->edit_fields };

	$fobj->gholders->register(
		['comments' , $comments ],
		['compose', $compose ]
	);


	return 1;
}

#----------

sub f_post {
	my $class = shift;
	my $fobj = shift;

	my $id = $fobj->bucket->get("id");

	my $post = {};
	foreach my $f ('title','name','url','email','comment') {
		my $v = $fobj->bucket->get($f);
		$post->{ $f } = $v;
	}

	if ( $fobj->bucket->get("preview") ) {
		# -- register a timestamp handler -- #
		$class->{_}->gholders->register(
			["timestamp" , sub { $class->handle_timestamp($fobj,@_); }]
		);

		# parse and register some preview gholders
		my $format = ( $class->{_}->switchboard->knows("format") ) ? 1 : undef;
		my $c = {};
		foreach my $f (@{ $class->edit_fields }) {
			if ($format && $f->{format}) {
				$c->{ $f->{name} } 
					= $class->{_}->format->format($post->{$f->{name}});
			} else {
				$c->{ $f->{name} } = $post->{ $f->{name} };
			}
		}

		$c->{parent} = $id;

		my ($ok,$msg) = $class->flesh_out_post($c);

		if (!$ok) {
			$fobj->gholders->register(["message",$msg]);
		}

		$fobj->gholders->register(
			['preview',1],
			['preview',$c]
		);

		# now register the raw values into compose
	
		$fobj->gholders->register(['compose',$post]);
	} elsif ( $fobj->bucket->get("post") ) {
		$fobj->gholders->register(["post",1]);
		# flesh out the post
		$post->{parent} = $id;
		my ($ok,$msg) = $class->flesh_out_post($post);

		if ($ok) {
			# we can go ahead and post
			$class->post($post);
			$fobj->gholders->register(['comment',$post]);
		} else {
			# doh...  error.  
			$fobj->gholders->register(["message",$msg]);
			$fobj->gholders->register(['compose',$post]);
		}
	}
}

#----------

sub f_mass_delete {
	my $class = shift;
	my $fobj = shift;

	my $start	= $fobj->bucket->get("start") || '0';
	my $limit	= $fobj->bucket->get("limit") || $fobj->glomule->pref("limit")->get;
	my $delete	= $fobj->bucket->get("delete");
	my $confirm	= $fobj->bucket->get("confirm");

	my $format = ( $class->{_}->switchboard->knows("format") ) ? 1 : undef;

	# -- if we have posts to delete, get them -- #

	if ($delete) {
		my $d = $class->get_by_id($fobj, split(',',$delete) );

		my @data;
		foreach my $c ( @{ $d->posts } ) {
			foreach my $f (@{ $class->fields }) {
				if ($format && $f->{format}) {
					$c->{ $f->{name} } 
						= $class->{_}->format->format( $c->{ $f->{name} } );
				} else {
					# do nothing
				}
			}

			push @data, ['delete.'.$c->{id} , $c ];
		}

		$fobj->gholders->register(
			['delete', [ map { $_->{id} } @{$d->posts} ] ],
			@data
		);
	} else {
		# -- load information for the last $count comments -- #

		my $comments = $class->posts_by_time($fobj,$start,$limit);

		my @data;
		foreach my $c ( @{ $comments->posts } ) {
			#$class->{_}->last_modified->nominate($p->{timestamp});
			foreach my $f (@{ $class->fields }) {
				if ($format && $f->{format}) {
					$c->{ $f->{name} } 
						= $class->{_}->format->format( $c->{ $f->{name} } );
				} else {
					# do nothing
				}
			}

			push @data, ['comments.'.$c->{id} , $c ];
		}

		$fobj->gholders->register(
			['count',$comments->count],
			['comments', [ map { $_->{id} } @{$comments->posts} ] ],
			@data
		);
	}
}

#----------

sub f_delete {
	my $class = shift;
	my $fobj = shift;

	# -- register a timestamp handler -- #
	$class->{_}->gholders->register(
		["timestamp" , sub { $class->handle_timestamp($fobj,@_); }]
	);

	my $id 		= $fobj->bucket->get("id");
	my $confirm	= $fobj->bucket->get("confirm");

	# -- load post information -- #

	my $c = $class->get_by_id($fobj,$id)->{$id};

	my $format = ( $class->{_}->switchboard->knows("format") ) ? 1 : undef;

	foreach my $f (@{ $class->fields }) {
		if ($format && $f->{format}) {
			$c->{ $f->{name} } 
				= $class->{_}->format->format( $c->{ $f->{name} } );
		} else {
			# do nothing
		}
	}

	$class->{gholders}->register(
		['comment',$c]
	);

	# -- now figure an action -- #

	if ($confirm) {
		$class->{_}->gholders->register(['confirm',1]);
		# they said to go ahead
		$class->delete($id);
	}
}
#----------

sub handle_timestamp {
	my $class = shift;
	my $fobj = shift;
	my $i = shift;
	my $c = shift;

	my $a = 
		$i->args->{format} 
		|| $i->args->{DEFAULT} 
		|| $fobj->glomule->pref("datetime_format")->get;

	$_[0] .= Date::Format::time2str($a,$c);
	return 0;
}

#----------

sub get_by_id {
	my $class = shift;
	my $fobj = shift;

	my $results = $class->get_from_glomheaders($fobj,
		'id in (' . join('?',map{'?'} @_) .')',
		@_
	);

	my $posts = {};
	%$posts = map { $_->{id} => $_ } @$results; 
	
	# -- now get post data -- #

	my $data = $class->{_}->utils->g_load_tbl(
		tbl		=> $fobj->glomule->data('data'),
		ident	=> "id",
		ids		=> \@_,
	);

	while ( my ($id,$d) = each %$data ) {
		while ( my ($k,$v) = each %$d ) {
			$posts->{$id}{$k} = $v if (!$posts->{$id}{$k});
		}
	}

	return $posts;
}

#----------

sub posts_by_time {
	my $class = shift;
	my $fobj = shift;
	my $start = shift;
	my $limit = shift;

	my $where = 
		qq(
			(1 = 1)
			order by timestamp desc
		);

	return $class->posts_generic_w_limit($fobj,$where,$start,$limit);
}

#----------

sub posts_by_parent {
	my $class = shift;
	my $fobj = shift;
	my $parent = shift;

	# -- what ids do we want? -- #

	my $where = 
		qq(
			parent = ? 
			order by 
			timestamp
		);

	return $class->posts_generic($fobj,$where,$parent);
}

#----------

sub fields {
	my $class = shift;

	return [
		{
			name	=> "name",
			require	=> 1,
			edit	=> 1,
		},
		{
			name	=> "email",
			edit	=> 1,
		},
		{
			name	=> "url",
			edit	=> 1,
		},
		{
			name	=> "comment",
			format	=> 1,
			require	=> 1,
			edit	=> 1,
		},
		{
			name	=> "ip",
			d_value	=> $ENV{REMOTE_ADDR},
		},
	];
}

sub header_fields {
	my $class = shift;

	return [

	{ KEYS => [
		'primary key(id)'
	] },
	{
		name	=> "id",
		def		=> "int(11) not null auto_increment",
		allowed	=> '\d+',
		d_value	=> 0,
	},
	{
		name	=> "title",
		def		=> "varchar(100)",
		allowed	=> '.*',
		edit	=> 1,
	},
	{
		name	=> "parent",
		def		=> "varchar(20) not null",
		allowed	=> '\d+',
		d_value	=> 0,
	},
	{
		name	=> "timestamp",
		def		=> "int(11) not null",
		allowed	=> '\d+',
		d_value	=> time,
	},
	{
		name	=> "user",
		def		=> "int(11)",
		allowed	=> '\d+',
		d_value	=> 
			$class->{_}->switchboard->knows("user") 
				? $class->{_}->user->id
				: 0,
		require	=> 0,
	},
	{
		name	=> "status",
		def		=> "tinyint not null",
		allowed	=> '\d+',
		d_value	=> 0,
	},

	];
}

#----------

1;

