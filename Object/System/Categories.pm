package eThreads::Object::System::Categories;

use eThreads::Object::System::Categories::Category;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub get_sql_for {
	my $class = shift;
	my $cat = shift;
	
	my $obj = $class->is_valid_cat($cat)
		or $class->{_}->bail->("Invalid category: $cat");

	return $obj->sql;
}

#----------

sub is_valid_cat_name {
	my $class = shift;
	my $cat = shift;

	my $cache = $class->load_all;

	if (my $c = $cache->{ name }{ $cat }) {
		# valid, create an object
		return $class->load($c->{id});
	} else {
		return undef;
	}
}

#----------

sub load {
	my $class = shift;
	my $id = shift;

	if (my $obj = $class->{_}->cache->objects->get("category",$id)) {
		return $obj;
	} else {
		my $cache = $class->load_all;

		my $c = $cache->{id}{ $id };

		return undef if (!$c);

		my $obj = $class->{_}->new_object(
			"System::Categories::Category",
			%$c
		);

		$class->{_}->cache->objects->set("category",$c->{id},$obj);

		return $obj;
	}
}

#----------

sub get_primary {
	my $class = shift;
	my $id = shift;

	# -- make sure we have an id -- #

	$class->{_}->bail->("Category get_primary called with no id.")
		if (!$id);

	# -- make sure we have a glomule -- #

	my $glomule = $class->_get_glomule;

	# -- look up primary category -- #

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			cat
		from 
			" . $class->{_}->core->get_tbl("category_primary") . "
		where 
			glomule = ?
			and id = ?
	");

	$get->execute($glomule,$id)
		or $class->{_}->bail->("get_primary failure: " . $get->errstr);

	# -- return undef if we didn't find anything -- #

	return undef if (!$get->rows);

	# -- load our category -- #

	return $class->load( $get->fetchrow_arrayref );
}

#----------

sub load_all {
	my $class = shift;

	my $glomule = $class->_get_glomule;

	my $c = $class->{_}->cache->get(tbl=>"cat_headers",first=>$glomule);

	if (!$c) {
		$c = $class->cache_headers($glomule);
	}

	return $c;
}

#----------

sub cache_headers {
	my $class = shift;
	my $glomule = shift || $class->_get_glomule;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			name
		from 
			" . $class->{_}->core->tbl_name('cat_headers') . "
		where 
			glomule = ?
	");

	$get->execute($glomule)
		or $class->{_}->bail->("cache_cat_headers failure: " . $get->errstr);

	my ($id,$n);
	$get->bind_columns( \($id,$n) );

	my $cat = { name => {} , id => {} };
	while ( $get->fetch ) {
		$cat->{name}{ $n } = $cat->{id}{ $id } = {
			id			=> $id,
			name		=> $n,
			glomule		=> $glomule
		};
	}

	$class->{_}->cache->set(
		tbl		=> "cat_headers",
		first	=> $glomule,
		ref		=> $cat
	);

	return $cat;
}

#----------

sub _get_glomule {
	my $class = shift;

	if ( my $g = $class->{_}->knows("glomule") ) {
		return $g->id;
	} else {
		$class->{_}->bail->("category functions require a glomule");
	}
}

#----------

sub f_main {
	my $class = shift;
	my $fobj = shift;

	
}

#----------

sub f_edit {
	my $class = shift;
	my $fobj = shift;


}

#----------

sub qopts_main {
	return [

	{
		name	=> "name",
		allowed	=> '.+',
		d_value	=> undef,
	},

	];
}

#----------

sub qopts_edit {
	return [];
}

#----------

=head1 NAME

eThreads::Object::System::Categories

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
