package eThreads::Object::System::XMLFunction;

use eThreads::Object::System -Base;
no warnings;

#----------

sub uri_has_xml_prefix {
	my $unclaimed = $self->_->RequestURI->unclaimed;

	my $xmlprefix = $self->_->settings->{xml_prefix};

	if ( 
		my ($prefix) = $unclaimed =~ 
			m!
				(
					/?
					$xmlprefix
					/
				)
			!x
	) {
		$self->_->RequestURI->claim($prefix);
		return 1;
	} else {
		return undef;
	}
}

#----------

sub f_handle_xmlfunction {
	my $fobj = shift;

	# -- we need a new queryopts 

	$self->_->bail->('in f_handle_xmlfunction');	
}

