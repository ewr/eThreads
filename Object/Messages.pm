package eThreads::Object::Messages;

use strict;

#----------

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless({
		_			=> $data,
		messages	=> undef,
	},$class);

	return $class;
}

#----------

sub bail {
	my $class = shift;
	my $err = shift;

	warn time . ": $err\n";
	$class->print("ERROR",$err);
}

#----------

sub print {
	my $class = shift;
	my $name = shift;
	my $text = shift;

	# prevent recursion
	if ($class->{STATUS}) {
		die "recursion in message print.";
	} else {
		$class->{STATUS} = 1;
	}

	my $msgs = $class->load_messages;

	my $msg = $msgs->{ $name } || $msgs->{ERROR};

	$msg =~ s!#TEXT#!$text!;

	$class->{_}->ap_request->content_type('text/html');
	$class->{_}->ap_request->print($msg);

	exit;
}

#----------

sub load_messages {
	my $msgs = $self->_->cache->get(tbl=>"messages");

	if (!$msgs) {
		$msgs = $self->cache_messages;
	}

	return $msgs;
}

#----------

sub cache_messages {
	my $get = $self->_->core->get_dbh->prepare("
		select 
			ident,value
		from 
			" . $self->_->core->tbl_name("messages") . "
	");

	$get->execute() 
		or die "error in cache_messages: " . $get->errstr . "\n";

	my ($ident,$value);
	$get->bind_columns( \($ident,$value) );

	my $msgs = {};
	while ($get->fetch) {
		$msgs->{ $ident } = $value;
	}

	return $msgs;
}

#----------

=head1 NAME

eThreads::Object::Messages

=head1 SYNOPSIS

	use eThreads::Object::Messages;

	my $obj = $inst->new_object("Messages");

	$obj->print("MsgName","my message");

=head1 DESCRIPTION

At various times eThreads will need to print some sort of a message to the 
user.  Examples might include when bail is called, and an error needs to be 
printed, or when a user does not successfully authenticate.  The Messages 
system allows standard message templates to be defined at the top-level that 
can optionally be overwritten on the container level.

=over 4

=item new 

	my $obj = $inst->new_object("Messages");

Returns a Messages object.  Should be called through Instance's new_object 
interface so that it can call back to Instance.

=item bail

	$obj->bail("error message");

	$self->_->bail->("error message");

This is a special case that uses the ERROR Message.  It will usually be 
registered as "bail" with the switchboard.  Note that for the switchboard 
usage you need the extra dereference.

=item print 

	$obj->print("MsgName","my msg text");

Prints a message, including content type if needed.  Does not exit after 
printing...  You'll need to do that yourself and supply the appropriate 
status code.  B<MsgName> is the name of the error message.  The appropriate 
template for this message will be loaded.  The second argument is your 
msg text, if that's appropriate for this message.

=item load_messages 

	my $msgs = $obj->load_messages;

Loads appropriate messages for the container.  Usually you'll just let 
print call this for you.  Returns a reference to the messages hash.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.

=cut

1;
