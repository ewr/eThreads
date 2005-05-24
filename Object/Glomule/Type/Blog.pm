package eThreads::Object::Glomule::Type::Blog;

@ISA = qw( eThreads::Object::Glomule::Type );

use strict;
use Date::Format;
use Time::ParseDate;

#----------

sub TYPE { "blog" }

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless( { 
		_		=> $data,
	} , $class);

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub activate {
	my $class = shift;

	return $class;
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

sub f_main {
	my $class = shift;
	my $fobj = shift;


	# -- register a timestamp handler -- #
	$class->{_}->gholders->register(
		["timestamp" , sub { $class->handle_timestamp($fobj,@_); }]
	);

	# -- get our query options -- #

	my $category	= $fobj->bucket->get("category");

	foreach my $qo ('start','limit','sortby','sortdir','month','year','day') {
		my $v = $fobj->bucket->get($qo);
		$fobj->glomule->pref($qo)->set($v) if ($v);
	}

	# -- figure out what posts we're getting, and, uh, get em -- #

	my $posts;
	if ($category) {
		# see if this is a valid category
		my $cat = $fobj->glomule->system('categories')->is_valid_name($category)
			or $class->{_}->bail->("Invalid category: $category");

		$fobj->gholders->register(['category', $cat->registerable ]);

#		$posts = $class->posts_by_category(
#			category	=> $category,
#			status		=> 1,
#		);
	} else {
		$posts = $class->posts_by_parent($fobj,
			parent	=> 0,
			status	=> 1,
		);
	}

	$class->register_navigation($fobj,$posts->count);
	
	# -- register our posts -- #

	$class->register_day_nav($fobj,$posts);

	return 1;
}

#----------

sub f_view {
	my $class = shift;
	my $fobj = shift;

	# -- register a timestamp handler -- #
	$class->{_}->gholders->register(
		["timestamp" , sub { $class->handle_timestamp($fobj,@_); }]
	);

	my $id = $fobj->bucket->get("id");

	my $post = $class->load_and_format_post($fobj,$id);

	$class->{_}->last_modified->nominate($post->{timestamp});

	$fobj->gholders->register(
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
		$class->{_}->bail->("Category support not yet implemented.");

	} else {
		$get = $class->{_}->core->get_dbh->prepare("
			select 
				timestamp 
			from 
				" . $fobj->glomule->data('headers') . "
			where 
				status = 1 
				and parent = 0
		");

		$fobj->gholders->register(['category','-']);
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
		$class->{_}->last_modified->nominate($ts);
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

			$fobj->gholders->register([ 'year.'.$y.'.month.'.$m , {
				mon		=> $m,
				month	=> $mons[$m],
				year	=> $y,
				count	=> $dates{$y}{$m}{TOTAL},
			} ]);

			push @months, $m;
		}

		$fobj->gholders->register(
			['year.'.$y , {
				year	=> $y,
				count	=> $dates{$y}{TOTAL},
				month	=> \@months,
			} ]
		);

		push @years, $y;
	}

	$fobj->gholders->register(['year',\@years]);
}

#----------

sub f_management {
	my $class = shift;
	my $fobj = shift;

	# -- get postponed posts -- #
	{
		my $posts = $class->posts_by_status($fobj,0);

		if ($posts) {
			my @o;
			foreach my $p (@{ $posts->posts }) {
				$fobj->gholders->register(["postponed.".$p->{id} , $p]);
				push @o, $p->{id};
			}

			$fobj->gholders->register(["postponed",\@o]) if (@o);
		}
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
		my $post = $class->get_post_information($fobj,$id);

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

	$fobj->gholders->register(["post" , $data]);
}

#----------

sub f_post {
	my $class = shift;
	my $fobj = shift;

	my $post = {};

	foreach my $f ('id','title','intro','body') {
		my $v = $fobj->bucket->get($f);
		$v = URI::Escape::uri_unescape($v);

		$post->{ $f } = $v;
	}

	# fill in fields from postponed post
	if ($post->{id}) {
		my $p = $class->get_post_information($fobj,$post->{id});

		while ( my ($k,$v) = each %$p ) {
			$post->{ $k } = $v if (!$post->{ $k });
		}
	}

	$class->flesh_out_post($post);

	if ($fobj->bucket->get("post")) {
		$fobj->gholders->register(["post",1]);

		# figure out our ping situation first
		my $ping;
		if (!$post->{id} || !$post->{status}) {
			$ping = 1;
		}

		my $post = $class->post(
			$fobj,
			$post,
			status => 1,
		);

		if ($ping) {
			my $pings = $class->load_pings;
			$pings->ping_all;
		}

		$fobj->gholders->register(["post",$post]);
	} elsif ($fobj->bucket->get("preview")) {
		# -- register a timestamp handler -- #
		$class->{_}->gholders->register(
			["timestamp" , sub { $class->handle_timestamp($fobj,@_); }]
		);

		$fobj->gholders->register(["preview",1]);
		my $preview = {};
		%$preview = %$post;

		$preview->{user} = $class->{_}->user->cachable;
	
		foreach my $f (@{ $class->fields }) {
			next if (!$f->{format});

			$preview->{ $f->{name} } 
				= $fobj->glomule->system('format')
					->format( $preview->{ $f->{name} } );
		}

		$fobj->gholders->register(
			['post',$preview]
		);
	} elsif ($fobj->bucket->get("postpone")) {
		$fobj->gholders->register(["postpone",1]);

		my $post = $class->post(
			$fobj,
			$post,
			status	=> 0,
		);

		$fobj->gholders->register(["post",$post]);
	} else {
		$class->{_}->bail->("Post called incorrectly.  No valid function.");
	}
}

#----------

sub f_delete {
	my $class = shift;
	my $fobj = shift;

	my $id 		= $fobj->bucket->get("id");
	my $confirm	= $fobj->bucket->get("confirm");

	# -- load post information -- #

	my $post = $class->load_and_format_post($fobj,$id);

	$fobj->gholders->register(
		['post',$post]
	);

	# -- now figure an action -- #

	if ($confirm) {
		$class->{_}->gholders->register(['confirm',1]);
		# they said to go ahead
		$class->delete($fobj,$id);
	}
}

#----------

sub f_ondate {
	my $class = shift;
	my $fobj = shift;

	# -- register a timestamp handler -- #
	$class->{_}->gholders->register(
		["timestamp" , sub { $class->handle_timestamp($fobj,@_); }]
	);

	my $date = $fobj->bucket->get("date");
	
	my $ts = 
		($date) 
		? Time::ParseDate::parsedate($date)
		: Time::ParseDate::parsedate("12:00am",NOW=>time);

	# first get our minimum timestamp
	my $min;
	{
		my $get = $class->{_}->core->get_dbh->prepare("
			select 
				min(timestamp)
			from 
				" . $fobj->glomule->data('headers') . "
		");

		$get->execute()
			or $class->{_}->bail->("ondate get_min failure: ".$get->errstr);

		$min = $get->fetchrow_array;
	}

	# prepare our id getting query
	my $get_ids = $class->{_}->core->get_dbh->prepare("
		select 
			id 
		from 
			" . $fobj->glomule->data('headers') . "
		where 
			timestamp >= ?
			and timestamp < (? + 86400)
	");

	my $ids = [];
	while ($ts >= $min) {
		$get_ids->execute($ts,$ts)
			or $class->{_}->bail->("ondate get_ids failure: ".$get_ids->errstr);

		my $id;
		$get_ids->bind_columns(\$id);

		while ($get_ids->fetch) {
			push @$ids, $id;
		}
	
		$ts = Time::ParseDate::parsedate("-1 year",NOW=>$ts);
	}

	$fobj->gholders->register(["count",scalar @$ids]);

	if (@$ids == 0) {
		return 1;
	}

	# -- now get these ids -- #

	my $posts = $class->posts_generic(
		$fobj,
		"id in (" 
			. join(",",map { "?" } @$ids) .
		") and parent = 0 order by timestamp desc",
		@$ids
	);

#	my $posts = {};

#	%$posts = map { $_->{id} => $_ } @$results; 
	
	# -- now get post data -- #

#	my $data = $class->{_}->utils->g_load_tbl(
#		tbl		=> $fobj->glomule->data('data'),
#		ident	=> "id",
#		ids		=> $ids,
#	);

#	while ( my ($id,$d) = each %$data ) {
#		while ( my ($k,$v) = each %$d ) {
#			$posts->{$id}{$k} = $v if (!$posts->{$id}{$k});
#		}
#	}

	# -- now format and register -- #

	$class->register_day_nav($fobj,$posts);
}

#----------

sub register_day_nav {
	my $class = shift;
	my $fobj = shift;
	my $posts = shift;

	my $days = [];

	# -- get data lengths for posts -- #

	my $lengths = $class->get_data_lengths_for($fobj,$posts);

	# -- divide posts into days -- #
	my $cday = 0;
	foreach my $p (@{ $posts->posts }) {
		#$p->{categories} = $class->{categories}->get_cats_for_id($p->{id});

		$class->{_}->last_modified->nominate($p->{timestamp});

		my $date = time2str("%x",$p->{timestamp});

		my $ploc = '/' . $fobj->gholders->get . 'post.'.$p->{id};

		if ($cday eq $date) {
			push @{$days->[-1]}, $ploc;
		} else {
			push @$days, [ 0, $p->{timestamp} , $ploc ];
			$cday = $date;
		}

		# get lengths of data fields
		$p->{length} = $lengths->{ $p->{id} };

		my $format = $fobj->glomule->system('format');

		foreach my $f (@{ $class->fields }) {
			next if (!$f->{format});

			$p->{ $f->{name} } 
				= $format 
					? $format->format( $p->{ $f->{name} } )
					: $p->{ $f->{name} };
		}

		$fobj->gholders->register(
			['post.'.$p->{id} , $p]
		);
	}

	# -- go through each day -- #

	# mark day one
	$days->[0][0] = 1;

	my @odays;
	foreach my $d (@$days) {
		my $expcol = shift @$d;
		my $ts = shift @$d;

		$fobj->gholders->register(
			[ 'day.'.$ts , { 
				expand 		=> $expcol, 
				timestamp 	=> $ts, 
				post 		=> $d 
			} ],
		);

		push @odays, $ts;
	}

	$fobj->gholders->register(
		[ 'day' , \@odays ]
	);

	return 1;
}

#----------

sub load_and_format_post {
	my $class = shift;
	my $fobj = shift;
	my $id = shift;

	if (!$id) {
		$class->{_}->bail->("You must provide an ID");
	}

	my $post = $class->get_post_information($fobj,$id);

	my $format = $fobj->glomule->system('format');

	foreach my $f (@{ $class->fields }) {
		next if (!$f->{format});

		$post->{ $f->{name} } 
			= $format 
				? $format->format( $post->{ $f->{name} } )
				: $post->{ $f->{name} };
	}

	# -- load user information -- #

	if ($post->{user}) {
		my $user = $class->{_}->new_object("User",id=>$post->{user});
		$post->{user} = $user->cachable;
	}

	return $post;
}

#----------

sub register_navigation {
	my $class = shift;
	my $fobj = shift;
	my $count = shift;

	my $max = $fobj->glomule->pref("limit")->get;
	my $start = $fobj->glomule->pref("start")->get;

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
		$prev = undef;
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
		$next = undef;
	}

	# -- register gholders -- #

	$fobj->gholders->register(
		[ 'nav.prev' , $prev ],
		[ 'nav.next' , $next ],
	);
}

#----------

sub count_posts {
	my $class = shift;
	my $fobj = shift;
	my %a = @_;

	my $status;
	if ($a{status}) {
		
	}

	my $db = $class->{_}->core->get_dbh;

	my $count = $db->prepare("
		select 
			count(id) 
		from 
			" . $fobj->glomule->data('headers') . " 
		where 
			status = 1
	");

	$count->execute;

	
}

#----------

sub get_post_information {
	my $class = shift;
	my $fobj = shift;
	my $id = shift;

	# -- first get post headers -- #

	my $get_headers = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			title,
			timestamp,
			user,
			status,
			parent
		from 
			" . $fobj->glomule->data('headers') . "
		where 
			id = ?
	");

	$get_headers->execute($id);

	my $p = {};
	$get_headers->bind_columns( 
		\(
			$p->{id},
			$p->{title},
			$p->{timestamp},
			$p->{user},
			$p->{status},
			$p->{parent}
		) 
	);
	$get_headers->fetch;

	# -- bail if we didn't get anything -- #
	
	if (!$p->{id}) {
		$class->{_}->bail->(
			"get_post_information: Post does not exist: $id"
		);
	}

	# -- now load post data onto headers -- #

	my $data = $class->{_}->utils->g_load_tbl(
		tbl		=> $fobj->glomule->data('data'),
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

sub get_data_lengths_for {
	my $class = shift;
	my $fobj = shift;
	my $posts = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			id,ident,length(value)
		from 
			" . $fobj->glomule->data('data') . "
		where 
			id in (" . join( ',' , map {'?'} @{$posts->posts} ) . ")
	");

	$get->execute( map { $_->{id} } @{ $posts->posts } );

	my ($id,$i,$l);
	$get->bind_columns( \($id,$i,$l) );

	my $lengths = {};
	while ($get->fetch) {
		$lengths->{ $id }{ $i } = $l;
	}

	return $lengths;
}

#----------

sub posts_by_status {
	my $class = shift;
	my $fobj = shift;
	my $status = shift;

	my $datelimit = $class->set_up_datelimit($fobj);

	my $where = 
		qq(
			status = ?
			$datelimit->{sql}
			order by 
		) 
			. $fobj->glomule->pref("sortby")->get 
			. " " 
			. $fobj->glomule->pref("sortdir")->get;

	return $class->posts_generic(
		$fobj,
		$where,
		$status
	);
}

#----------

sub posts_by_id {
	my $class = shift;
	my %a = @_;


}

#----------

sub posts_by_parent {
	my $class = shift;
	my $fobj = shift;
	my %a = @_;

	my $datelimit = $class->set_up_datelimit($fobj);

	my $status;
    if ($a{status}) {
        $status = "and status = $a{status}";
    }

	my $where = 
		qq(
			parent = ?
			$status
			$datelimit->{sql}
			order by 
		) 
			. $fobj->glomule->pref("sortby")->get 
			. " " 
			. $fobj->glomule->pref("sortdir")->get;

	return $class->posts_generic_w_limit(
		$fobj,
		$where,
		$fobj->glomule->pref("start")->get,
		$fobj->glomule->pref("limit")->get,
		$a{parent}
	);
}

#----------

sub posts_by_category {
	my $class = shift;
	my $fobj = shift;
	my %a = @_;

	my $status;
	if ($a{status}) {
		$status = "and status = $a{status}";
	}

	# -- datelimit? -- #

	my $datelimit = $class->set_up_datelimit;

	# -- get category sql -- #

	my $cat_sql = $class->{_}->categories->get_sql_for($a{category});

	my $where = 
		qq(
			$cat_sql
			$status 
			$datelimit->{sql} 
			order by 
		)  
		. $fobj->glomule->pref("sortby")->get 
		. " " 
		. $fobj->glomule->pref("sortdir")->get;

	return $class->posts_generic_w_limit(
		$fobj,
		$where,
		$fobj->glomule->pref('start')->get,
		$fobj->glomule->pref('limit')->get
	);
}

#----------

sub set_up_datelimit {
	my $class = shift;
	my $fobj = shift;

	my $datelimit = {
		year	=> undef,
		month	=> undef,
		day		=> undef,
		active	=> 0,
	};

	if (my $year = $fobj->glomule->pref("year")->get) {
		$datelimit->{active}++;
		$datelimit->{year} = $year;
	}

	if (my $val = $fobj->glomule->pref("month")->get) {
		next if (!$datelimit->{year});
		$datelimit->{month} = $val;
	}

	if (my $val = $fobj->glomule->pref("day")->get) {
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
];}

#----------

sub fields {
	my $class = shift;

	return [
		{
			name	=> "intro",
			format	=> 1,
			edit	=> 1,
		},
		{
			name	=> "body",
			format	=> 1,
			edit	=> 1,
		},
	];
}

#----------

#----------

1;
