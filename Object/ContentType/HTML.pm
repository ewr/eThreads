package eThreads::Object::ContentType::HTML;

use eThreads::Object::ContentType -Base;

#----------

const 'type' => 'text/html';

sub new {
	my $data = shift;

	$self = bless({
		_		=> $data,
	},$self);

	return $self;
}

#----------

sub activate {
	$self->_->gholders->register(
		"form",
		sub { return $self->handle_form(@_); }
	);

	#$self->_->gholders->register(
	#	"qopt",
	#	sub { return $self->handle_form_qopt(@_); }
	#);

	return $self;
}

#----------

sub handle_form {
	my $i = shift;

	my $tmplt = $i->args->{func};
	$tmplt = "/" . $tmplt if ($tmplt !~ m!^/!);

	# make a copy of the args
	my $args = {};
	%$args = %{$i->args};

	# delete func & method
	delete $args->{func};
	delete $args->{method};

	while ( my $c = $i->children->next ) {
		$self->handle_form_qopt($c,$args);
	}

	my $link = $self->_->queryopts->link($i->args->{func},$args);

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
	my $i = shift;
	my $opts = shift;

	# make sure we've got an opts hash to throw into
	return 0 if (ref($opts) ne "HASH");

	my $name = $i->args->{name} || $i->args->{DEFAULT};
	return 0 if (!$name);

	my $v;
	$self->_->gholders->handle_template_tree($i,$v);

	$opts->{$name} = $v;
}

#----------

1;

