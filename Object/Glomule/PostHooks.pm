package eThreads::Object::Glomule::PostHooks;

use Spiffy -Base;

field '_'	=> -ro;

const 'OK'		=> 10;
const 'PASS'	=> 5;
const 'FAIL'	=> 0;

field 'msg';

sub new {
	my $swb = shift;
	$self = bless { _ => $swb , hooks => [] } , $self;

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

#----------

sub run {
	my $post = shift;
	my $gtype = shift;

	my $status = 1;
	foreach my $h ( $self->hooks ) {
		# run the hook
		my ($s,$msg) = $h->( $self , $post , $gtype );

		if ($s == $self->OK || $s == $self->PASS ) {
			# cool, next
			next;
		} else {
			$self->msg($msg);
			$status = 0;
			last;
		}
	}

	if ($status) {
		# we're cool
		return $self->OK;
	} else {
		return $self->FAIL;
	}
}




