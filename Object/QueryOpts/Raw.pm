package eThreads::Object::QueryOpts::Raw;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		input	=> undef,
	} , $class );

	$class->{input} = $class->load;

	return $class;
}

#----------

sub set {
	my $class = shift;
	my $arg = shift;
	my $v = shift;

	$class->{ input }{ $arg } = $v;

	return 1;
}

#----------

sub get {
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

sub load {
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

=head1 NAME

eThreads::Object::QueryOpts::Raw

=head1 DESCRIPTION

=head1 SYNOPSIS

=cut

1;
