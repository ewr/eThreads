package eThreads::Object::ContentType::HTML;

@ISA = qw( eThreads::Object::ContentType );

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless({
		_		=> $data,
		type	=> "text/html",
	},$class);

	return $class;
}

#----------

sub activate {
	my $class = shift;

	$class->{_}->gholders->register(
		"form",
		sub { return $class->handle_form(@_); }
	);

	#$class->{_}->gholders->register(
	#	"qopt",
	#	sub { return $class->handle_form_qopt(@_); }
	#);

	return $class;
}

#----------

sub handle_form {
	my $class = shift;
	my $i = shift;

	my $tmplt = $i->args->{func};
	$tmplt = "/" . $tmplt if ($tmplt !~ m!^/!);

	# make a copy of the args
	my $args = {};
	%$args = %{$i->args};

	# delete func & method
	delete $args->{func};
	delete $args->{method};

	foreach my $c (@{$i->children}) {
		$class->handle_form_qopt($c,$args);
	}

	my $link = $class->{_}->queryopts->link($i->args->{func},$args);

	my ($flink,$opts) = $link =~ m!([^\?]*)\??(.*)?!s;

	$_[0] .= 
		qq(<form action=") . 
			$flink . 
		qq(" method=") . 
			$i->args->{method} . 
		qq(">);

	foreach my $o (split("&amp;",$opts)) {
		my ($k,$v) = split("=",$o);
		$_[0] .= 
			qq(<input type="hidden" name=").
				$k.
			qq(" value=").
				$v.
			qq("/>);
	}
	
	return 0;
}

#----------

sub handle_form_qopt {
	my $class = shift;
	my $i = shift;
	my $opts = shift;

	# make sure we've got an opts hash to throw into
	return 0 if (ref($opts) ne "HASH");

	my $name = $i->args->{name} || $i->args->{DEFAULT};
	return 0 if (!$name);

	my $v;
	$class->{_}->gholders->handle_template_tree($i,$v);

	$opts->{$name} = $v;
}

#----------

1;

