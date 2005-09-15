package eThreads::Object::Template::Writable;

use eThreads::Object::Template -Base;

const 'CAN_SET_TYPE' => 1;

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

		if ($self->CAN_SET_TYPE) {
			# allow type update
			$self->_->utils->set_value(
				tbl		=> $self->TABLE,
				keys	=> {
					id	=> $self->id
				},
				value_field	=> 'type',
				value		=> $self->type,
			);
		}

		warn "calling set_value on tbl " . $self->TABLE . " with value: " . $self->value . "\n";

		# update content
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

		# double-check that our path isn't used
		if ( $self->look->has_template_by_path( $self->path ) ) {
			$self->_->bail->(
				'Template with path "'.$self->path.'" already exists.'
			);
		} 

		if ( $self->CAN_SET_TYPE ) {
			$self->_->utils->set_value(
				tbl			=> $self->TABLE,
				keys		=> {
					name	=> $self->path,
					look	=> $self->look->id,
					c_type	=> $self->{type}
				},
				value		=> $self->value
			);
		} else {
			$self->_->utils->set_value(
				tbl			=> $self->TABLE,
				keys		=> {
					name	=> $self->path,
					look	=> $self->look->id,
				},
				value		=> $self->value
			);
		}

		# update time on templates for the look
		$self->_->cache->update_times->set(
			tbl		=> $self->TABLE,
			first	=> $self->look->id
		);

		# undef the template map if it exists
		# FIXME: there should be a less intrusive way to do this
		undef $self->look->{ $self->TABLE };

		# get our id
		my $id = $self->look->has_template_path_in_table( 
			$self->TABLE, 
			$self->path 
		) or $self->_->bail->("Couldn't get id for new template.");

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
