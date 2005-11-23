package eThreads::Object::QueryOpts::Bucket;

use eThreads::Object::QueryOpts -Base;
no warnings;

#----------

sub new {
	my $data = shift;

	$self = bless {
		_			=> $data,
		glomule		=> undef,
		function	=> undef,

		@_,

		opts		=> $data->queryopts->new_bucket_data,
	} , $self;	

	return $self;
}

#----------

sub register {
	my %args = @_;

	my $obj = $self->_->new_object(
		"QueryOpts::QueryOption",
		glomule	=> $self->{glomule},
		@_
	);

	$self->{opts}{ $obj->opt } = $obj;

	my $name = $obj->name;

	my $input;
	if ($name) {
		$input = $self->_->queryopts->get_input($name);
		$self->_->queryopts->bind_to_name($name,$obj);
	} else {
		# nothing to look for
	}

	if (
		$input && 
		$input =~ m!^$args{allowed}$!s && 
		$input ne $args{default}
	) {
		$obj->set( $input );
	} else {
		# do nothing
	}

	return $obj->get;
}

#----------

sub get {
	my $opt = shift;

	my $q = $self->get_ref($opt);

	if ($q) {
		return $q->get;
	} else {
		return undef;
	}
}

#----------

sub alter {
	my ($opt,$key,$val) = @_;
	return $self->get_ref($opt)->alter($key,$val);
}

#----------

sub set {
	my ($opt,$val) = @_;
	return $self->get_ref($opt)->set($val);
}

#----------

sub get_ref {
	my $opt = shift;

	$opt =~ s!.*/([^/]+)!$1!;

	return undef if ( 
		!exists( $self->{opts}{ $opt } )
	);

	my $oref = $self->{opts}{$opt};

	return $oref;
}

#----------

sub toggle {
	my $opt = shift;
	return $self->get_ref($opt)->toggle;
}

#----------

1;
