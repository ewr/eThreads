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

	$class->{_}->gholders->register(
		"qopt",
		sub { return $class->handle_form_qopt(@_); }
	);

	return $class;
}

#----------

sub handle_form {
	my $class = shift;
	my $i = shift;

	# add initial form statement
	my $flink = $class->{_}->queryopts->link($i->args->{func});

	$_[0] .= 
		qq(<form action=") . 
			$flink . 
		qq(" method=") . 
			$i->args->{method} . 
		qq(">);

	my @keys = keys(%{$i->{args}});

	# make a copy of the args
	my $args = {};
	%$args = %{$i->args};

	# delete func & method
	delete $args->{func};
	delete $args->{method};

	foreach my $c (@{$i->children}) {
		$class->handle_form_qopt($c,$args);
	}

	# now figure out what class opts need to be hidden fields
	my $opts = $class->{_}->queryopts->list_persistent_options($args);

	foreach my $o (@$opts) {
		$_[0] .= 
			qq(<input type="hidden" name=").
				$o->[0].
			qq(" value=").
				URI::Escape::uri_escape($o->[1]).
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

