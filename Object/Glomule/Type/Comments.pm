package eThreads::Object::Glomule::Type::Comments;

@ISA = qw( eThreads::Object::Glomule );

use strict;

#----------

sub TYPE { "comments" }

#----------

sub new {
	my $class = shift;
	my $data = shift;
	my $name = shift;
	my $i = shift;

	$class = bless ( {
		table	=> undef,
		name	=> $name,
		_		=> $data,
	} , $class ); 

	if (!$name) {
		$class->{name} = "comments",
	}

	# create our custom switchboard
	my $custom = $class->{_}->switchboard->custom;
	$custom->reroute_calls_for($class);

	# -- register ourselves -- #

	$custom->register("glomule",$class);

	$class->load_info;

	return $class;
}

#----------

sub activate {
	my $class = shift;

	# -- register our functions -- #
	$class->activate_functions;

	# FIXME - this format module should get loaded somewhere else...  i'm not 
	# FIXME - sure where, though, so i'm going to load one here for now.

	$class->{_}->switchboard->register("format" , sub {
		$class->{_}->instance->new_object("Format::Markdown")
	} );

	$class->{_}->objects->activate($class->{_}->format);

	return $class;
}

#----------

sub activate_functions {
	my $class = shift;

	# -- load our prefs -- #
	$class->register_prefs( $class->_prefs )->load_prefs;

	$class->register_functions(
		{
			name	=> "view",
			sub		=> sub {$class->f_view(@_)},
			qopts	=> $class->qopts_view,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
		{
			name	=> "post",
			sub		=> sub {$class->f_post(@_)},
			qopts	=> $class->qopts_post,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
	);

	return $class;
}

#----------

sub f_view {
	my $class = shift;
	my $fobj = shift;

	my $id = $fobj->bucket->get("id");

	my ($posts,$count) = $class->get_by_parent($id);

	my $format = ( $class->{_}->switchboard->knows("format") ) ? 1 : undef;

	my $comments = [];
	my @data;
	foreach my $p (@$posts) {
		$class->{_}->last_modified->nominate($p->{timestamp});
		foreach my $f (@{ $class->fields }) {
			if ($format && $f->{format}) {
				$p->{ $f->{name} } 
					= $class->{_}->format->format( $p->{ $f->{name} } );
			} else {
				# do nothing
			}
		}

		push @$comments, $p->{id};
		push @data, ['comments.'.$p->{id} , $p ];
	}

	# create a blank compose hash
	my $compose = {};
	%$compose = map { $_->{name} => "" } @{ $class->edit_fields };

	$class->gholders->register(
		['count' , $count],
		['comments' , $comments ],
		['compose', $compose ],
		@data
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
			["timestamp" , sub { $class->handle_timestamp(@_); }]
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
			$class->gholders->register(["message",$msg]);
		}

		$class->gholders->register(
			['preview',1],
			['preview',$c]
		);

		# now register the raw values into compose
	
		$class->gholders->register(['compose',$post]);
	} elsif ( $fobj->bucket->get("post") ) {
		$class->gholders->register(["post",1]);
		# flesh out the post
		$post->{parent} = $id;
		my ($ok,$msg) = $class->flesh_out_post($post);

		if ($ok) {
			# we can go ahead and post
			$class->post($post);
			$class->gholders->register(['comment',$post]);
		} else {
			# doh...  error.  
			$class->gholders->register(["message",$msg]);
			$class->gholders->register(['compose',$post]);
		}
	}
}

#----------

sub handle_timestamp {
	my $class = shift;
	my $i = shift;
	my $c = shift;

	my $a = 
		$i->args->{format} 
		|| $i->args->{DEFAULT} 
		|| $class->pref("datetime_format")->get;

	$_[0] .= Date::Format::time2str($a,$c);
	return 0;
}

#----------

sub get_by_parent {
	my $class = shift;
	my $parent = shift;

	# -- what ids do we want? -- #

	my $db = $class->{_}->core->get_dbh;

	my $where = 
		qq(
			parent = ? 
			order by 
			timestamp
		);

	my ($results,$count) = $class->get_from_glomheaders(
		$where,
		$parent
	);

	my $posts = {};

	# if we didn't get anything, short-circuit here
	if (!$count) {
		return ([],0);
	}

	my @ids = map { $_->{id} } @$results;
	%$posts = map { $_->{id} => $_ } @$results; 
	
	# -- now get post data -- #

	my $data = $class->{_}->utils->g_load_tbl(
		tbl		=> $class->{data},
		ident	=> "id",
		ids		=> \@ids,
	);

	while ( my ($id,$d) = each %$data ) {
		while ( my ($k,$v) = each %$d ) {
			$posts->{$id}{$k} = $v if (!$posts->{$id}{$k});
		}
	}

	return ($results,$count);
}

#----------

sub qopts_view {
	my $class = shift;

	return [

	{
		opt		=> "id",
		d_value	=> undef,
		allowed	=> '\d+',
		persist	=> 1,
	},

	];
}

sub qopts_post {
	my $class = shift;

	return [

	{
		opt		=> "id",
		d_value	=> undef,
		allowed	=> '\d+',
		persist	=> 1,
	},
	{
		opt		=> "title",
		allowed	=> '.+',
		d_value	=> '',
	},
	{
		opt		=> "name",
		allowed	=> '.+',
		d_value	=> '',
	},
	{
		opt		=> "url",
		allowed	=> '.+',
		d_value	=> '',
	},
	{
		opt		=> "email",
		allowed	=> '.+',
		d_value	=> '',
	},
	{
		opt		=> "comment",
		allowed	=> '.+',
		d_value	=> '',
	},
	{
		opt		=> "post",
		allowed	=> '.+',
		d_value	=> '',
	},
	{
		opt		=> "preview",
		allowed	=> '.+',
		d_value	=> '',
	},

	];
}

#----------

sub fields {
	my $class = shift;

	return [
		{
			name	=> "name",
			def		=> "varchar(30) not null",
			require	=> 1,
			edit	=> 1,
		},
		{
			name	=> "email",
			def		=> "varchar(60)",
			edit	=> 1,
		},
		{
			name	=> "url",
			def		=> "varchar(60)",
			edit	=> 1,
		},
		{
			name	=> "comment",
			def		=> "text not null",
			format	=> 1,
			require	=> 1,
			edit	=> 1,
		},
		{
			name	=> "ip",
			def		=> "varchar(20)",
			d_value	=> $ENV{REMOTE_ADDR},
		},
	];
}

sub header_fields {
	my $class = shift;

	return [

	{
		name	=> "id",
		def		=> "int(11) not null auto_increment",
		primary	=> 1,
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

sub _prefs {return [
	{
		name		=> "datetime_format",
		d_value		=> "%D %I:%M%p",
		allowed		=> '.*',
		descript	=> qq(
			How eThreads should format fields marked as containing date & time.
		),
	},

];}

#----------

1;
