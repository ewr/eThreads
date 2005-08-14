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

	# now we have to figure out qkeys, qopts, etc.  We do this from a few 
	# different sources.  

	# in order to know what qopts a template will take we create an object 
	# for the linked template and then ask for its qopts.  Internally the 
	# template object will merge the master list of qopts in the Controller 
	# with the name mappings that are stored in the database.  We need to 
	# know what opt keys are available in what functions in what glomules, 
	# and we need to know all of the names that map to opts (both defined 
	# and default) so that we can support linking via opt name


	my $link_qopts;
	{
		# get qopts hashref
		my $qopts = $class->list_link_qopts($tmplt,$args);

		if ( my $qkeys = $class->_load_foreign_qkeys($tmplt) ) {
			my @keys;
			foreach my $k (@$qkeys) {
				push @keys, $qopts->{ $k } || "-";
				delete $qopts->{ $k };
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
		while ( my ($opt,$val) = each %$qopts ) {
			push @qopts, ( $opt . "=" . URI::Escape::uri_escape($val) );
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
	my $qopts = {};

	# TODO: We need a cheap way of recognizing if we're linking to the current 
	# template and just using the already known object to optimize

	# find the template object
	my $t = $class->{_}->look->load_template_by_path($tmplt);

	# return an empty hash if we get nothing
	return $qopts if (!$t);

	# when we call $t->qopts we're going to get a Template::Qopts object. 
	# There are four main indentifiers for a qopt: glomule, function, opt, 
	# and name.  This object will allow us to do a primary sort by any of 
	# those, and then we get a hashref and have to work through the branches 
	# there

	my $all_opts = $t->qopts;

	# we'll next go through each of the names and 
	# look to see if we have a qopt mapped to that name in the current 
	# template that has persist as one of its characteristics and whose 
	# value is other than the default for the qopt.  We set up $qopts as a 
	# hash keyed the same as $fnames, but with proper values.  This hash 
	# will only contain the options that should be passed on in the link.

	foreach my $name ( keys %{ $all_opts->names } ) {
		if (my $opt = $class->names->{ $name }) {
			next if (!$opt->persist);

			my $v = $opt->get;

			next if (!$v || $v eq $opt->default);

			$qopts->{ $name } = $v;
		} else {
			# ignore this one
		}
	}

	# The keys given to us in $args need to be parsed.  We could end up with 
	# any of four elements: name, glomule, function, opt.  We always need 
	# either name or opt, the other two we can guess at

	# $args key         Glomule     Function    Opt Key     Name
	# ----------------------------------------------------------
	# id                -           -           -           id
	# .id               -           -           id          -
	# .view.id          -           view        id          - 
	# comments.view.id  comments    view        id          - 

	while ( my ($k,$v) = each %$args ) {
		if ($k =~ /[^\.]/) {
			# no dot inside means this is a name mapping...  That's easy.  
			# just make sure the linked template can take this name and put 
			# the value in $qopts

			next if ( !$all_opts->names($k) );

			$qopts->{ $k } = $v;
			
		} elsif ( $k =~ /^\.([^\.]+)$/ ) {
			# leading dot with no additional dots means we have an opt key. 
			# $1 contains the opt key.

			my $opts = $all_opts->opt( $1 );

			foreach my $o ( $all_opts->objects_in_tree( $opts ) ) {
				$qopts->{ $o->name } = $v;
			}
		} elsif ( $k =~ /^\.([^\.]+)\.([^\.]+)$/ ) {
			# leading dot, characters, another dot, then characters means we 
			# have a function and an opt key.  
		} else {

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

	# if we don't actually have a name bound we use the opt as our default.
	# if you really don't want this opt to be bound you give it a name of 
	# - and that gets ignored

	my $named = $class->{_}->template->named_qopts;

	my $name = 
		($named->{ $g } && $named->{ $g }{ $o }) 
			? $named->{ $g }{ $o }{name}
			: $o;

	return ($name eq "-") ? undef : $name;
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
