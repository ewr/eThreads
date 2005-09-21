package eThreads::Object::Look::Writable;

use eThreads::Object::Look -Base;

#----------

field 'name';

#----------

sub write {
	if ( $self->id ) {
		# updating existing look
	} else {
		# creating a new look
		if (!$self->name) {
			$self->_->bail->("Can't write look without a name.");
		}
	}
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
