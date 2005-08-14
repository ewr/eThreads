package eThreads::Object::System::Categories::Category;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
		name	=> undef,
		id		=> undef,
		glomule	=> undef,
		data	=> {
			icon		=> undef,
			descript	=> undef,
		},
		@_,
	} , $class ); 

	if (!$class->{name} || !$class->{glomule}) {
		$class->{_}->bail->("Improperly initialized category.");
	}

	return $class;
}

#----------

sub activate {
	my $class = shift;

	if (!$class->id) {
		$class->initialize;
	}

	$class->load_data;

	return $class;
}

#----------

sub id {
	return shift->{id};
}

#----------

sub name {
	return shift->{name};
}

#----------

sub data {
	my $class = shift;
	my $ident = shift;

	return $class->{data}{ $ident };
}

#----------

sub registerable {
	my $class = shift;

	return {
		id		=> $class->{id},
		name	=> $class->{name},
		%{$class->{data}}
	};
}

#----------

sub sql {
	my $class = shift;

}

#----------

sub initialize {
	my $class = shift;

	# -- prep work -- #

	# clean up our name
	$class->{name} =~ s!(?:^\W*|\W$)!!g;

	# -- check for duplicate -- #

	# make sure category with this name doesn't already exist
	my $check = $class->{_}->core->get_dbh->prepare("
		select
			id
		from 
			" . $class->{_}->core->tbl_name('cat_headers') . "
		where 
			glomule = ?
			and name = ?
	");

	$check->execute($class->{glomule},$class->{name}) 
		or $class->{_}->bail->("category init check failed:".$check->errstr);
	
	if ($check->rows) {
		$class->{_}->bail->(
			"Can't init category -- already exists: $class->{name}"
		);
	}

	# -- continue with category initialization -- #

	my $create = $class->{_}->core->get_dbh->prepare("
		insert into 
			" . $class->{_}->core->tbl_name('cat_headers') . "
		(id,glomule,name) 
		values(0,?,?)
	");

	$create->execute($class->{glomule},$class->{name}) 
		or $class->{_}->bail->("category init create failed: ".$create->errstr);

	# FIXME - this is a MySQL specific hack
	$class->{id} = $create->{'mysql_insertid'};

	# -- update ts for cat_headers -- #

	$class->{_}->cache->update_times->set(
		tbl		=> "cat_headers",
		first	=> $class->{glomule},
	);

	return $class->{id};
}

#----------

sub load_data {
	my $class = shift;

	my $data = $class->{_}->cache->get(
		tbl		=> "cat_data",
		first	=> $class->{glomule},
	);

	while ( my ($k,$v) = each %{ $data->{ $class->id } } ) {
		next if ($class->{data}{$k});
		$class->{data}{$k} = $v;
	}

	return $class->{data};
}

#----------

=head1 NAME

eThreads::Object::System::Categories::Category

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
