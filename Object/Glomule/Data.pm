package eThreads::Object::Glomule::Data;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		id			=> undef,
		name		=> undef,
		controller	=> undef,
		system		=> {},
		data		=> {},
		@_,
		_			=> $data,
	} , $class ); 

#	if (!$class->{name}) {
#		$class->{_}->bail->("Invalid glomule data init: no name");
#	}

	if (!$class->{type}) {
		$class->{_}->bail->("Invalid glomule data init: no type");
	}

	if (!$class->{controller}) {
		$class->{_}->bail->("Invalid glomule data init: no controller");
	}

	return $class;
}

#----------

sub DESTROY {
	my $class = shift;

	undef $class->{controller};
	%{$class->{system}} = ();
	undef $class->{system};
	%{$class->{prefs}} = ();
	undef $class->{prefs};
	
}

#----------

sub activate {
	my $class = shift;

	$class->load_info;

	# -- load systems -- #

	foreach my $s ( $class->controller->systems ) {
		my $obj 
			= $class->{system}{ $s->name } 
				= $class->{_}->system->load($s->object);

		$class->{_}->objects->activate($obj);
	}

	# -- register prefs -- #

	$class->register_prefs( scalar $class->controller->prefs );

	return $class;
}

#----------

sub has_function {
	my $class = shift;
	my $func = shift;

	# strip any leading slashes
	$func =~ s!^/!!;

	if (my $f = $class->controller->has_function($func)) {
		my $fobj = $class->{_}->new_object(
			'Glomule::Function',
			$class, 
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

sub connect_to_gholders {
	my $class = shift;
	my $gholders = shift;

	$class->{gholders} = $gholders;

	return 1;
}

#----------

sub gholders {
	shift->{gholders};
}

#----------

sub controller {
	shift->{controller};
}

#----------

sub system {
	my $class = shift;
	my $sys = shift;

	$class->{system}{ $sys };
}

#----------

sub type {
	shift->{type};
}

#----------

sub name {
	shift->{name};
}

#----------

sub data {
	my $class = shift;
	my $name = shift;
	return $class->{data}{$name};
}

#----------

sub register_data {
	my $class = shift;
	my $name = shift;
	my $value = shift;

	$class->{_}->utils->set_value(
		tbl		=> "glomule_data",
		keys	=> {
			ident	=> $name,
			id		=> scalar $class->id,
		},
		value	=> $value,
	);

	$class->{_}->cache->update_times->set(
		tbl		=> "glomule_data",
		first	=> scalar $class->id,
		ts		=> time,
	);

	$class->{data}{ $name } = $value;

	return 1;
}

#----------

sub id {
	my $class = shift;

	if ($class->{id}) {
		if ( wantarray ) {
			my $gh = $class->{_}->glomule->load_headers;
			return ( $class->{id} , $gh->{id}{ $class->{id} } );
		} else {
			return $class->{id};
		}
	} else {
		$class->{_}->glomule->name2id($class->{name});
	}
}

#----------

sub load_info {
	my $class = shift;

	if (!$class->{name}) {
		# try the default name
		$class->{name} = $class->controller->default;
	}

	# -- figure out our id -- #

	my ($id,$gh) = $class->id;

	if (!$id) {
		# we need to create our glomule
		$class->initialize;

		# now we get this again, since we're too lazy to get the 
		# object elsewise
		($id,$gh) = $class->id;
	}

	# -- load glomule data -- #

	my $gd = $class->{_}->cache->get(
		tbl		=> "glomule_data",
		first	=> $id,
	);

	if (!$gd) {
		$gd = $class->{_}->glomule->cache_data(
			$id
		);
	}
		
	# -- load these values into our object -- #

	foreach my $h ($gh,$gd) {
		while ( my ($k,$v) = each %$h ) {
			next if ($class->{data}{$k});
			$class->{data}{$k} = $v;
		}
	}

	return 1;
}

#----------

sub initialize {
	my $class = shift;

	# ok, we need to create an entry in glomule_headers and get an id 
	# for our efforts

	my $ins = $class->{_}->core->get_dbh->prepare("
		insert into 
			" . $class->{_}->core->tbl_name("glomule_headers") . "
		(id,container,name,natural_type,parent) 
		values(0,?,?,?,?)
	");

	$ins->execute(
		$class->{_}->container->id,
		$class->{name},
		$class->TYPE,
		0
	) or $class->{_}->bail->("couldn't init glomule: " . $ins->errstr);

	$class->{_}->cache->update_times->set(
		tbl	=> "glomule_headers",
		ts	=> time,
	);

	# -- now create tables -- #

	$class->create_tables;

	return 1;
}

#----------

sub create_tables {
	my $class = shift;
	
	# -- create headers tbl -- #

	my $headers = $class->{_}->utils->create_table(
		$class->{_}->utils->get_unused_tbl_name("glomheaders"),
		$class->header_fields
	);

	$class->register_data("headers",$headers);

	# -- now create data tbl -- #

	my $data = $class->{_}->utils->create_table(
		$class->{_}->utils->get_unused_tbl_name("glomdata"),
		$class->_data_tbl_fields,
	);

	$class->register_data("data",$data);
}

#----------

sub register_prefs {
	my $class = shift;
	my $prefs = shift;

	foreach my $p (@$prefs) {
		my $obj = $class->{_}->new_object("Glomule::Pref")->init($p);
		$class->{prefs}{ $p->{name} } = $obj;
	}

	return $class;
}

#----------

sub load_prefs {
	my $class = shift;

	my $core = $class->{_}->core;

	# -- first load glomule-wide prefs -- #

	my $gp = $class->{_}->cache->get(
		tbl		=> "prefs",
		first	=> $class->{id},
	);

	if (!$gp) {
		$gp = $class->cache_glomule_prefs;
	}

	# -- next load look-specific prefs -- #

	my $lp = $class->{_}->cache->get(
		tbl		=> "prefs",
		first	=> $class->{id},
		second	=> $class->{_}->look->id
	);

	if (!$lp) {
		$lp = $class->cache_look_prefs;
	}

	foreach my $ps ($gp,$lp) {
		while ( my ($k,$v) = each %$ps ) {
			my $obj = $class->pref($k);
			next if (!$obj);
			$obj->set($v);
		}
	}

	return $class;
}

#----------

sub pref {
	my $class = shift;
	my $pref = shift;

	return $class->{prefs}{ $pref };
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
