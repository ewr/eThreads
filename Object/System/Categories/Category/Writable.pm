package eThreads::Object::System::Categories::Category::Writable;

use eThreads::Object::System::Categories::Category -Base;
no warnings;

#----------

field '_' => -ro;

field 'id'		=> -ro;
field 'glomule'	=> -ro;
field 'name';

sub write {
	if ( $self->id ) {

	} else {
		# name is required to be unique...  make sure this name doesn't exist
		if ( $self->catobj->is_valid_name( $self->name ) ) {
			# already exists...
			$self->_->bail->('Unable to write category: Name already exists.');
		}

		my $insert = $self->_->core->get_dbh->prepare("
			insert into " . $self->_->core->tbl_name('cat_headers') . "
				(id,glomule,name)
			values(0,?,?)
		");

		$insert->execute( $self->glomule , $self->name )
			or $self->_->bail->('Unable to write category: ' . $insert->errstr);

		$self->_->cache->update_times->set(
			tbl		=> 'cat_headers',
			first	=> $self->glomule
		);

		# now find our id

		# TODO: agh..  invasive
		undef $self->catobj->{headers};

		my $id = $self->catobj->headers->{name}{ $self->name }
			or $self->_->bail->('Wrote category, but unable to get ID.');

		$self->{id} = $id;

		return 1;
	}
}

#----------

sub delete {
	if ( !$self->id ) {
		return undef;
	}

	
}

#----------

sub write_data {
	if ( !$self->id ) {
		return undef;
	}

	while ( my ($k,$v) = each %{ $self->{data} } ) {
		$self->_->utils->set_value(
			tbl		=> 'cat_data',
			keys	=> {
				id		=> $self->glomule,
				ident	=> $k
			},
			value	=> $v
		);
	}

	$self->_->cache->update_times->set(
		tbl		=> 'cat_data',
		first	=> $self->glomule,
		second	=> $self->id
	);

	return 1;
}
