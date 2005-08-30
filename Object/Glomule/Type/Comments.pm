package eThreads::Object::Glomule::Type::Comments;

use eThreads::Object::Glomule::Type -Base;

use strict;

#----------

const 'TYPE'	=> 'comments';

#----------

sub new {
	my $data = shift;

	$self = bless ( {
		_		=> $data,
	} , $self ); 

	return $self;
}

#----------

sub activate {
	return $self;
}

#----------

sub f_view {
	my $fobj = shift;

	my $id = $fobj->bucket->get("id");

	my $posts = $self->posts_by_parent($fobj,$id);

	my $format = $fobj->glomule->system('format');

	my $comments = [];
	my @data;

	if ($posts) {
		foreach my $p (@{ $posts->posts }) {
			$self->_->last_modified->nominate($p->{timestamp});
			foreach my $f (@{ $self->fields }) {
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
	%$compose = map { $_->{name} => "" } @{ $self->edit_fields };

	$fobj->gholders->register(
		['comments' , $comments ],
		['compose', $compose ]
	);


	return 1;
}

#----------

sub f_post {
	my $fobj = shift;

	my $id = $fobj->bucket->get("id");

	my $post = {};
	foreach my $f ('title','name','url','email','comment') {
		my $v = $fobj->bucket->get($f);
		$post->{ $f } = $v;
	}

	if ( $fobj->bucket->get("preview") ) {
		# -- register a timestamp handler -- #
		$self->_->gholders->register(
			["timestamp" , sub { $self->handle_timestamp($fobj,@_); }]
		);

		# parse and register some preview gholders
		my $format = $fobj->glomule->system('format');
		my $c = {};
		foreach my $f (@{ $self->edit_fields }) {
			if ($format && $f->{format}) {
				$c->{ $f->{name} } 
					= $format->format($post->{$f->{name}});
			} else {
				$c->{ $f->{name} } = $post->{ $f->{name} };
			}
		}

		$c->{parent} = $id;

		my ($ok,$msg) = $self->flesh_out_post($c);

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
		my ($ok,$msg) = $self->flesh_out_post($post);

		if ($ok) {
			# we can go ahead and post
			$self->post($fobj,$post);
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
	my $fobj = shift;

	my $start	= $fobj->bucket->get("start") || '0';
	my $limit	= $fobj->bucket->get("limit") || $fobj->glomule->pref("limit")->get;
	my $delete	= $fobj->bucket->get("delete");
	my $confirm	= $fobj->bucket->get("confirm");

	my $format = ( $self->_->switchboard->knows("format") ) ? 1 : undef;

	# -- if we have posts to delete, get them -- #

	if ($delete) {
		my $d = $self->get_by_id($fobj, split(',',$delete) );

		my @data;
		foreach my $c ( @{ $d->posts } ) {
			foreach my $f (@{ $self->fields }) {
				if ($format && $f->{format}) {
					$c->{ $f->{name} } 
						= $self->_->format->format( $c->{ $f->{name} } );
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

		my $comments = $self->posts_by_time($fobj,$start,$limit);

		my @data;
		foreach my $c ( @{ $comments->posts } ) {
			#$self->_->last_modified->nominate($p->{timestamp});
			foreach my $f (@{ $self->fields }) {
				if ($format && $f->{format}) {
					$c->{ $f->{name} } 
						= $self->_->format->format( $c->{ $f->{name} } );
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
	my $fobj = shift;

	# -- register a timestamp handler -- #
	$self->_->gholders->register(
		["timestamp" , sub { $self->handle_timestamp($fobj,@_); }]
	);

	my $id 		= $fobj->bucket->get("id");
	my $confirm	= $fobj->bucket->get("confirm");

	# -- load post information -- #

	my $c = $self->get_by_id($fobj,$id)->{$id};

	my $format = ( $self->_->switchboard->knows("format") ) ? 1 : undef;

	foreach my $f (@{ $self->fields }) {
		if ($format && $f->{format}) {
			$c->{ $f->{name} } 
				= $self->_->format->format( $c->{ $f->{name} } );
		} else {
			# do nothing
		}
	}

	$fobj->gholders->register(
		['comment',$c]
	);

	# -- now figure an action -- #

	if ($confirm) {
		$self->_->gholders->register(['confirm',1]);
		# they said to go ahead
		$self->delete($fobj,$id);
	}
}
#----------

sub handle_timestamp {
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
	my $fobj = shift;

	my $results = $self->get_from_glomheaders($fobj,
		'id in (' . join('?',map{'?'} @_) .')',
		@_
	);

	my $posts = {};
	%$posts = map { $_->{id} => $_ } @$results; 
	
	# -- now get post data -- #

	my $data = $self->_->utils->g_load_tbl(
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
	my $fobj = shift;
	my $start = shift;
	my $limit = shift;

	my $where = 
		qq(
			status = 1
			order by timestamp desc
		);

	return $self->posts_generic_w_limit($fobj,$where,$start,$limit);
}

#----------

sub posts_by_parent {
	my $fobj = shift;
	my $parent = shift;

	# -- what ids do we want? -- #

	my $where = 
		qq(
			parent = ? 
			and status = 1
			order by 
			timestamp
		);

	return $self->posts_generic($fobj,$where,$parent);
}

#----------

sub fields {
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
			$self->_->switchboard->knows("user") 
				? $self->_->user->id
				: 0,
		require	=> 0,
	},
	{
		name	=> "status",
		def		=> "tinyint not null",
		allowed	=> '\d+',
		d_value	=> 1,
	},

	];
}

#----------

1;

