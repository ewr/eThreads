package eThreads::Object::QueryOpts::Bucket;

@ISA = qw( eThreads::Object::QueryOpts );

use strict;

#----------

sub new {
	my $proto 	= shift;
	my $class 	= ref($proto) || $proto;
	my $data 	= shift;

	my $self = {
		_			=> $data,
		glomule		=> undef,
		function	=> undef,

		@_,

		opts		=> $data->queryopts->new_bucket_data,
	};	

	bless $self, $class;

	return $self;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

#----------

sub register {
	my $class = shift;
	my %args = @_;

	my $obj = $class->{_}->instance->new_object(
		"QueryOpts::QueryOption",
		glomule	=> $class->{glomule},
		@_
	);

	if ( $obj->class ) {
		$class->{opts}{ $obj->class }{ $obj->opt } = $obj;
		delete $class->{compiled}{ $obj->class };
	} else {
		$class->{opts}{GLOBAL}{ $obj->opt } = $obj;
		delete $class->{compiled}{GLOBAL};
	}

	my $name = $obj->name;

	my $input;
	if ($name) {
		$input = $class->{_}->queryopts->get_input($name);
	} else {
		# nothing to look for
	}

	if (
		$input && 
		$input =~ m!^$args{allowed}$!s && 
		$input ne $args{d_value}
	) {
		$obj->set( $input );
	} else {
		# do nothing
	}

	return $obj->get;
}

#----------

1;
