package eThreads::Object::Core;

use Date::Format;
use Time::ParseDate;
use URI::Escape;

use Spiffy -Base;
no warnings;

use eThreads::Object::Auth;
use eThreads::Object::Auth::Cookies;
use eThreads::Object::Auth::Internal;

use eThreads::Object::Cache;
use eThreads::Object::Container;

use eThreads::Object::ContentType;
use eThreads::Object::ContentType::HTML;
use eThreads::Object::ContentType::XML;

use eThreads::Object::Controller;

use eThreads::Object::DB;
use eThreads::Object::DB::mysql;

use eThreads::Object::Domain;
use eThreads::Object::FakeRequestHandler;
use eThreads::Object::Functions;
use eThreads::Object::GHolders;
use eThreads::Object::Glomule;
use eThreads::Object::Instance;
use eThreads::Object::LastModifiedTime;
use eThreads::Object::Look;
use eThreads::Object::Messages;
use eThreads::Object::Mode;
use eThreads::Object::Objects;
use eThreads::Object::Plugin;
use eThreads::Object::QueryOpts;
use eThreads::Object::RequestURI;
use eThreads::Object::Switchboard;

use eThreads::Object::System;
use eThreads::Object::System::Categories;
use eThreads::Object::System::Format::Markdown;
use eThreads::Object::System::Ping;
use eThreads::Object::System::Ping::BaseMethod;
use eThreads::Object::System::Ping::XMLRPC;
use eThreads::Object::System::XMLFunction;

use eThreads::Object::Template;
use eThreads::Object::Users;
use eThreads::Object::User;
use eThreads::Object::Utils;

#----------

field '_' => -ro;

field 'settings' 	=> -ro;

field 'controller' 		=> 
	-init=>q!
		$self->_->controller
	!, -ro;

field 'memcache' 		=> 
	-init=>q!
		$self->_->memcache
	!, -ro;

field 'cgi_r_handler'	=> 
	-init=>q!
		$self->_->new_object('FakeRequestHandler');
	!, -ro;

field 'standalone'		=> 
	-init=>q!
		$self->_->new_object('Standalone');
	!, -ro;

#----------

sub new {
	$self = bless ( { } , $self );

	# -- read in our settings -- #

	{ 
#		my $cfg = "/etc/apache2/perl/eThreads/cfg.main";
		my $cfg = "/web/ericrichardson.com/eTdev/cfg.main";

		my $s;
		open(CFG,$cfg) or die "Couldn't open settings: $cfg";
			$s .= $_ while ($_ = <CFG>);
		close CFG;

		my $settings = eval qq( package main; return { $s }; );

		$self->{settings} = $settings;
	}

	# -- create our switchboard object -- #

	my $objects = new eThreads::Object::Objects($self);
	my $swb = $objects->create('Switchboard',$self);
	$swb->register('objects',$objects);
	$swb->reroute_calls_for($self);

	$swb->register('core',$self);

	# -- register our settings -- #

	$swb->register('settings',$self->{settings});

	# -- connect our database -- #

	my $db = $self->_->new_object('DB::'.$self->{settings}{db}{type});
	$db->connect();
	$swb->register('db',$db);

	# -- set up our memory cache -- #

	$swb->register('memcache',
		$self->_->new_object('Cache::Memory')
	);

	# -- sweep controller xml into mem -- #

	$swb->register('controller',
		$self->_->new_object('Controller')
	);

	# -- return our class object -- #

	return $self;
}

#----------

sub new_instance {
	my $r = shift;
	$self->_->new_object('Instance',$r);
}

#----------

sub get_dbh {
	my $db = $self->_->db->get_dbh;

	if ($db->ping) {
		return $db;
	} else {
		$self->_->db->connect;
	}
}

#----------

sub new_object {
	my @caller = caller;
	$self->_->bail("new-object called on core: @caller\n");
}

#----------

sub cgi_enable {
	return 1;
}

#----------

sub get_default_domain {
	return $self->{settings}{default_domain};
}

#----------

sub get_object_for_type {
	my $type = shift;

	return $self->{settings}{glomule_types}{$type} || undef;
}

#----------

sub tbl_name {
	my $tbl = shift;
	return $self->{settings}{db}{tbls}{ $tbl };
}

#----------

sub code {
	my $code = shift;
	return $self->settings->{response_codes}{ $code };
}

#----------

sub bail {
	my $text = shift;

	# ugh, bail called while we're still registered...  that means we're 
	# just dying

	die "core bail: $text\n";
}

#----------

=head1 NAME

eThreads::Object::Core

=head1 SYNOPSIS

	# new core object
	my $core = new eThreads::Object::Core;

	# get db handler
	$db = $core->get_dbh;

	$core->tbl_name("templates");

=head1 DESCRIPTION

This object loads all the other eThreads objects and provides a few basic 
bits of functionality.  It is persistent over the entire life of the perl 
instance, so most functionality will occur at the instance level or below.  
The core is mostly responsible for loading the settings file and setting 
up the database connection.

=over 4

=item new 

	my $core = new eThreads::Object::Core;

Create a new core object.  Read the settings file into memory.  Create our 
database connection.  Create the persistant memory cache.

=item get_dbh

	my $db = $core->get_dbh;

Returns the DB object.

=item settings 

	my $settings = $core->settings;

Returns a reference to the settings hash.  Usually you wouldn't call this 
directly.

=item memcache

	$core->memcache->set(...);

Returns a blessed ref to the memcache.  This should never be accessed 
directly.  Instead, use the Cache::Memory::Instance interface.

=item new_object

	$core->new_object("type",args);

Creates an object with the core as its ->_ data.  This should only be 
used when you don't yet have an instance or switchboard.

=item get_default_id 

Returns the default container id from settings.

=item tbl_name

	my $tbl = $core->tbl_name("glomule_headers");

Returns the localized database table name for the key (default table name) 
given.

=item bail

	$core->bail("error");

Die.  Hard.  Used as a last resort.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;

