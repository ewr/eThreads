package eThreads::Object::System::Comments;

@ISA = qw( eThreads::Object::System );

use strict;

#----------

sub SYSTYPE { return "Comments"; }

sub new {
	my $class = shift;
	my $data = shift;
	my $i = shift;

	$class = bless ( {
		table	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

}

sub activate {
	my $class = shift;

	$class->{bucket} = $class->{_}->queryopts->new_bucket(
		system		=> $class->SYSTYPE,
		function	=> $class->{name},
	);

	# -- lookup table for container -- #

	if ( my $tbl = $class->{_}->container->data->{comments} ) {
		$class->{tbl} = $tbl;
	} else {
		# we need to create a table
		my $tbl = $class->initialize;
		$class->{_}->container->register_data("comments",$tbl);
		$class->{tbl} = $tbl;
	}

	# register our functions
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

	$class->functions->register(
		{
			name	=> "view",
			handle	=> sub { return $class->handle_view(@_); },
		},
		{
			name	=> "post",
			qopts	=> $class->qopts_post,
			handle	=> sub { return $class->handle_post(@_); },
			walk	=> sub { return $class->walk_post(@_); },
		},
	);

	return $class;
}

#----------

sub bucket {
	my $class = shift;
	return $class->{bucket};
}

#----------

sub functions {
	my $class = shift;

	if (!$class->{functions}) {
		$class->{functions} = $class->{_}->switchboard->new_object("Functions");
	}
	
	return $class->{functions};
}

#----------

sub find_key {
	my $class = shift;
	my $i = shift;

	# -- find comments key -- #

	# install a temporary key handler
	# FIXME - I want to be able to register this and then get rid of it 
	# FIXME - after we find our key, but I don't currently have a way to 
	# FIXME - do this.  we need basically custom switchboards for gholders

	$class->{_}->gholders->register(['key',sub { return 0; }]);

	my $key;
	foreach my $c (@{$i->children}) {
		next if ($c->type ne "key");

		$class->{_}->gholders->handle_template_tree($c,$key);

		last;
	}

	if (!$key) {
		$class->{_}->bail->("comments initialized with no key");
	}

	$class->{key} = $key;
}

#----------

sub walk_view {
	# do nothing;
}

#----------

sub handle_view {
	my $class = shift;
	my $i = shift;

	my $key = $class->find_key($i);

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			" . join("," , map { $_->{name} } @{ $class->fields } ) . " 
		from 
			" . $class->{tbl} . "
		where 
			ckey = ?
	");

	$get->execute($class->{key})
		or $class->{_}->bail->("get comments failure: " . $get->errstr);

	my $format = ( $class->{_}->switchboard->knows("format") ) ? 1 : undef;

	my $count = $get->rows;

	my $comments = [];
	my @data;
	while (my $r = $get->fetchrow_arrayref) {
		my $c = {};

		my $i;
		foreach my $f (@{ $class->fields }) {
			if ($format && $f->{format}) {
				$c->{ $f->{name} } 
					= $class->{_}->format->format($r->[$i]);
			} else {
				$c->{ $f->{name} } = $r->[$i];	
			}

			$i++;
		}

		push @$comments, $c->{id};
		push @data, ['comments.'.$c->{id} , $c ];
	}

	# create a blank compose hash
	my $compose = {};
	%$compose = map { $_->{name} => "" } @{ $class->fields };

	$class->{_}->gholderctx->register(
		['count' , $count],
		['comments' , $comments ],
		['compose', $compose ],
		@data
	);

	return 1;
}

#----------

sub walk_post {
	my $class = shift;

}

sub qopts_post {
	my $class = shift;

	return [
		{
			opt		=> "id",
			allowed	=> '\d+',
			d_value	=> 0,
			persist	=> 1,
		},
		{
			opt		=> "title",
			allowed	=> '.+',
			d_value	=> '',
			persist	=> 1,
		},
		{
			opt		=> "name",
			allowed	=> '.+',
			d_value	=> '',
			persist	=> 1,
		},
		{
			opt		=> "url",
			allowed	=> '.+',
			d_value	=> '',
			persist	=> 1,
		},
		{
			opt		=> "email",
			allowed	=> '.+',
			d_value	=> '',
			persist	=> 1,
		},
		{
			opt		=> "comment",
			allowed	=> '.+',
			d_value	=> '',
			persist	=> 1,
		},
		{
			opt		=> "post",
			allowed	=> '.+',
			d_value	=> '',
			persist	=> 1,
		},
		{
			opt		=> "preview",
			allowed	=> '.+',
			d_value	=> '',
			persist	=> 1,
		},
	];
}

#----------

sub handle_post {

}

#----------

sub initialize {
	my $class = shift;

	# -- get a table name for our comments -- #
	
	my $tbl = $class->{_}->utils->get_unused_tbl_name("comments");

	# -- create the table -- #

	$class->{_}->utils->create_table(
		$tbl,
		$class->fields
	);

	return $tbl;
}

#----------

sub fields {
	my $class = shift;

	return [
		{
			name	=> "id",
			def		=> "int(11) not null auto_increment",
			primary	=> 1,
			d_value	=> 0,
		},
		{
			name	=> "ckey",
			def		=> "varchar(20) not null",
			require	=> 1,
		},
		{
			name	=> "timestamp",
			def		=> "int(11) not null",
			d_value	=> time,
		},
		{
			name	=> "name",
			def		=> "varchar(30) not null",
			require	=> 1,
		},
		{
			name	=> "email",
			def		=> "varchar(60)",
		},
		{
			name	=> "url",
			def		=> "varchar(60)",
		},
		{
			name	=> "title",
			def		=> "varchar(80)",
		},
		{
			name	=> "comment",
			def		=> "text not null",
			format	=> 1,
			require	=> 1,
		}
	];
}

#----------

1;

