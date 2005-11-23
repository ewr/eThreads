package eThreads::Object::Plugin;

use Spiffy -Base;

#----------

field '_'	=> -ro;
field 'i'	=> -ro;
field 'cfg';

sub new {
	my $data = shift;

	$self = bless ( {
		@_,
		_		=> $data,
	} , $self ); 

	return $self;
}

#----------

sub load {
	my $type = shift;

	my $plugin = $self->_->settings->{plugins}{ $type };

	return undef if (!$plugin);

	my $pkg = "eThreads::Object::Plugin::$plugin";
	eval "require $pkg";
	my $o = $self->_->switchboard->new_object('Plugin::'.$plugin,@_);

	if (my $cfg = $self->_->settings->{plugin_cfg}{ $plugin }) {
		$o->cfg($cfg);
	}

	return $o;
}

#----------

#----------

=head1 NAME

eThreads::Object::Plugin

=head1 DESCRIPTION

This is the generic plugin interface.  It can't be used directly, but will 
be supersetted by plugin objects.

=head1 CREATING PLUGINS

To create a plugin, make an object like eThreads::Object::Plugin::Foo.  The 
plugin should have an activate function, and this is where you'll create / 
register / do / whatever your functionality.  Your object will be given a 
custom switchboard that will have a register context at $self->_->rctx.

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
