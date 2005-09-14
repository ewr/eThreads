package eThreads::Object::Template::Writable;

use eThreads::Object::Template -Base;

field 'look';
field 'id';
field 'path';
field 'value';

sub type {
	if ($_[0]) {
		$self->{type} = shift;
		$self->{type_obj} = 
			$self->_->new_object('ContentType::'.$self->{type})->activate
	}

	return $self->{type_obj};
}

sub write {
	if (!$self->look) {
		$self->_->bail->('Unable to write template without a look');
	} elsif ( !ref($self->look) ) {
		# we might have a look id that we need to make into a look object
		my $look = $self->_->new_object('Look',id=>$self->look);
	}

	if ($self->id) {
		# we're updating an existing template
		warn "updating existing " . $self->id . "\n";

		$self->_->utils->set_value(
			tbl		=> $self->TABLE,
			keys	=> {
				id	=> $self->id
			},
			value	=> $self->value,
		);

		$self->_->cache->update_times->set(
			tbl		=> $self->TABLE,
			first	=> $self->look->id,
			second	=> $self->id
		);

		return $self;
	} else {
		# we're inserting a new template
		warn "inserting new template\n";

		# double-check that our path isn't used
		if ( $self->look->has_template_by_path( $self->path ) ) {
			$self->_->bail->(
				'Template with path "'.$self->path.'" already exists.'
			);
		} 

		$self->_->utils->set_value(
			tbl			=> $self->TABLE,
			keys		=> {
				name	=> $self->path,
				look	=> $self->look->id,
				c_type	=> $self->{type}
			},
			value		=> $self->value
		);

		# update time on templates for the look
		$self->_->cache->update_times->set(
			tbl		=> $self->TABLE,
			first	=> $self->look->id
		);

		# get our id
		my $id = $self->look->has_template_by_path( $self->path )
			or $self->_->bail->("Couldn't get id for new template.");

		$self->id( $id );

		# now update time for our template
		$self->_->cache->update_times->set(
			tbl		=> $self->TABLE,
			first	=> $self->look->id,
			second	=> $self->id
		);

		return $self;
	}
}