package eThreads::Object::Glomule::PostHooks;

use Spiffy -Base;

field '_'	=> -ro;

const 'OK'		=> 10;
const 'PASS'	=> 5;
const 'FAIL'	=> 0;

sub new {
	my $swb = shift;
	$self = bless { _ => $swb } , $self;

	return $self;
}

#----------

sub register {
	my $hookref = shift;

	return undef if ( ref($hookref) ne "CODE" );

	push @{ $self->{hooks} } , $hookref;

	return 1;
}

#----------

sub hooks {
	wantarray ? @{ $self->{hooks} } : $self->{hooks};
}




