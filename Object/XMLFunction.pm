package eThreads::Object::XMLFunction;

use Spiffy -Base;
no warnings;

field '_' => -ro;

sub new {
	my $data = shift;
	$self = bless { _ => $data } , $self;

	return $self;
}

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

sub determine_function {
	$self->_->bail->("In determine_function for XMLFunction");
}

