package eThreads::Object::System::Categories;

use eThreads::Object::System -Base;
no warnings;

use eThreads::Object::System::Categories::Category;

#----------

field '_' => -ro;

field 'glomule';
field 'headers'	=> 
	-init=>q!
		$self->_->cache->get(tbl=>"cat_headers",first=>$self->glomule)
			or $self->cache_headers($self->glomule);
	!, -ro;

sub new {
	$self = super;
	my $glomule = shift;

	$self->glomule($glomule);

	return $self;
}

#----------

sub is_valid_name {
	my $cat = shift;

	if (my $c = $self->headers->{ name }{ $cat }) {
		return 1;
	} else {
		return undef;
	}
}

#----------

sub is_valid_id {
	my $cat = shift;

	if (my $c = $self->headers->{ id }{ $cat }) {
		return 1;
	} else {
		return undef;
	}
}

#----------

sub load_by_name {
	my $cat = shift;
	if ( my $c = $self->headers->{ name }{ $cat }) {
		return $self->load( $c->{id} );
	} else {
		return undef;
	}
}

#----------

sub load {
	my $id = shift;

	my $c = $self->headers->{id}{ $id };

	return undef if (!$c);

	my $obj = $self->_->new_object(
		"System::Categories::Category",
		catobj => $self,
		%$c
	);

	return $obj;
}

#----------

sub new_category {
	$self->_->new_object(
		'System::Categories::Category::Writable',
		catobj => $self
	);
}

#----------

sub get_primary {
	my $id = shift;

	# -- make sure we have an id -- #

	$self->_->bail->("Category get_primary called with no id.")
		if (!$id);

	# -- look up primary category -- #

	my $get = $self->_->core->get_dbh->prepare("
		select 
			cat
		from 
			" . $self->_->core->get_tbl("category_primary") . "
		where 
			glomule = ?
			and id = ?
	");

	$get->execute( scalar $self->glomule->id , $id )
		or $self->_->bail->("get_primary failure: " . $get->errstr);

	# -- return undef if we didn't find anything -- #

	return undef if (!$get->rows);

	# -- load our category -- #

	return $self->load( $get->fetchrow_arrayref );
}

#----------

sub load_all {
	my $cats = { name => {} , id => {} };
	while (my ($id,$c) = each %{$self->headers->{id}}) {
		$cats->{name}{ $id } = $cats->{id}{ $c->{id} } 
			= $self->_->new_object(
				"System::Categories::Category",
				%$c
			);
	}

	return $cats;
}

#----------

sub cache_headers {
	my $get = $self->_->core->get_dbh->prepare("
		select 
			id,
			name
		from 
			" . $self->_->core->tbl_name('cat_headers') . "
		where 
			glomule = ?
	");

	$get->execute(scalar $self->glomule->id)
		or $self->_->bail->("cache_cat_headers failure: " . $get->errstr);

	my ($id,$n);
	$get->bind_columns( \($id,$n) );

	my $cat = { name => {} , id => {} };
	while ( $get->fetch ) {
		$cat->{name}{ $n } = $cat->{id}{ $id } = {
			id			=> $id,
			name		=> $n,
			glomule		=> scalar $self->glomule->id
		};
	}

	$self->_->cache->set(
		tbl		=> 'cat_headers',
		first	=> scalar $self->glomule->id,
		ref		=> $cat
	);

	return $cat;
}

#----------

sub f_main {
	my $fobj = shift;

	if (my $name = $fobj->bucket->get('name')) {
		# -- create a new category -- #

		# check to make sure it doesn't exist
		if ($self->is_valid_name( $name )) {
			$fobj->gholders->register("message","Category exists: $name");
		} else {
			my $cat = $self->_->new_object("System::Categories::Category",
				name	=> $name,
				glomule	=> $self->glomule
			)->activate;
		
			$fobj->gholders->register("message","Created category $name");
		}
	}

	# -- load all categories -- #

	my @data;
	my $cats = $self->load_all;
	
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
	my $fobj = shift;

	# -- load -- #

	my $id = $fobj->bucket->get('id');

	my $cat = $self->load($id)
		or $self->_->bail->("couldn't load category: $id");

	# -- check for edits -- #

	if ($fobj->bucket->get('submit')) {

	}

	# -- register -- #

	$fobj->gholders->register('category',$cat->registerable);
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
