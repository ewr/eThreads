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

sub print {
	my $class = shift;

	my $msgs = $class->{messages} || $class->load_messages;


}

#----------

sub load_messages {
	my $class = shift;

	

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

Copyright (c) 1999-2004 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.

=cut

1;
