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

}

#----------

sub post {

}

#----------

sub initialize {
	my $class = shift;

	# make sure glomule doesn't have a comments table
	if ($class->{glomule}->{comments}) {
		warn "attempted to initialize over existing comments\n";
		return undef;
	}

	# -- get a table name for our comments -- #
	
	my $tbl = $class->{_}->core->get_unused_tbl_name("comments");

	# -- create the table -- #

	$class->{_}->core->create_table(
		name	=> $tbl,
		schema	=> $class->_table_schema,
	);

	# -- tell the glomule about the comments table -- #

	$class->glomule->register_data("comments",$tbl);

	return 1;
}

#----------

sub _table_schema {
	my $class = shift;

	return [
		{
			name	=> "id",
			def		=> "int(11) not null auto_increment",
			primary	=> 1,
		},
		{
			name	=> "parent",
			def		=> "int(11) not null",
		},
		{
			name	=> "name",
			def		=> "varchar(30) not null",
		},
		{
			name	=> "email",
			def		=> "varchar(60) not null",
		},
		{
			name	=> "url",
			def		=> "varchar(60) not null",
		},
		{
			name	=> "comment",
			def		=> "text not null",
		}
	];
}

#----------

1;

