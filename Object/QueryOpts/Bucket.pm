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

	$class->{opts}{ $obj->opt } = $obj;

	my $name = $obj->name;

	my $input;
	if ($name) {
		$input = $class->{_}->queryopts->get_input($name);
		$class->{_}->queryopts->bind_to_name($name,$obj);
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

sub get {
	my ($class,$opt) = @_;

	my $q = $class->get_ref($opt);

	if ($q) {
		return $q->get;
	} else {
		return undef;
	}
}

#----------

sub alter {
	my ($class,$opt,$key,$val) = @_;
	return $class->get_ref($opt)->alter($key,$val);
}

#----------

sub set {
	my ($class,$opt,$val) = @_;
	return $class->get_ref($opt)->set($val);
}

#----------

sub get_ref {
	my ($class,$opt) = @_;

	$opt =~ s!.*/([^/]+)!$1!;

	return undef if ( 
		!exists( $class->{opts}{ $opt } )
	);

	my $oref = $class->{opts}{$opt};

	return $oref;
}

#----------

sub toggle {
	my ($class,$opt) = @_;
	return $class->get_ref($opt)->toggle;
}

#----------

1;
