package eThreads::Object::Glomule::Type::NCManagement;

@ISA = qw( eThreads::Object::Glomule );

use strict;

#----------

sub TYPE { "NCManagement" }

#----------

sub new {
	my $class = shift;
	my $data = shift;
	my $name = shift;

	$class = bless ( {
		_		=> $data,
		name	=> $name || undef,
		id		=> undef,
	} , $class );

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
			name	=> "committee",
			sub		=> sub {$class->f_committee(@_)},
			qopts	=> $class->qopts_committee,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
		{
			name	=> "add_member",
			sub		=> sub {$class->f_add_member(@_)},
			qopts	=> $class->qopts_add_member,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
		{
			name	=> "remove_member",
			sub		=> sub {$class->f_remove_member(@_)},
			qopts	=> $class->qopts_remove_member,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
		{
			name	=> "add_committee",
			sub		=> sub {$class->f_add_committee(@_)},
			qopts	=> $class->qopts_add_committee,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
		{
			name	=> "add_person",
			sub		=> sub {$class->f_add_person(@_)},
			qopts	=> $class->qopts_add_person,
			modes	=> {
				Normal	=> 1,
				Auth	=> 1,
			},
		},
	);

	return $class;
}

#----------

sub f_main {
	my $class = shift;
	my $fobj = shift;

	# -- load a list of committees -- #

	{
		# load root level committees
		my $committees = $class->load_committees();

		my @data;
		foreach my $c (@$committees) {
			push @data, [ 'committee.'.$c->{id} , $c ];
		}

		$class->gholders->register(
			['committee', [ map { $_->{id} } @$committees ] ],
			@data
		);
	}

	return 1;
}

#----------

sub f_committee {
	my $class = shift;
	my $fobj = shift;

	my $id = $fobj->bucket->get('id');

	$class->{_}->bail->("No committee id given.") if (!$id);

	# -- load the commitee info -- #

	my $c = $class->load_committee(id=>$id);

	$class->gholders->register(['committee',$c]);

	# -- now load a list of committee members -- #

	my $members = $class->list_members_of_committee($id);

	$class->gholders->register(
		['member', [ map { $_->{id} } @$members ] ],
		map { [ 'member.'.$_->{id} , $_ ] } @$members
	);

}

#----------

sub f_person {
	my $class = shift;
	my $fobj = shift;

	
}

#----------

sub f_add_member {
	my $class = shift;
	my $fobj = shift;

	my $committee = $fobj->bucket->get('committee');
	my $person = $fobj->bucket->get('person');

	if (!$committee) {
		$class->{_}->bail->("You must provide a committee.");
	}

	my $c = $class->load_committee(id=>$committee);
	$class->gholders->register(['committee',$c]);

	if (!$person) {
		# load a list of people
		my $p = $class->list_people_not_in_committee($committee);

		$class->gholders->register(
			['person_list', [ map { $_->{id} } @$p ] ],
			map { [ 'person_list.'.$_->{id} , $_ ] } @$p
		);
	}

	if ($committee && $person) {
		# load the person's info, then see what we do
		my $p = $class->load_person($person);

		$class->gholders->register(
			['person',1],
			['person',$p]
		);
	
		if ($fobj->bucket->get('confirm')) {
			# add the person to the committee
			my $add = $class->{_}->core->get_dbh->prepare("
				insert into 
					" . $class->data('mappings') . "
					(c,p,role)
				values(?,?,?)
			");

			$add->execute($committee,$person,undef)
				or $class->{_}->bail->("add member failed: ". $add->errstr);

			$class->gholders->register(['added',1]);
		} else {
			# wait for confirmation
		}
	}
}

#----------

sub f_remove_member {

}

#----------

sub f_add_committee {
	my $class = shift;
	my $fobj = shift;

	my $c = {
		name		=> undef,
		descript	=> undef,
		parent		=> 0,
	};

	if ($fobj->bucket->get("submit")) {
		foreach my $k ('name','descript','parent') {
			$c->{ $k } = $fobj->bucket->get( $k );
		}

		my $message = undef;

		if (!$message && !$c->{name}) {
			$message = "Name is required.";
		}

		if (
			!$message 
			&& $class->load_committee(name=>$c->{name},parent=>$c->{parent})
		) {
			$message = "Name is not unique.";
		}

		if ($message) {
			# register the message so they can try again
			$class->gholders->register(
				['message',$message]
			);
		} else {
			# go about trying to add the committee
			my $posted = $class->post(
				$c,
				headers		=> $class->data('committee_headers'),
				h_fields	=> $class->_tbl_committee_headers,
				data		=> $class->data('committee_data'),
				d_fields	=> $class->_fields_committee_data,
			);

			$class->gholders->register(
				['created',1],
				['created',$posted]
			);
		}
	} else {

	}

	# we need a tree of parents
#	my $c = $class->load_committee_tree;

	$class->gholders->register(['committee',$c]);
}

#----------

sub f_add_person {
	my $class = shift;
	my $fobj = shift;

	my $p = {
		id			=> undef,
		name		=> undef,
		email		=> undef,
		phone		=> undef,
		category	=> undef,
	};

	my $id = $fobj->bucket->get('id');
	
	if ($fobj->bucket->get('submit')) {
		foreach my $k ('id','name','email','phone','category') {
			$p->{ $k } = $fobj->bucket->get( $k );
		}

		my $message = undef;


		if ($message) {
			$class->gholders->register(['message',$message]);
		} else {
			$class->flesh_out_post(
				$p,
				h_fields	=> $class->_tbl_people_headers,
				d_fields	=> $class->_fields_people_data,
			);
		
			my $posted = $class->post(
				$p,
				headers		=> $class->data('people_headers'),
				h_fields	=> $class->_tbl_people_headers,
				data		=> $class->data('people_data'),
				d_fields	=> $class->_fields_people_data,
			);

			$class->gholders->register(
				['created',1]
			);
		}

	} else {

	}

	$class->gholders->register(['person',$p]);
}

#----------

sub load_committees {
	my $class = shift;
	my $parent = shift || 0;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			name
		from 
			" . $class->data("committee_headers") . "
		where 
			parent = ?
		order by name
	");

	$get->execute($parent) 
		or $class->{_}->bail->("load_committees failure: " . $get->errstr);

	# short-circuit if we didn't get anything
	return undef if (!$get->rows);

	my ($id,$n);
	$get->bind_columns( \($id,$n) );

	my $committees = [];
	my $lookup = {};
	
	while ($get->fetch) {
		my $c = {
			id		=> $id,
			name	=> $n
		};

		push @$committees, $c;
		$lookup->{ $id } = $c;
	}

	# -- now fill in data -- #

	my $data = $class->{_}->utils->g_load_tbl(
		tbl		=> $class->data('committee_data'),
		ident	=> "id",
		ids		=> [ map { $_->{id} } @$committees ],
	);

	while ( my ($id,$d) = each %$data ) {
		while ( my ($k,$v) = each %$d ) {
			$lookup->{ $id }{ $k } = $v if ( !$lookup->{ $id }{ $k } );
		}
	}

	return $committees;
}

#----------

sub load_committee {
	my $class = shift;
	my %a = @_;

	my $where = undef;
	if ($a{id}) {
		$where = ["id = ?",$a{id}];
	} elsif ($a{name}) {
		$where = ["name = ? and parent = ?",$a{name},$a{parent}];
	} else {
		$class->{_}->bail->("load_committee needs either name or id.");
	}

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			name,
			parent
		from 
			" . $class->data('committee_headers') . " 
		where 
			$where->[0]
	");

	$get->execute(@$where[1..$#$where])
		or $class->{_}->bail->("load_committee failure: ".$get->errstr);

	return undef if (!$get->rows);

	my ($id,$n,$p);
	$get->bind_columns( \($id,$n,$p) );

	$get->fetch;
	my $committee = {
		id		=> $id,
		name	=> $n,
		parent	=> $p
	};

	# -- load committee info from data -- #

	# FIXME: add data code

	return $committee;
}

#----------

sub load_committee_tree {
	my $class = shift;
	my $parent = shift;
	
	my $ctree = $class->load_committees($parent);

	foreach my $c (@$ctree) {
		$class->_load_committee_tree($c);
	}
}

sub _load_committee_tree {
	my $class = shift;
	my $ref = shift;

	my $c = $class->load_committees($ref->{id});

	if ($c) {
		$ref->{children} = $c;

		foreach my $cc (@$c) {
			$class->load_committee_tree($cc);
		}
	}
}

#----------

sub list_members_of_committee {
	my $class = shift;
	my $committee = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			p.id,
			p.name,
			m.role
		from 
			" . $class->data('mappings') . " as m,
			" . $class->data('people_headers') . " as p
		where 
			m.p = p.id 
			and m.c = ? 
		order by 
			m.role,
			p.name
	");

	$get->execute($committee) 
		or $class->{_}->bail->("list_members get failure: ".$get->execute);

	my ($p,$n,$r);
	$get->bind_columns( \($p,$n,$r) );

	my $members = [];
	while ($get->fetch) {
		push @$members, {
			id		=> $p,
			name	=> $n,
			role	=> $r
		};
	}

	# -- now flesh out the info about the people -- #

	# FIXME: add code

	return $members;
}

#----------

sub load_person {
	my $class = shift;
	my $id = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			name
		from 
			" . $class->data('people_headers') . " 
		where 
			id = ?
	");

	$get->execute($id) 
		or $class->{_}->bail->("load_person failure" . $get->errstr);

	return undef if (!$get->rows);

	my ($name) = $get->fetchrow_array;

	my $person = {
		id		=> $id,
		name	=> $name,
	};

	# -- load person data -- #

	# FIXME: add code

	return $person;
}

#----------

sub list_people_not_in_committee {
	my $class = shift;
	my $committee = shift;

	# first get a list of people in the committee
	my $members = $class->list_members_of_committee($committee);

	my $by_id = { map { $_->{id} => $_ } @$members };

	# now get a list of all people
	my $people = $class->list_people;

	# now run through people and grab all but the members
	my $non_members = [];
	foreach my $p (@$people) {
		next if ($by_id->{ $p->{id} });
		push @$non_members, $p;
	}

	return $non_members;
}

#----------

sub list_people {
	my $class = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			name
		from 
			" . $class->data('people_headers') . "
		order by name
	");

	$get->execute
		or $class->{_}->bail->("list_people failure: ".$get->errstr);

	my ($id,$n);
	$get->bind_columns( \($id,$n) );

	my $people = [];
	while ($get->fetch) {
		push @$people, {
			id		=> $id,
			name	=> $n
		};
	}

	return $people;
}

#----------

sub create_tables {
	my $class = shift;

	# we overload here to create a couple different tables
	# - committees: index of committees
	# - people: index of people
	# - mappings: map people to commitees
	
	# all of these are going to have custom layouts

	foreach my $t (
		[ 'committee_headers',	$class->_tbl_committee_headers 	],
		[ 'committee_data',		$class->_data_tbl_fields 		],
		[ 'people_headers',		$class->_tbl_people_headers 	],
		[ 'people_data',		$class->_data_tbl_fields 		],
		[ 'mappings',			$class->_tbl_mappings			]
	) {
		my $data = $class->{_}->utils->create_table(
			$class->{_}->utils->get_unused_tbl_name("glomdata"),
			$t->[1]
		);

		$class->register_data($t->[0],$data);
	}

	return 1;
}

#----------

sub _prefs {return [

]};

#----------

sub qopts_main {
	my $class = shift;

	return [

	];
}

#----------

sub qopts_add_member {
	my $class = shift;

	return [

	{
		opt		=> "committee",
		allowed	=> '\d+',
		d_value	=> undef,
		persist	=> 1,
	},
	{
		opt		=> "person",
		allowed	=> '\d+',
		d_value	=> undef,
		persist	=> 1,
	},
	{
		opt		=> "role",
		allowed	=> '.*',
		d_value	=> undef,
		persist	=> 1,
	},
	{
		opt		=> "confirm",
		allowed	=> '\d+',
		d_value	=> undef,
		persist	=> 1,
	}

	];
}

#----------

sub qopts_remove_member {
	my $class = shift;

	return [

	{
		opt		=> "committee",
		allowed	=> '\d+',
		d_value	=> undef,
		persist	=> 1,
	},
	{
		opt		=> "person",
		allowed	=> '\d+',
		d_value	=> undef,
		persist	=> 1,
	},
	{
		opt		=> "confirm",
		allowed	=> '\d+',
		d_value	=> undef,
		persist	=> 1,
	}

	];
}

#----------

sub qopts_committee {
	my $class = shift;

	return [

	{
		opt		=> "id",
		allowed	=> '\d+',
		d_value	=> undef,
	},

	];
}

#----------

sub qopts_add_person {
	my $class = shift;

	return [

	{
		opt		=> "submit",
		allowed	=> '.*',
		d_value	=> undef,
	},
	{
		opt		=> "id",
		allowed	=> '\d+',
		d_value	=> undef,
	},
	{
		opt		=> "name",
		allowed	=> '.*',
		d_value	=> undef,
	},
	{
		opt		=> "email",
		allowed	=> '.*',
		d_value	=> undef,
	},
	{
		opt		=> "phone",
		allowed	=> '.*',
		d_value	=> undef,
	},
	{
		opt		=> "category",
		allowed	=> '.*',
		d_value	=> undef,
	},

	];
}

#----------

sub qopts_add_committee {
	my $class = shift;

	return [

	{
		opt		=> "submit",
		allowed	=> '.*',
		d_value	=> undef,
	},
	{
		opt		=> "name",
		allowed	=> '.+',
		d_value	=> undef,
	},
	{
		opt		=> "descript",
		allowed	=> '.*',
		d_value	=> undef,
	},
	{
		opt		=> "parent",
		allowed	=> '\d+',
		d_value	=> 0,
	},
	
	];
}

#----------

sub _tbl_committee_headers {
	return [

	{	KEYS	=> [
		'primary key(id)',
		'unique key(parent,name)',
	] },

	{
		name	=> "id",
		def		=> "int(11) not null auto_increment",
		d_value	=> 0,
	},
	{
		name	=> "name",
		def		=> "varchar(60) not null",
	},
	{
		name	=> "parent",
		def		=> "int(11) default 0",
	},

	];
}

#----------

sub _fields_committee_data {
	return [

	{
		name	=> "descript",
		format	=> 1,
		edit	=> 1,
	},

	];
}

#----------

sub _tbl_people_headers {
	return [

	{ KEYS => [
		'primary key(id)',
	] },

	{
		name	=> "id",
		def		=> "int(11) not null auto_increment",
		allowed	=> '\d+',
		d_value	=> 0,
	},

	{
		name	=> "name",
		def		=> "varchar(60) not null",
		allowed	=> '.*',
		require	=> 1,
		edit	=> 1,
	},

	];
}

#----------

sub _fields_people_data {
	return [

	{
		name	=> "email",
		format	=> 0,
		edit	=> 1,
	},
	{
		name	=> "phone",
		format	=> 0,
		edit	=> 1,
	},
	{
		name	=> "category",
		format	=> 0,
		edit	=> 1,
	},
	{
		name	=> "residential",
		format	=> 0,
		edit	=> 1,
	},
	{
		name	=> "business",
		format	=> 0,
		edit	=> 1,
	}

	];
}

#----------

sub _tbl_mappings {
	return [

	{ KEYS => [
		'primary key(c,p)'
	] },

	{
		name	=> "c",
		def		=> "int(11) not null",
	},

	{
		name	=> "p",
		def		=> "int(11) not null",
	},

	{
		name	=> "role",
		def		=> "enum('Member','Chair','President','Vice-President','Secretary','Treasurer','Alternate')",
	},

	];
}

#----------

=head1 NAME

eThreads::Object::Glomule::Type::NCManagement;

=head1 SYNOPSIS

=head1 DESCRIPTION


=over 4


=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
