package eThreads::Object::DB;

use DBI;
use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless({
		_		=> $data,
	},$class);

	return $class;
}

#----------

sub connect {
	my $class = shift;

	$class->{h} = DBI->connect(
		"DBI:".
		$class->{_}->settings->{db}{type} .":".
		$class->{_}->settings->{db}{db} . ":".
		$class->{_}->settings->{db}{host}, 
		$class->{_}->settings->{db}{user},
		$class->{_}->settings->{db}{pass}
	) or die "could not connect to db: $!";

	return $class->{h};
}

#----------

sub get_dbh {
	return shift->{h};
}

#----------

sub get_next_id {
	my $next_id = 0;
	return $next_id;
}

#----------

sub get_message_id {
	my $class = shift;
	my $id = $class->{h}->{'mysql_insertid'};
	warn "no insertid found on $class->{h}!\n" if (!$id);
	return $id;
}

1;
