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
	my $glomule = shift;
	my $cat = shift;
	
	my $obj = $class->is_valid_cat($glomule,$cat)
		or $class->{_}->bail->("Invalid category: $cat");

	return $obj->sql;
}

#----------

sub is_valid_name {
	warn "args: @_\n";
	my $class = shift;
	my $glomule = shift;
	my $cat = shift;

	warn "looking for cat $cat on glomule $glomule\n";

	my $cache = $class->get_headers($glomule);

	if (my $c = $cache->{ name }{ $cat }) {
		# valid, create an object
		return $class->load($glomule,$c->{id});
	} else {
		return undef;
	}
}

#----------

sub load {
	my $class = shift;
	my $glomule = shift;
	my $id = shift;

	my $cache = $class->get_headers($glomule);

	my $c = $cache->{id}{ $id };

	return undef if (!$c);

	my $obj = $class->{_}->new_object(
		"System::Categories::Category",
		%$c
	);

	return $obj;
}

#----------

sub get_primary {
	my $class = shift;
	my $glomule = shift;
	my $id = shift;

	# -- make sure we have an id -- #

	$class->{_}->bail->("Category get_primary called with no id.")
		if (!$id);

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

sub get_headers {
	my $class = shift;
	my $glomule = shift;

	my $c = $class->{_}->cache->get(tbl=>"cat_headers",first=>$glomule);

	if (!$c) {
		$c = $class->cache_headers($glomule);
	}

	return $c;
}

#----------

sub load_all {
	my $class = shift;
	my $glomule = shift;

	my $headers = $class->get_headers($glomule);

	my $cats = { name => {} , id => {} };
	while (my ($id,$c) = each %{$headers->{id}}) {
		$cats->{name}{ $id } = $cats->{id}{ $c->{id} } 
			= $class->{_}->new_object(
				"System::Categories::Category",
				%$c
			);
	}

	return $cats;
}

#----------

sub cache_headers {
	my $class = shift;
	my $glomule = shift;

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

sub f_main {
	my $class = shift;
	my $fobj = shift;

	my $glomule = $fobj->glomule->id;

	if (my $name = $fobj->bucket->get('name')) {
		# -- create a new category -- #

		# check to make sure it doesn't exist
		if ($class->is_valid_name( $glomule , $name )) {
			$fobj->gholders->register("message","Category exists: $name");
		} else {
			my $cat = $class->{_}->new_object("System::Categories::Category",
				name	=> $name,
				glomule	=> $fobj->glomule->id
			)->activate;
		
			$fobj->gholders->register("message","Created category $name");
		}
	}

	# -- load all categories -- #

	my @data;
	my $cats = $class->load_all($glomule);
	
	while (my ($id,$c) = each %{ $cats->{id} }) {
		push @data, [ 'categories.' . $id , $c->registerable ];
	}

	$fobj->gholders->register(
		[ 'categories' , [ map { $_->[1]{id} } @data ] ],
		@data
	);
}

#----------

sub f_edit {
	my $class = shift;
	my $fobj = shift;

	my $glomule = $fobj->glomule->id;

	# -- load -- #

	my $id = $fobj->bucket->get('id');

	my $cat = $class->load($glomule,$id)
		or $class->{_}->bail->("couldn't load category: $id");

	# -- check for edits -- #

	if ($fobj->bucket->get('submit')) {

	}

	# -- register -- #

	$fobj->gholders->register('category',$cat->registerable);
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
