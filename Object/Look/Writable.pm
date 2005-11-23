package eThreads::Object::Look::Writable;

use eThreads::Object::Look -Base;

#----------

field 'name';

#----------

sub write {
	if ( !$self->container ) {
		# can't do this
		$self->_->bail->('Unable to write look without container');
	} elsif ( !ref( $self->container ) ) {
		# might have a container id...  let's load the container
	}


	if ( $self->id ) {
		# updating existing look

		warn "wanted to update\n";
		return undef;
		
		# set name
		$self->_->utils->set_value(
			tbl		=> 'looks',
			keys	=> {
				id	=> $self->id,
			},
			value_field		=> 'name',
			value			=> $self->name
		);
	} else {
		# creating a new look
		if (!$self->name) {
			$self->_->bail->("Can't write look without a name.");
		}

		# make sure we have a name
		if ( !$self->name ) {
			$self->_->bail->('Unable to write look without a name.');
		}

		# make sure we don't already have a look with this name
		if ( $self->container->is_valid_look_name( $self->name ) ) {
			$self->_->bail->('Unable to write look: duplicate name');
		}

		$self->_->utils->set_value(
			tbl		=> 'looks',
			keys	=> {
				container	=> $self->container->id,
				name		=> $self->name,
			},
			value_field	=> 'type',
			value		=> 'NORMAL',
		);
	}

	# undef the looks in the container
	undef $self->container->{ looks };

	# set our update time
	$self->_->cache->update_times->set(
		tbl		=> 'looks',
		first	=> $self->container->id
	);
}

#----------

sub delete {
	if ( $self->id ) {
		# delete our templates

		# delete our look record
		
	} else {
		# nothing to do here.
		return undef;
	}
}
