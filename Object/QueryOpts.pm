package eThreads::Object::QueryOpts;

use strict;

use eThreads::Object::QueryOpts::Bucket;
use eThreads::Object::QueryOpts::QueryOption;
use eThreads::Object::QueryOpts::Raw;

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

	$class->load_qkeys_to_input;

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;
}

#----------

sub new_bucket {
	return shift->{_}->instance->new_object('QueryOpts::Bucket',@_);
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
		#warn "multiple binds to $name -- IGNORING\n";
	}
}

#----------

sub names {
	return shift->{names};
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
		$class->{_}->domain->path,
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
		%$h_qopts = map { $_->[0] => $_ } @$qopts;
		
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
			push @qopts, ( $q->[0] . "=" . URI::Escape::uri_escape($q->[1]) );
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

			next if (!$v || $v eq $opt->d_value);
			
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

	return $class->{_}->raw_queryopts->get(@_);
}

#----------

sub get_from_input {
	my $class = shift;
	my %a = @_;

	my $name = $class->get_name_for_opt($a{glomule},$a{opt}) 
		or return undef;

	# return what we find on input
	return $class->{_}->raw_queryopts->get($name);
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

sub load_qkeys_to_input {
	my $class = shift;

	my $qkeys = $class->{_}->RequestURI->unclaimed;

	my @parts = split("/",$qkeys);
	
	# ignore an empty first part since we get a / first
	shift @parts if (!$parts[0]);

	foreach my $k (@{ $class->{_}->template->qkeys }) {
		my $v = shift @parts;
		next if (!$v || $v eq "-");

		$class->{_}->raw_queryopts->set($k,$v);
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
