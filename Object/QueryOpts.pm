package eThreads::Object::QueryOpts;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		input	=> undef,
		buckets	=> [],
		names	=> {},
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

sub bind_to_name {
	my $class = shift;
	my $name = shift;
	my $opt = shift;

	if (!$class->{names}{ $name }) {
		# easy...  first time using a name
		$class->{names}{ $name } = $opt;
	} else {
		# hmmm...  conflict resolution time
		# FIXME: not sure how to handle this case
		warn "multiple binds to $name -- IGNORING\n";
	}
}

#----------

sub names {
	my $class = shift;
	return $class->{names};
}

#----------

sub link {
	my $class = shift;
	my $tmplt = shift;
	my $args = shift;

	$tmplt = "/" . $tmplt if ($tmplt !~ m!^/!);

	# to return a link, you have to come up with a number of different 
	# pieces.  First you need the container path, then the container name, 
	# then the template name, then the proper query opts to be appended 
	# to the end.  The template name is simple enough...  that's provided 
	# in $tmplt.

	# start with the basics...

	my @pieces = (
		$class->{_}->root->path,
		$class->{_}->mode->path,
		$class->{_}->container->path,
		$tmplt
	);

	# now try and figure out some qkeys, qopts, etc
	my $link_qopts;
	{
		# get qopts
		my $qopts = $class->list_link_qopts($tmplt,$args);

		# hash them
		my $h_qopts = {};
		foreach my $q (@$qopts) {
			$h_qopts->{ $q->[0] } = $q;
		}
		
		# we need to open a template object for the linked to template 
		# so that we can get its qkeys
		if ( my $qkeys = $class->_load_foreign_qkeys($tmplt) ) {
			my @keys;
			foreach my $k (@$qkeys) {
				push @keys, $h_qopts->{ $k }->[1] || "-";
				$h_qopts->{ $k }->[2] = 1;
			}

			# cleanup keys
			while ( $keys[-1] eq "-" ) {
				pop @keys;
			}

			push @pieces, @keys;
		} else {
			warn "failed to load qkeys for $tmplt\n";
			# do nothing
		}

		my @qopts;
		foreach my $q (@$qopts) {
			next if ($q->[2]);
			push @qopts, ( $q->[0] . "=" . $q->[1] );
		}

		$link_qopts = join("&amp;",@qopts);
	}

	my $link = join("/",@pieces);
	$link =~ s!/+!/!g;

	# now finally add on query opts

	if ($link_qopts) {
		$link .= ($link =~ /\?/) ? "&amp;" : "?";
		$link .= $link_qopts;
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
		my $opts = join(
			"&amp;", 
			map { $_->[0] . "=" . $_->[1] } 
				@{ $class->list_persistent_options($args) }
		);

		if (!%$qargs) {
			$class->{compiled}{ $args->{class} } = $opts;
		}

		return $opts;
	}
}

#----------

sub list_link_qopts {
	my $class = shift;
	my $tmplt = shift;
	my $args = shift;
	my $qopts = [];

	# find the template object
	my $t = $class->{_}->look->load_template_by_path($tmplt);

	# return an empty list if we get nothing
	return $qopts if (!$t);

	# we get qopts from the template as glomule->opt->name, which is really 
	# pretty backward from what we want.  we need a list of names the foreign 
	# template will accept, and then we need to 

	my $fnames = {};
	while ( my ($g,$gref) = each %{ $t->qopts } ) {
		while ( my ($o,$oref) = each %$gref ) {
			$fnames->{ $oref->{name} } = 1;
		}
	}

	foreach my $n (keys %$fnames) {
		if (my $opt = $class->names->{ $n }) {
			next if (!$opt->persist);

			my $v = exists( $args->{ $n } ) ? 
				$args->{ $n } : $opt->get;

			next if ($v eq $opt->d_value);
			
			push @$qopts, [ $n , $v ];
		} elsif (my $v = $args->{ $n }) {
			push @$qopts, [ $n , $v ];
		} else {
			# ignore this one
		}
	}

	return $qopts;
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
	
				next if ($v eq $opt->d_value);
				push @$qopts, [$opt->{name},$v];
			}
		}
	}

	return $qopts;	
}

#----------

sub _load_foreign_qkeys {
	my $class = shift;
	my $path = shift;

	if (my $c = $class->{qkey_cache}{ $path }) {
		return $c;
	}

	if (my $t = $class->{_}->look->load_template_by_path($path)) {
		return $class->{qkey_cache}{ $path } = $t->qkeys;
	} else {
		return undef;
	}
}

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

		#$val = URI::Escape::uri_unescape($val);
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
		next if (!$v || $v eq "-");
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
