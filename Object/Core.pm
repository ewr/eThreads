package eThreads::Object::Core;

use Date::Format;
use Time::ParseDate;
use URI::Escape;

use eThreads::Object::Auth;
use eThreads::Object::Auth::Cookies;
use eThreads::Object::Auth::Internal;

use eThreads::Object::Cache;

use eThreads::Object::Container;

use eThreads::Object::ContentType;
use eThreads::Object::ContentType::HTML;

use eThreads::Object::DB;
use eThreads::Object::DB::mysql;

use eThreads::Object::Domain;

use eThreads::Object::Format::Markdown;

use eThreads::Object::GHolders;
use eThreads::Object::Glomule;
use eThreads::Object::FakeRequestHandler;
use eThreads::Object::Functions;
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

use eThreads::Object::System::Ping;
use eThreads::Object::System::Ping::BaseMethod;
use eThreads::Object::System::Ping::XMLRPC;

use eThreads::Object::Template;
use eThreads::Object::User;
use eThreads::Object::Utils;

use strict;

#----------

sub new {
	my $class = shift;

	$class = bless ( { } , $class );

	# -- read in our settings -- #

	{ 
		my $cfg = "/etc/apache2/perl/eThreads/cfg.main";

		my $s;
		open(CFG,$cfg) or die "Couldn't open settings: $cfg";
			$s .= $_ while ($_ = <CFG>);
		close CFG;

		my $settings = eval qq( package main; return { $s }; );

		$class->{settings} = $settings;
	}

	# -- connect our database modules -- #

	$class->{db} = $class->new_object("DB::".$class->{settings}{db}{type});

	# -- connect to the database -- #

	$class->{db}->connect();

	# -- set up our memory cache -- #

	$class->{memcache} = $class->new_object("Cache::Memory");

	# -- return our class object -- #

	return $class;
}

#----------

sub get_dbh {
	my $class = shift;
	return $class->{db}->get_dbh || $class->{db}->connect();
}

#----------

sub settings {
	return shift->{settings};
}

#----------

sub memcache {
	return shift->{memcache};
}

#----------

sub new_object {
	my $class = shift;
	my $type = shift;

	my $module = "eThreads::Object::$type";

	my $obj = $module->new($class,@_);

	return $obj;
}

#----------

sub cgi_enable {
	my $class = shift;

	return 1;
}

#----------

sub cgi_r_handler {
	my $class = shift;

	if (my $r = $class->{_cgi_r_handler}) {
		return $r;
	} else {
		my $r = $class->{_cgi_r_handler} = $class->new_object(
			"FakeRequestHandler"
		);

		return $r;
	}
}

#----------

sub load_instance_objects {
	my $class = shift;

	my $inst = $class->new_object("Instance");

	return $inst;
}

#----------

sub load_instance_from_notes {
	my $class = shift;
	my $c = shift;

	my $inst = $class->new_object("Instance");

	my $v = {
		c	=> {
			id		=> $c->notes->get("container/id"),
			name	=> $c->notes->get("container/name"),
		},
	};

	$inst->{container}			= $inst->new_object("Container");
	$inst->{container}{id}		= $v->{c}{id};
	$inst->{container}{name}	= $v->{c}{name};

	return $inst;
}

#----------


sub get_default_domain {
	my $class = shift;
	return $class->{settings}{default_domain};
}

#----------

sub get_object_for_type {
	my $class = shift;
	my $type = shift;

	return $class->{settings}{glomule_types}{$type} || undef;
}

#----------

sub tbl_name {
	my $class = shift;
	my $tbl = shift;

	return $class->{settings}{db}{tbls}{ $tbl };
}

#----------

sub code {
	my $class = shift;
	my $code = shift;
	return $class->settings->{response_codes}{ $code };
}

#----------

sub bail {
	my $class = shift;
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

Creates an object with the core as its ->{_} data.  This should only be 
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

