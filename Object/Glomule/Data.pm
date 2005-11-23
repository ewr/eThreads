package eThreads::Object::Glomule::Data;

use Spiffy -Base;

use Scalar::Util;

use eThreads::Object::Glomule::PostHooks;

#----------

field '_' => -ro;
field 'gholders';
field 'controller'	=> -ro;
field 'type'		=> -ro;
field 'name'		=> -ro;

field 'posthooks'	=> 
	-ro, 
	-init=>q!$self->_->new_object('Glomule::PostHooks')!;

field 'buckets'		=> [];

sub new {
	my $data = shift;

	$self = bless ( {
		id			=> undef,
		name		=> undef,
		controller	=> undef,
		system		=> {},
		data		=> {},
		@_,
		_			=> $data,
	} , $self ); 

#	Scalar::Util::weaken( $self->{controller} );

	if (!$self->{type}) {
		$self->{_}->bail->("Invalid glomule data init: no type");
	}

	if (!$self->{controller}) {
		$self->{_}->bail->("Invalid glomule data init: no controller");
	}

	return $self;
}

sub new_bucket {
	my $b = $self->_->new_object('Glomule::Data::Bucket');
	push @{ $self->buckets } , $b;
	$b;
}

#----------

sub DESTROY {
	undef $self->{controller};
	%{$self->{system}} = ();
	undef $self->{system};
	%{$self->{prefs}} = ();
	undef $self->{prefs};
}

#----------

sub activate {
	$self->load_info;

	# -- load systems -- #

	foreach my $s ( $self->controller->systems ) {
		my $obj 
			= $self->{system}{ $s->name } 
				= $self->{_}->system->load($s->object,$self);

		$self->{_}->objects->activate($obj);
	}

	# -- register prefs -- #

	$self->register_prefs( scalar $self->controller->prefs );

	return $self;
}

#----------

sub has_function {
	my $func = shift;

	# strip any leading slashes
	$func =~ s!^/!!;

	if (my $f = $self->controller->has_function($func)) {
		my $fobj = $self->{_}->new_object(
			'Glomule::Function',
			$self, 
			{
				name	=> $f->name,
				object	=> $f->object,
				system	=> $f->system,
				sub		=> $f->sub,
				qopts	=> [ map { $_->attributes } $f->qopts ],
				modes	=> [ map { $_->name => $_->value } $f->modes ],
			}
		);
	} else {
		return undef;
	}
}

#----------

sub system {
	my $sys = shift;
	$self->{system}{ $sys };
}

#----------

sub data {
	my $name = shift;
	return $self->{data}{$name};
}

#----------

sub register_data {
	my $name = shift;
	my $value = shift;

	$self->{_}->utils->set_value(
		tbl		=> "glomule_data",
		keys	=> {
			ident	=> $name,
			id		=> scalar $self->id,
		},
		value	=> $value,
	);

	$self->{_}->cache->update_times->set(
		tbl		=> "glomule_data",
		first	=> scalar $self->id,
		ts		=> time,
	);

	$self->{data}{ $name } = $value;

	return 1;
}

#----------

sub id {
	if ($self->{id}) {
		if ( wantarray ) {
			my $gh = $self->{_}->glomule->headers;
			return ( $self->{id} , $gh->{id}{ $self->{id} } );
		} else {
			return $self->{id};
		}
	} else {
		$self->_->container->glomule_n2id( $self->{name} );
	}
}

#----------

sub load_info {
	if (!$self->{name}) {
		# try the default name
		$self->{name} = $self->controller->default;
	}

	# -- figure out our id -- #

	my ($id,$gh) = $self->id;

	if (!$id) {
		# we need to create our glomule
		$self->initialize;

		# now we get this again, since we're too lazy to get the 
		# object elsewise
		($id,$gh) = $self->id;
	}

	# -- load glomule data -- #

	my $gd = $self->{_}->cache->get(
		tbl		=> "glomule_data",
		first	=> $id,
	);

	if (!$gd) {
		$gd = $self->{_}->glomule->cache_data(
			$id
		);
	}
		
	# -- load these values into our object -- #

	foreach my $h ($gh,$gd) {
		while ( my ($k,$v) = each %$h ) {
			next if ($self->{data}{$k});
			$self->{data}{$k} = $v;
		}
	}

	return 1;
}

#----------

sub initialize {
	# ok, we need to create an entry in glomule_headers and get an id 
	# for our efforts

	my $ins = $self->{_}->core->get_dbh->prepare("
		insert into 
			" . $self->{_}->core->tbl_name("glomule_headers") . "
		(id,container,name,natural_type,parent) 
		values(0,?,?,?,?)
	");

	my $typeobj = $self->_->glomule->typeobj( $self->type );

	$ins->execute(
		$self->{_}->container->id,
		$self->{name},
		$self->type,
		0
	) or $self->{_}->bail->("couldn't init glomule: " . $ins->errstr);

	$self->{_}->cache->update_times->set(
		tbl	=> "glomule_headers",
		ts	=> time,
	);

	# FIXME: this is invasive.  cache needs to handle this somehow on update
	undef $self->_->glomule->{headers};

	# -- now create tables -- #

	$typeobj->create_tables($self);

	return 1;
}

#----------

sub register_prefs {
	my $prefs = shift;

	foreach my $p (@$prefs) {
		my $obj = $self->{_}->new_object("Glomule::Pref")->init($p);
		$self->{prefs}{ $p->{name} } = $obj;
	}

	return $self;
}

#----------

sub load_prefs {
	my $core = $self->{_}->core;

	# -- first load glomule-wide prefs -- #

	my $gp = $self->{_}->cache->get(
		tbl		=> "prefs",
		first	=> $self->{id},
	);

	if (!$gp) {
		$gp = $self->cache_glomule_prefs;
	}

	# -- next load look-specific prefs -- #

	my $lp = $self->{_}->cache->get(
		tbl		=> "prefs",
		first	=> $self->{id},
		second	=> $self->{_}->look->id
	);

	if (!$lp) {
		$lp = $self->cache_look_prefs;
	}

	foreach my $ps ($gp,$lp) {
		while ( my ($k,$v) = each %$ps ) {
			my $obj = $self->pref($k);
			next if (!$obj);
			$obj->set($v);
		}
	}

	return $self;
}

#----------

sub pref {
	my $pref = shift;

	return $self->{prefs}{ $pref };
}

#----------

sub cache_glomule_prefs {
	return {};
}

#----------

sub cache_look_prefs {
	return {};
}

#----------

=head1 NAME

eThreads::Object::Glomule::Data

=head1 SYNOPSIS

=head1 DESCRIPTION


=over 4


=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
