package eThreads::Object::QueryOpts;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		opts	=> {},
		input	=> undef,
		buckets	=> [],
	} , $class );

	$class->{input} = $class->load_input;

	$class->load_qkeys_to_input;

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub new_bucket {
	my $class = shift;

	my $b = $class->{_}->instance->new_object("QueryOpts::Bucket",@_);

	return $b;
}

#----------

sub new_bucket_data {
	my $class = shift;

	my $b = {};
	push @{ $class->{buckets} } , $b;

	return $b;
}

#----------

# i'm not sure how useful the global register is here.  most always it will 
# be overloaded by the bucket register, which is as it should be.  I'm 
# leaving this here because i'm unsure if registering a queryopt from 
# outside a bucket is ever allowable (i tend to think it is not).

sub register {
	my $class = shift;
	my %args = @_;

	my $obj = $class->{_}->instance->new_object("QueryOpts::QueryOption",@_);

	if ($args{class}) {
		$class->{opts}{ $args{class} }{ $args{name} } = $obj;
		delete $class->{opts}{compiled}{ $args{class} };
	} else {
		$class->{opts}{GLOBAL}{ $args{name} } = $obj;
		delete $class->{opts}{compiled}{GLOBAL};
	}

	my $input = $class->get_from_input(
		glomule	=> $args{glomule}->id,
		name	=> $args{name}
	);

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

	my ($oclass,$oname);
	if ($opt =~ m!/!) {
		($oclass,$oname) = split("/",$opt);
	} else {
		$oclass = "GLOBAL";
		$oname = $opt;
	}

	return undef if ( 
		!exists( $class->{opts}{ $oclass } ) 
		|| !exists( $class->{opts}{ $oclass }{ $oname } )
	);

	my $oref = $class->{opts}{$oclass}{$oname};

	return $oref;
}

#----------

sub toggle {
	my ($class,$opt) = @_;
	return $class->get_ref($opt)->toggle;
}

#----------

sub link {
	my $class = shift;
	my $func = shift;
	my $args = shift;

	# to return a link, you have to come up with a number of different 
	# pieces.  First you need the container path, then the container name, 
	# then the template name, then the proper query opts to be appended 
	# to the end.  The template name is simple enough...  that's provided 
	# in $func.

	# start with the basics...

	my @pieces = (
		$class->{_}->root->path,
		$class->{_}->mode->path,
		$class->{_}->container->path,
		$func
	);

	my $link = join("/",@pieces);
	$link =~ s!/+!/!g;

	# now add on query opts

	my $opts;
	if ($args->{class}) {
		$opts .= $class->compile_persistent_options($args);
	}

	#$opts .= $class->compile_class_options({class=>"GLOBAL"});

	if ($opts) {
		$link .= ($link =~ /\?/) ? "&amp;" : "?";
		$link .= $opts;
	}

	# now just return what we've got

	return $link;
}

#----------

sub compile_persistent_options {
	my $class = shift;
	my $args = shift;

	# build a hash without class
	my $qargs = {};
	while ( my ($k,$v) = each %$args ) {
		next if ($k eq "class");
		$qargs->{ $k } = $v;
	}

	if ( !%$qargs && $class->{compiled}{ $args->{class} } ) {
		return $class->{compiled}{ $args->{class} };
	} else {
		my $opts;

		foreach my $b (@{ $class->{buckets} }) {
			my @q_opts;
			while ( my ($k,$opt) = each %{ $b->{ $args->{class} } } ) {
				next if ( !$opt->persist );
				my $v = exists( $qargs->{ $k } ) ? 
					$qargs->{ $k } : $opt->get;
	
				push @q_opts, $opt->{name}."=$v" if ($v ne $opt->d_value); 
			}

			$opts = join("&amp;",@q_opts);
		}
	
		if (!%$qargs) {
			$class->{compiled}{ $args->{class} } = $opts;
		}

		return $opts;
	}
}

#----------

sub list_persistent_options {
	my $class = shift;
	my $args = shift;
	my $qopts = [];

	# build a hash without class
	my $qargs = {};
	while ( my ($k,$v) = each %$args ) {
		next if ($k eq "class");
		$qargs->{ $k } = $v;
	}

	my @classes = ('GLOBAL');
	push @classes, $args->{class} if ($args->{class});

	foreach my $b (@{ $class->{buckets} }) {
		foreach my $c (@classes) {
			while ( my ($k,$opt) = each %{ $b->{ $c } } ) {
				next if ( !$opt->persist || !$opt->{name} );
				my $v = exists( $qargs->{ $opt->{name} } ) ? 
					$qargs->{ $opt->{name} } : $opt->get;
	
				push @$qopts, [$opt->{name},$v] if ($v ne $opt->d_value); 
			}
		}
	}

	return $qopts;	
}
#----------

#----------------#
# input routines #
#----------------#

sub get_input {
	my $class = shift;
	my $arg = shift;

	if ($arg) {
		if ( exists($class->{input}{ $arg }) ) {	
			return $class->{input}{ $arg };
		} else {
			return undef;
		}
	} else {
		return $class->{input};
	}
}

#----------

sub get_from_input {
	my $class = shift;
	my %a = @_;

	my $name = $class->get_name_for_opt($a{glomule},$a{opt}) 
		or return undef;

	# return what we find on input
	return $class->{_}->queryopts->get_input($name);
}

#----------

sub get_name_for_opt {
	my $class = shift;
	my $g = shift;
	my $o = shift;

	my $name = $class->{_}->template->qopts->{ $g }{ $o }{name};

	return $name || undef;
}

#----------

sub load_input {
	my $class = shift;
	my ($info);

	my $input = {};

	# just a little background on why i've waivering back and forth between 
	# rolling my own input code and using CGI.  I like CGI for the ability 
	# to do multipart forms (and thereby allow uploading into the screenshot 
	# module), but i also need access to escaped input values before they're 
	# parsed (to do pass-throughs), and I can't figure out how to do that 
	# with CGI at the moment.  So for now we're at an impasse.

	if ($ENV{'REQUEST_METHOD'} eq "POST") {
		read(STDIN,$info,$ENV{"CONTENT_LENGTH"});
	} else {
		$info=$ENV{QUERY_STRING};
	}

	# this is where we'll put unprocessed input values
	$input->{raw} = {};

	foreach (split(/&/,$info)) {
		my ($var,$val) = split(/=/,$_,2);
		$var =~ s/\+/ /g;

		# don't allow a var = 'raw'
		next if ($var eq"raw");

		# save the raw value
		$input->{raw}{$var} = $val;

		$val =~ s/\+/ /g;
		$val =~ s/%([0-9,A-F,a-f]{2})/sprintf("%c",hex($1))/ge;
		$input->{$var} .= ", " if ($input->{$var});
		$input->{$var} .= $val;
	}

	$input->{username} = $ENV{REMOTE_USER};

	return $input;
}

#----------

sub load_qkeys_to_input {
	my $class = shift;

	my $qkeys = $class->{_}->RequestURI->unclaimed;

	my @parts = split("/",$qkeys);
	
	# ignore an empty first part since we get a / first
	shift @parts if (!$parts[0]);

	foreach my $k (@{ $class->{_}->template->qkeys }) {
		my $v = shift @parts;
		next if (!$v);
		$class->{input}{ $k } = $v;
	}

	# for now we're just going to say, "hey, we're last," and claim 
	# all remaining URI no matter if we used it or not
	$class->{_}->RequestURI->claim($qkeys);

	return 1;
}

#----------

=head1 NAME

eTrevolution::eThreads::Object::QueryOpts

=head1 DESCRIPTION

This object manages eThreads QueryOpts.  It keeps track of QO Buckets, manages 
mapping input to qopts, etc.

=head1 SYNOPSIS

	my $q = new eThreads::Object::QueryOpts;

	
=cut

1;
