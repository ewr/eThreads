package eThreads::Object::Glomule::Type::Blog;

@ISA = qw( eThreads::Object::Glomule );

use strict;
use Date::Format;

#----------

sub new {
	my $class = shift;
	my $data = shift;
	my $name = shift;

	$class = bless( { 
		_		=> $data,
		name	=> $name || undef,
		id		=> undef,
	} , $class);

	$class->load_info;

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub activate {
	my $class = shift;

	# create our custom switchboard

	my $custom = $class->{_}->switchboard->custom;
	$custom->reroute_calls_for($class);
	$custom->register("switchboard",$custom);

	# -- register our functions -- #
	$class->activate_functions;

	# -- load our prefs -- #
	$class->register_prefs( $class->_prefs )->load_prefs;

	# -- load the categories system -- #
	# $class->{categories} 
	#	= $class->{_}->load_module("systems/categories");

	# -- load our format module -- #
	$class->{_}->switchboard->register("format" , sub {
		$class->{_}->instance->new_object("Format::Markdown")
	} );

	$class->{_}->objects->activate($class->{_}->format);

	return $class;
}

#----------

sub activate_functions {
	my $class = shift;

	$class->register_functions(
		{
			name	=> "",
			sub		=> sub {$class->f_main(@_)},
			qopts	=> $class->qopts_main,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
		{
			name	=> "view",
			sub		=> sub {$class->f_view(@_)},
			qopts	=> $class->qopts_view,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
	);

	return $class;
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

sub f_main {
	my $class = shift;
	my $fobj = shift;

	# -- register a timestamp handler -- #

	$class->{_}->gholders->register(
		["timestamp" , sub { $class->handle_timestamp(@_); }]
	);

	# -- get our query options -- #

	my $category	= $fobj->bucket->get("category");
	my $start 		= $fobj->bucket->get("nav/start");
	my $limit 		= $fobj->bucket->get("nav/limit");
	my $sortby 		= $fobj->bucket->get("nav/sortby");
	my $sortdir		= $fobj->bucket->get("nav/sortdir");

	# -- figure out what posts we're getting, and, uh, get em -- #

	my $posts;
	if ($category) {

	} else {
		#$class->{_}->set_title();

		$posts = $class->get_data_by_parent(
			parent	=> 0,
			start	=> $start,
			limit	=> $limit,
			sortby	=> $sortby,
			dir		=> $sortdir,
		);
	}

	# -- register our posts -- #

	if ($class->pref("day_based_display")->get) {
		my $days = [];

		# -- divide posts into days -- #
		my $max_ts;

		my $cday = 0;
		foreach my $p (@$posts) {
			#$p->{categories} = $class->{categories}->get_cats_for_id($p->{id});
			
			$max_ts = $p->{timestamp} if ($p->{timestamp} > $max_ts);

			my $date = time2str("%x",$p->{timestamp});

			my $ploc = '/' . $class->{gholders}->get . 'post.'.$p->{id};

			if ($cday eq $date) {
				push @{$days->[-1]}, $ploc;
			} else {
				push @$days, [ $p->{timestamp} , $ploc ];
				$cday = $date;
			}

			foreach my $f (@{ $class->fields }) {
				next if (!$f->{format});

				$p->{ $f->{name} } 
					= $class->{_}->format->format( $p->{ $f->{name} } );
			}

			$class->{gholders}->register(
				['post.'.$p->{id} , $p]
			);
		}

		# -- go through each day -- #

		my @odays;
		foreach my $d (@$days) {
			my $ts = shift @$d;

			$class->{gholders}->register(
				[ 'day.'.$ts , { timestamp => $ts , post => $d } ],
			);

			push @odays, $ts;
		}

		$class->{gholders}->register(
			[ 'day' , \@odays ]
		);
	}

	return 1;
}

#----------

sub f_view {
	my $class = shift;
	my $fobj = shift;

	my $id = $fobj->bucket->get("id");

	if (!$id) {
		$class->{_}->core->bail("You must provide an ID");
	}

	my $post = $class->get_post_information($id);

	foreach my $f (@{ $class->fields }) {
		next if (!$f->{format});

		$post->{ $f->{name} } 
			= $class->{_}->format->format( $post->{ $f->{name} } );
	}

	$class->{gholders}->register(
		['post',$post]
	);

	return 1;
}

#----------

sub get_post_information {
	my $class = shift;
	my $id = shift;

	my $get_headers = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			title,
			timestamp,
			user,
			parent
		from 
			$class->{headers}
		where 
			id = ?
	");

	$get_headers->execute($id);

	my $p = {};
	$get_headers->bind_columns( 
		\($p->{id},$p->{title},$p->{timestamp},$p->{user},$p->{parent}) 
	);
	$get_headers->fetch;

	my $data = $class->{_}->core->g_load_tbl(
		tbl		=> $class->{data},
		ident	=> "id",
		ids		=> [$id],
		flat	=> 1,
	);

	while ( my ($k,$v) = each %$data ) {
		$p->{$k} = $v if (!$p->{$k});
	}

	return $p;
}	

#----------

sub get_data_by_parent {
	my $class = shift;
	my %a = @_;

	$a{start} = $a{start} || 0;
	$a{limit} = $a{limit} || 0;

	# -- load headers -- #

	my $headers = $class->{_}->cache->load_cache_file(
		tbl		=> "glomheaders",
		first	=> $class->{id},
	);

	if (!$headers) {
		$headers = $class->cache_glomheaders;
	}

	# -- what ids do we want? -- #

	my $db = $class->{_}->core->get_dbh;

	my $select = $db->prepare("
		select 
			id 
		from
			$class->{headers}
		where 
			parent = ?
		order by 
			? $a{dir}
		limit
			$a{start},$a{limit}
	");

	$select->execute($a{parent},$a{sortby}) 
		or $class->{_}->core->bail("main select failed: ".$db->errstr);

	my $id;
	$select->bind_columns(\$id);

	my $results = [];
	my @ids;
	my $posts = {};
	while ($select->fetch) {
		my $post = {};

		%$post = %{$headers->{ $id }};

		#while ( my ($k,$v) = each %{$data->{ $id }} ) {
		#	$post->{$k} = $v if (!$post->{$k});
		#}

		$posts->{$id} = $post;

		push @ids, $id;

		push @$results, $post;
	}

	# -- now get post data -- #

	my $data = $class->{_}->core->g_load_tbl(
		tbl		=> $class->{data},
		ident	=> "id",
		ids		=> \@ids,
	);

	while ( my ($id,$d) = each %$data ) {
		while ( my ($k,$v) = each %$d ) {
			$posts->{$id}{$k} = $v if (!$posts->{$id}{$k});
		}
	}

	return $results;
}

#---------------#
# query options #
#---------------#

sub qopts_main {
	my $class = shift;

	return [

	{
		opt		=> "category",
		allowed	=> '\w+',
		d_value	=> undef,
		desc	=> "Selects a category for viewing.",
	},

	{
		opt		=> "start",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> 0,
		desc	=> "Starting result number."
	},

	{
		opt		=> "limit",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> 10,
		desc	=> "How many results to return",
	},

	{
		opt		=> "sortby",
		class	=> "nav",
		allowed	=> '\w+',
		d_value	=> 'id',
		desc	=> "Field by which results will be sorted.",
	},

	{
		opt		=> "sortdir",
		class	=> "nav",
		allowed	=> '(?:asc|desc)',
		d_value	=> 'desc',
		toggle	=> ['asc','desc'],
		desc	=> "Direction of sorting",
	},

	];
}

#----------

sub qopts_view {
	my $class = shift;

	return [

	{
		opt		=> "id",
		allowed	=> '\d+',
		d_value	=> '',
		desc	=> "Post ID",
	},

	];
}

#-------#
# prefs #
#-------#

sub _prefs {return [
	{
		name		=> "button_bar_nav",
		d_value		=> "1",
		allowed		=> '[10]',
		descript	=> qq(
			Put Previous/Next links in the button bar.
		),
		select		=> [["Yes","1"],["No","0"]],
	},
	{
		name		=> "comments",
		d_value		=> "1",
		allowed		=> '[10]',
		descript	=> qq(
			Allow readers to comment on your posts.
		),
		select		=> [["Yes","1"],["No","0"]],
	},
	{
		name		=> "datetime_format",
		d_value		=> "%D %I:%M%p",
		allowed		=> '.*',
		descript	=> qq(
			How eThreads should format fields marked as containing date & time.
		),
	},
	{
		name		=> "limit",
		d_value		=> "10",
		allowed		=> '\d+',
		descript	=> qq(
			How many threads eThreads should print per page.
		),
	},
	{
		name		=> "archive_years",
		d_value		=> 1,
		allowed		=> '[10]',
		descript	=> qq(
			Show years in the archive?
		),
		select		=> [['Yes',1],['No',0]],
	},
	{
		name		=> "archive_months",
		d_value		=> 1,
		allowed		=> '[10]',
		descript	=> qq(
			Show months in the archive?
		),
		select		=> [['Yes',1],['No',0]],
	},
	{
		name		=> "archive_days",
		d_value		=> 0,
		allowed		=> '[10]',
		descript	=> qq(
			Show days in the archive?
		),
		select		=> [['Yes',1],['No',0]],
	},
	{
		name		=> "day_based_display",
		d_value		=> 1,
		allowed		=> '[10]',
		descript	=> qq(
			Prepare day-based post tree.
		),
		select		=> [['Yes',1],['No',0]],
	},
	{
		name		=> "post_based_display",
		d_value		=> 1,
		allowed		=> '[10]',
		descript	=> qq(
			Prepare post-based post tree.
		),
		select		=> [['Yes',1],['No',0]],
	},
];}

#----------

sub fields {
	my $class = shift;

	return [
		{
			name	=> "intro",
			format	=> 1,
		},
		{
			name	=> "body",
			format	=> 1,
		},
		{
			name	=> "poster",
			format	=> 1,
		},
		{
			name	=> "poster_email",
			format	=> 1,
		},
		{
			name	=> "poster_url",
			format	=> 1,
		},
	];
}

#----------

1;
