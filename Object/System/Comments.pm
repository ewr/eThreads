package eThreads::Object::System::Comments;

@ISA = qw( eThreads::Object::System );

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		glomule	=> undef,
		@_,
		_		=> $data,
	} , $class ); 

	if (!$class->{glomule}) {
		$class->{_}->bail->("Comments initialized with no glomule");
	}

	return $class;
}

#----------

sub glomule {
	my $class = shift;
	return $class->{glomule};
}

#----------

sub get {
	my $class = shift;
	my $id = shift;

	my @fields = map { $_->{name} } @{ $class->fields };

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			@fields 
		from 
			" . $class->glomule->{comments} . "
		where 
			parent = ?
	");

	$get->execute($id)
		or $class->{_}->bail->("get comments failure: " . $get->errstr);

	my $format = ( $class->{_}->switchboard->knows("format") ) ? 1 : undef;

	my $comments = [];
	while (my $r = $get->fetchrow_arrayref) {
		my $c = {};
	
		for (my $i; $i<@fields;$i++) {
			if ($format) {
				$c->{ $fields[$i] } 
					= $class->{_}->format->format($r->[$i]);
			} else {
				$c->{ $fields[$i] } = $r->[$i];	
			}

		push @$comments, $c;
	}

	return $comments;
}

#----------

sub post {
	my $class = shift;


}

#----------

sub initialize {
	my $class = shift;

	# make sure glomule doesn't have a comments table
	if ($class->glomule->{comments}) {
		warn "attempted to initialize over existing comments\n";
		return undef;
	}

	# -- get a table name for our comments -- #
	
	my $tbl = $class->{_}->utils->get_unused_tbl_name("comments");

	# -- create the table -- #

	$class->{_}->utils->create_table(
		$tbl,
		$class->fields
	);

	# -- tell the glomule about the comments table -- #

	$class->glomule->register_data("comments",$tbl);

	return 1;
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
			name	=> "parent",
			def		=> "int(11) not null",
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
			name	=> "comment",
			def		=> "text not null",
			format	=> 1,
			require	=> 1,
		}
	];
}

#----------

1;

