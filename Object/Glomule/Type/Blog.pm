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

	# -- load our prefs -- #
	$class->register_prefs( $class->_prefs )->load_prefs;

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
		{
			name	=> "archive",
			sub		=> sub {$class->f_archive(@_)},
			qopts	=> $class->qopts_archive,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
		{
			name	=> "management",
			sub		=> sub {$class->f_management(@_)},
			qopts	=> $class->qopts_management,
			modes	=> {
				Auth	=> 1,
			},
		},
		{
			name	=> "compose_post",
			sub		=> sub {$class->f_compose_post(@_)},
			qopts	=> $class->qopts_compose_post,
			modes	=> {
				Auth	=> 1,
			},
		},
		{
			name	=> "post",
			sub		=> sub {$class->f_post(@_)},
			qopts	=> $class->qopts_post,
			modes	=> {
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

	foreach my $qo ('start','limit','sortby','sortdir','month','year','day') {
		my $v = $fobj->bucket->get("nav/".$qo);
		$class->pref($qo)->set($v) if ($v);
	}

	# -- figure out what posts we're getting, and, uh, get em -- #

	my $posts;
	my $count;
	if ($category) {

	} else {
		($posts,$count) = $class->get_data_by_parent(
			parent	=> 0,
			status	=> 1,
		);
	}

	$class->register_navigation($count);
	
	# -- register our posts -- #

	if ($class->pref("day_based_display")->get) {
		my $days = [];

		# -- divide posts into days -- #
		my $cday = 0;
		foreach my $p (@$posts) {
			#$p->{categories} = $class->{categories}->get_cats_for_id($p->{id});

			$class->{_}->last_modified->nominate($p->{timestamp});

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

	# -- register a timestamp handler -- #
	$class->{_}->gholders->register(
		["timestamp" , sub { $class->handle_timestamp(@_); }]
	);

	my $id = $fobj->bucket->get("id");

	if (!$id) {
		$class->{_}->core->bail("You must provide an ID");
	}

	my $post = $class->get_post_information($id);

	# FIXME -- temporary hack while i'm missing posts
	if (!$post->{title} && ($id > 1410 && $id < 1620)) {
		$post = {
			title	=> "It'll be a bit...",
			intro	=> "The post you're looking for falls into the gap of posts that I'm still working to recover.  Sorry about that.  Come back in a week or two and maybe it'll be back.",
			user	=> 1,
			timestamp	=> 1098868083,
		};
	}

	foreach my $f (@{ $class->fields }) {
		next if (!$f->{format});

		$post->{ $f->{name} } 
			= $class->{_}->format->format( $post->{ $f->{name} } );
	}

	# -- load user information -- #

	if ($post->{user}) {
		my $user = $class->{_}->instance->new_object("User",id=>$post->{user});
		$post->{user} = $user->cachable;
	}


	$class->{gholders}->register(
		['post',$post]
	);

	return 1;
}

#----------

sub f_archive {
	my $class = shift;
	my $fobj = shift;

	my $category = $fobj->bucket->get("category");

	my $get;
	if ($category) {

	} else {
		$get = $class->{_}->core->get_dbh->prepare("
			select 
				timestamp 
			from 
				" . $class->{headers} . "
			where 
				status = 1 
		");

		$class->gholders->register(['category','-']);
	}

	$get->execute;

	# -- now buzz through and separate them -- #

	my @mons = (
		'','January','February','March','April','May','June','July',
		'August','September','October','November','December'
	);

	my ($ts);
	$get->bind_columns(\$ts);

	my %dates;
	while ( $get->fetch ) {
		my $tmp = Date::Format::time2str("%Y/%m/%d",$ts);
		$tmp =~ m!^(\d\d\d\d)/(\d\d)/(\d\d)$!;
		$dates{$1}{$2}{$3}++;
		$dates{$1}{$2}{TOTAL}++;
		$dates{$1}{TOTAL}++;
	}

	my @years;
	foreach my $y (sort {$b <=> $a} keys %dates) {
		next if ($y eq "TOTAL");

		my @data;
		my @months;
		foreach my $m (sort {$b <=> $a} keys %{$dates{$y}}) {
			next if ($m eq "TOTAL");

			$class->gholders->register([ 'year.'.$y.'.month.'.$m , {
				mon		=> $m,
				month	=> $mons[$m],
				year	=> $y,
				count	=> $dates{$y}{$m}{TOTAL},
			} ]);

			push @months, $m;
		}

		$class->gholders->register(
			['year.'.$y , {
				year	=> $y,
				count	=> $dates{$y}{TOTAL},
				month	=> \@months,
			} ]
		);

		push @years, $y;
	}

	$class->gholders->register(['year',\@years]);
}

#----------

sub f_management {
	my $class = shift;
	my $fobj = shift;

	# -- get postponed posts -- #
	{
		my $posts = $class->get_posts_by_status(0);

		my @o;
		foreach my $p (@$posts) {
			$class->gholders->register(["postponed.".$p->{id} , $p]);
			push @o, $p->{id};
		}

		$class->gholders->register(["postponed",\@o]);
	}
}

#----------

sub f_compose_post {
	my $class = shift;
	my $fobj = shift;

	my $id = $fobj->bucket->get("post/id");

	my $data = {
		id		=> $id,
		title	=> undef,
		body	=> undef,
		intro	=> undef,
	};

	if (!$id) {
		# do nothing
	} else {
		# load postponed post from the db
		my $post = $class->get_post_information($id);

		foreach my $f ('title','intro','body') {
			$data->{$f} = $post->{$f};
		}
	}

	foreach my $f ('title','intro','body') {
		if (my $v = $fobj->bucket->get("post/".$f)) {
			$v = URI::Escape::uri_unescape($v);
			$data->{$f} = $v;
		}

		# strip some html
		$data->{$f} =~ s!<br>!!g;
	}

	$class->gholders->register(["post" , $data]);
}

#----------

sub f_post {
	my $class = shift;
	my $fobj = shift;

	my $post = {};

	foreach my $f ('id','title','intro','body') {
		my $v = $fobj->bucket->get("post/".$f);
		$v = URI::Escape::uri_unescape($v);

		$post->{ $f } = $v;
	}

	# fill in fields from postponed post
	if ($post->{id}) {
		my $p = $class->get_post_information($post->{id});

		while ( my ($k,$v) = each %$p ) {
			$post->{ $k } = $v if (!$post->{ $k });
		}
	}

	$class->flesh_out_post(
		post	=> $post,
		data	=> $class->fields,
	);

	if ($fobj->bucket->get("post/post")) {
		$class->gholders->register(["post",1]);

		my $post = $class->post(
			$post,
			status => 1,
		);

		#my $pings = $class->load_pings;
		#$pings->ping_all;

		$class->gholders->register(["post",$post]);
	} elsif ($fobj->bucket->get("post/preview")) {
		# -- register a timestamp handler -- #
		$class->{_}->gholders->register(
			["timestamp" , sub { $class->handle_timestamp(@_); }]
		);

		$class->gholders->register(["preview",1]);
		my $preview = {};
		%$preview = %$post;

		$preview->{user} = $class->{_}->user->cachable;
	
		foreach my $f (@{ $class->fields }) {
			next if (!$f->{format});

			$preview->{ $f->{name} } 
				= $class->{_}->format->format( $preview->{ $f->{name} } );
		}

		$class->gholders->register(
			['post',$preview]
		);
	} elsif ($fobj->bucket->get("post/postpone")) {
		$class->gholders->register(["postpone",1]);

		my $post = $class->post(
			$post,
			status	=> 0,
		);

		$class->gholders->register(["post",$post]);
	} else {
		# they suck
	}
}

#----------

sub register_navigation {
	my $class = shift;
	my $count = shift;

	my $max = $class->pref("limit")->get;
	my $start = $class->pref("start")->get;

	my ($prev,$next);
	my $p_start = ($start - $max);
	my $f_start = ($start + $max);

	$p_start = 0 if ($p_start < 0);

	if ($start) {
		my $link = $class->{_}->queryopts->link(
			$class->{_}->template->path,
			{
				class	=> "nav",
				start	=> $p_start,
			}
		);

		my $p_posts = ($start > $max) ? $max : $start;

		$prev = { href => $link , num => $p_posts };
	} else {
		$prev = {};
	}

	if ($count > $f_start) {
		my $link = $class->{_}->queryopts->link(
			$class->{_}->template->path,
			{
				class	=> "nav",
				start	=> $f_start,
			}
		);

		my $r_posts = ($count - $start - $max);

		if ($r_posts > $max) {
			$r_posts = $max;
		}

		$next = { href => $link , num => $r_posts };
	} else {
		$next = {};
	}

	# -- register gholders -- #

	$class->gholders->register(
		[ 'nav.prev' , $prev ],
		[ 'nav.next' , $next ],
	);
}

#----------

sub count_posts {
	my $class = shift;
	my %a = @_;

	my $status;
	if ($a{status}) {
		
	}

	my $db = $class->{_}->core->get_dbh;

	my $count = $db->prepare("
		select 
			count(id) 
		from 
			" . $class->{headers} . " 
		where 
			status = 1
	");

	$count->execute;

	
}

#----------

sub post {
	my $class = shift;
	my $ipost = shift;
	my %args = @_;

	my $post = {};
	%$post = %$ipost;

	while ( my ($k,$v) = each %args ) {
		$post->{ $k } = $v;
	}

	my $db = $class->{_}->core->get_dbh;

	# now we need to insert (or update) our headers entry.

	my (@hfields,@hvalues);
	foreach my $f (@{$class->header_fields}) {
		next if ($f->{name} eq "id");
		
		push @hfields, $f->{name};
		push @hvalues, $post->{ $f->{name} };
	}
	
	if ($post->{id}) {
		# update

		my $update = $db->prepare("
			update 
				" . $class->{headers} . " 
			set 
				" . join("=\?,",@hfields) . "=? 
			where 
				id = ?
		");

		$update->execute(@hvalues,$post->{id}) 
			or $class->{_}->core->bail("update post failure: " . $db->errstr);
	} else {
		# insert 

		my $insert = $db->prepare("
			insert into 
				" . $class->{headers} . "
			(" . join(",",@hfields) . ") 
			values(" . join(",",split("","?"x@hfields)) . ")
		");

		$insert->execute(@hvalues) 
			or $class->{_}->core->bail("insert post failed: " . $db->errstr);

		# FIXME - this is a MySQL specific hack
		$post->{id} = $db->{'mysql_insertid'};
	}

	# now do data
	foreach my $f (@{ $class->fields }) {
		$class->{_}->core->set_value(
			tbl		=> $class->{data},
			keys	=> {
				id		=> $post->{id},
				ident	=> $f->{name},
			},
			value	=> $post->{ $f->{name} },
		);
	}

	return $post;
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

sub get_posts_by_status {
	my $class = shift;
	my $status = shift;

	#my $headers = $class->get_glomheaders;

	my $datelimit = $class->set_up_datelimit;

	my $sql = 
		qq(
			status = ? 
			$datelimit->{sql}
			order by 
		) . $class->pref("sortby") . " " . $class->pref("sortdir");
	

	my $posts = $class->get_from_glomheaders(
		$sql,
		$status
	);

	return $posts;
}

#----------

sub get_data_by_parent {
	my $class = shift;
	my %a = @_;

	my $status;
	if ($a{status}) {
		$status = "and status = $a{status}";
	}

	# -- datelimit? -- #

	my $datelimit = $class->set_up_datelimit;

	# -- what ids do we want? -- #

	my $db = $class->{_}->core->get_dbh;

	# first make a count of all posts the query would have retrieved if 
	# it had not been limited

	my $where = 
		qq(
			parent = ? 
			$status 
			$datelimit->{sql} 
			order by 
		)  
		. $class->pref("sortby")->get 
		. " " 
		. $class->pref("sortdir")->get;

	my $count = $db->prepare("
		select 
			count(id) 
		from
			$class->{headers}
		where 
			$where
	");

	$count->execute($a{parent}) 
		or $class->{_}->core->bail("count posts failed: ".$db->errstr);

	my $num_posts = $count->fetchrow_array;

	# now actually get our limited rows

	my $results = $class->get_from_glomheaders(
		$where
		. " limit " 
		. $class->pref("start")->get
		. ","
		. $class->pref("limit")->get,
		$a{parent}
	);

	my $posts = {};

	my @ids = map { $_->{id} } @$results;
	%$posts = map { $_->{id} => $_ } @$results; 
	
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

	return ($results,$num_posts);
}

#----------

sub set_up_datelimit {
	my $class = shift;

	my $datelimit = {
		year	=> undef,
		month	=> undef,
		day		=> undef,
		active	=> 0,
	};

	if (my $year = $class->pref("year")->get) {
		$datelimit->{active}++;
		$datelimit->{year} = $year;
	}

	if (my $val = $class->pref("month")->get) {
		next if (!$datelimit->{year});
		$datelimit->{month} = $val;
	}

	if (my $val = $class->pref("day")->get) {
		next if (!$datelimit->{year} && !$datelimit->{day});
		$datelimit->{day} = $val;
	}

	if ($datelimit->{active}) {
			my $year	= $datelimit->{year};
			my $mon		= $datelimit->{month} 	|| "01";
			my $day		= $datelimit->{day} 	|| "01";
			
			my $start = Time::ParseDate::parsedate("$year/$mon/$day");

			my $end;
			if ($datelimit->{day}) {
				$end = Time::ParseDate::parsedate("+1 day",NOW=>$start);
			} elsif ($datelimit->{month}) {
				$end = Time::ParseDate::parsedate("+1 month",NOW=>$start);
			} else {
				$end = Time::ParseDate::parsedate("+1 year",NOW=>$start);
			}

			$datelimit->{sql} 
				= "and (timestamp >= $start and timestamp < $end)";
	}

	return $datelimit;
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
		persist	=> 1,
	},
	{
		opt		=> "start",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("start")->get,
		desc	=> "Starting result number.",
		persist	=> 1,
	},
	{
		opt		=> "limit",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("limit")->get,
		desc	=> "How many results to return",
		persist	=> 1,
	},
	{
		opt		=> "sortby",
		class	=> "nav",
		allowed	=> '\w+',
		d_value	=> $class->pref("sortby")->get,
		desc	=> "Field by which results will be sorted.",
		persist	=> 1,
	},
	{
		opt		=> "sortdir",
		class	=> "nav",
		allowed	=> '(?:asc|desc)',
		d_value	=> $class->pref("sortdir")->get,
		toggle	=> ['asc','desc'],
		desc	=> "Direction of sorting",
		persist	=> 1,
	},
	{
		opt		=> "year",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("year")->get,
		desc	=> "Year Limit",
		persist	=> 1,
	},
	{
		opt		=> "month",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("month")->get,
		desc	=> "Month Limit",
		persist	=> 1,
	},
	{
		opt		=> "day",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("day")->get,
		desc	=> "Day Limit",
		persist	=> 1,
	},

	];
}

#----------

sub qopts_archive {
	my $class = shift;

	return [

	{
		opt		=> "category",
		allowed	=> '\w+',
		d_value	=> undef,
		desc	=> "Selects a category for viewing.",
		persist	=> 1,
	},
	{
		opt		=> "year",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("year")->get,
		desc	=> "Year Limit",
		persist	=> 1,
	},
	{
		opt		=> "month",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("month")->get,
		desc	=> "Month Limit",
		persist	=> 1,
	},
	{
		opt		=> "day",
		class	=> "nav",
		allowed	=> '\d+',
		d_value	=> $class->pref("day")->get,
		desc	=> "Day Limit",
		persist	=> 1,
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

#----------

sub qopts_management {
	my $class = shift;

	return [
	];
}

#----------

sub qopts_compose_post {
	my $class = shift;

	return [

	{
		opt		=> "id",
		allowed	=> '\d+',
		d_value	=> '',
		desc	=> "Post ID",
		class	=> "post",
		persist	=> 1,
	},
	{
		opt		=> "title",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Post Title",
		class	=> "post",
	},
	{
		opt		=> "intro",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Post Intro",
		class	=> "post",
	},
	{
		opt		=> "body",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Post Body",
		class	=> "post",
	},

	];
}

#----------

sub qopts_post {
	my $class = shift;

	return [

	{
		opt		=> "id",
		allowed	=> '\d+',
		d_value	=> '',
		desc	=> "Post ID",
		class	=> "post",
		persist	=> 1,
	},
	{
		opt		=> "title",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Post Title",
		class	=> "post",
		persist	=> 1,
	},
	{
		opt		=> "intro",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Post Intro",
		class	=> "post",
		persist	=> 1,
	},
	{
		opt		=> "body",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Post Body",
		class	=> "post",
		persist	=> 1,
	},
	{
		opt		=> "preview",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Preview",
		class	=> "post",
		persist	=> 0,
	},
	{
		opt		=> "postpone",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Postpone",
		class	=> "post",
		persist	=> 0,
	},
	{
		opt		=> "post",
		allowed	=> '.*',
		d_value	=> '',
		desc	=> "Post",
		class	=> "post",
		persist	=> 0,
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
		name		=> "sortby",
		d_value		=> "timestamp",
		allowed		=> '\w+',
		hidden		=> 1,
	},
	{
		name		=> "sortdir",
		d_value		=> "desc",
		allowed		=> '(?:asc|desc)',
		hidden		=> 1,
	},
	{
		name		=> "start",
		d_value		=> "0",
		allowed		=> '\d+',
		hidden		=> 1,
	},
	{
		name		=> "year",
		d_value		=> "0",
		allowed		=> '\d+',
		hidden		=> 1,
	},
	{
		name		=> "month",
		d_value		=> "0",
		allowed		=> '\d+',
		hidden		=> 1,
	},
	{
		name		=> "day",
		d_value		=> "0",
		allowed		=> '\d+',
		hidden		=> 1,
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
	];
}

#----------

1;
