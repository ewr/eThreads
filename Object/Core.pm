package eThreads::Object::Core;

use Data::Dumper;
use Date::Format;
use Time::ParseDate;
use URI::Escape;

use eThreads::Object::Auth;
use eThreads::Object::Auth::Internal;

use eThreads::Object::Cache;
use eThreads::Object::Cache::Memory;
use eThreads::Object::Cache::Memory::Instance;
use eThreads::Object::Cache::MultiServer;
use eThreads::Object::Cache::SingleServer;
use eThreads::Object::Cache::Objects;
use eThreads::Object::Cache::UpdateTimes;

use eThreads::Object::Container;

use eThreads::Object::ContentType;
use eThreads::Object::ContentType::HTML;

use eThreads::Object::DB;
use eThreads::Object::DB::mysql;

use eThreads::Object::Format::Markdown;

use eThreads::Object::GHolders;
use eThreads::Object::GHolders::GHolder;
use eThreads::Object::GHolders::RegisterContext;

use eThreads::Object::Glomule;
use eThreads::Object::Glomule::Function;
use eThreads::Object::Glomule::Pref;
use eThreads::Object::Glomule::Type::Admin;
use eThreads::Object::Glomule::Type::Blog;

use eThreads::Object::Instance;

use eThreads::Object::LastModifiedTime;

use eThreads::Object::Look;

use eThreads::Object::Messages;

use eThreads::Object::Mode;
use eThreads::Object::Mode::Admin;
use eThreads::Object::Mode::Auth;
use eThreads::Object::Mode::Normal;

use eThreads::Object::Objects;

use eThreads::Object::QueryOpts;
use eThreads::Object::QueryOpts::Bucket;
use eThreads::Object::QueryOpts::QueryOption;

use eThreads::Object::RequestURI;

use eThreads::Object::Switchboard;
use eThreads::Object::Switchboard::Custom;

use eThreads::Object::System::Ping;
use eThreads::Object::System::Ping::BaseMethod;
use eThreads::Object::System::Ping::XMLRPC;

use eThreads::Object::Template;
use eThreads::Object::Template::Item;
use eThreads::Object::Template::Subtemplate;
use eThreads::Object::Template::Walker;

use eThreads::Object::User;

use strict;

use Storable;
#use Date::Format;
#use Time::ParseDate;
use CGI;
use Carp;
use DBI;

sub new {
	my $class = shift;

	$class = bless ( { } , $class );

	# -- read in our settings -- #

	{ 
		my $cfg = "/web/ericrichardson.com/perl/eThreads/cfg.main";

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
	return $class->{db}->get_dbh;
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


sub get_default_id {
	my $class = shift;
	return $class->{settings}{default_container};
}

#----------

sub get_object_for_type {
	my $class = shift;
	my $type = shift;

	return $class->{settings}{glomule_types}{$type} || undef;
}

#----------

sub set_value {
	my $class = shift;
	my %args = @_;

	$args{value_field} = "value" if (!$args{value_field});
	$args{value} = '0' if (!$args{value} && $args{set_zero_val});

	# set up our conditions
	my @cargs;
	my @cond;

	my $db = $class->get_dbh;

	foreach my $key (keys %{$args{keys}}) {
		push @cond, "$key = ?";
		push @cargs, $args{keys}{$key};
	};

	my $cond = "where " . join(" and ",@cond);

	# select to determine if there is a current value set
	my $select = $db->prepare("
		select 1 from $args{tbl} $cond
	");

	$class->bail(0,"set_value select failure: ".$db->errstr) unless (
		$select->execute(@cargs)
	);

	if ($select->rows && ($args{value} || $args{set_zero_val})) {
		# if an entry exists, and there was a value input or we're 
		# setting zero values, then update existing entry

		my $update = $db->prepare("
			update $args{tbl} set $args{value_field} = ? $cond
		");

		$class->bail(0,"set_value update failure: ".$db->errstr) unless (
			$update->execute($args{value},@cargs)
		);
	} elsif ($select->rows) {
		# if there is an entry, there's no input value, and zero values are 
		# illegal, delete the entry

		my $delete = $db->prepare("
			delete from $args{tbl} $cond
		");
		$class->bail(0,"set_value delete failure: ".$db->errstr) unless (
			$delete->execute(@cargs)
		);
	} elsif ($args{value} || $args{set_zero_val}) {
		# if there was no match, and there's an input value or we're allowing 
		# zero values, create a new entry

		my $keys = join(",",keys %{$args{keys}});

		my $create = $db->prepare("
			insert into $args{tbl}(
				$keys,$args{value_field}
			) values (" . "?,"x(@cargs) . "?)
		");
		$class->bail(0,"set_value create failure: ".$db->errstr) unless (
			$create->execute(@cargs,$args{value})
		);
	} else {
		# do nothing
	}
}
#----------

sub g_load_tbl {
	my $class = shift;
	my %args = @_;

	my $tmp = {};

	my $db = $class->get_dbh;

	my $where;
	if ($args{get_all}) {
		# $where stays null
	} else {
		$where = 
			"where $args{ident} in (". 
			join( "," , @{ $args{ids} } ). 
			")";
	}

	my $get_tbl = $db->prepare("
		select $args{ident},ident,value from $args{tbl} 
		$where
		$args{extra}
	");

	$class->bail("g_load_tbl: ".$db->errstr) unless (
		$get_tbl->execute()
	);

	my ($id,$ident,$value);
	$get_tbl->bind_columns(\$id,\$ident,\$value);
	
	if ($args{flat}) {
		while ($get_tbl->fetch) {
			$tmp->{$ident} = $value;
		}
	} else {
		while ($get_tbl->fetch) {
			$tmp->{$id}{$ident} = $value;
		}
	}

	return $tmp;
}

#----------

sub g_rec_populate {
	my ($class,$uh,$t) = @_;
	my $h = {};
 
	foreach my $id (@$t) {
		while ( my ($k,$v) = each %{ $uh->{ $id } }) {
			$h->{ $k } = $v if (!defined($h->{ $k }));
		}
	}   
        
	return $h;
}   

#----------

sub tbl_name {
	my $class = shift;
	my $tbl = shift;

	return $class->{settings}{db}{tbls}{ $tbl };
}

#----------

#----------

sub bail {
	my $class = shift;

	

	die "bail: @_\n";
}

#----------

=head1 NAME

eThreads::Object::Core

=head1 SYNOPSIS

	# new core object
	my $core = new eThreads::Object::Core;

	# get db handler
	$db = $core->get_dbh;

	$core->table_name("templates");

=head1 DESCRIPTION

This object loads all the other eThreads objects and provides a few basic 
bits of functionality.  It is persistent over the entire life of the perl 
instance, so most functionality will occur at the instance level or below.  
The core is mostly responsible for loading the settings file and setting 
up the database connection.

=over 4

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2004 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
