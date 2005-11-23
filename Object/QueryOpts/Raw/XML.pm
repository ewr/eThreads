package Object::QueryOpts::Raw::XML;

use Spiffy -Base;
no warnings;

field '_' => -ro;

sub new {
	my $data = shift;

	$self = bless { _ => $data } , $self;

	return $self;
}

sub set {

}

sub get {

}
