#---------------------------------------------------------------------
#  $Id: core.pm,v 1.36 2000/07/12 01:51:27 eric Exp $
#
#  eThreads - revolutionizing forums... again.
#  Copyright (C) 1999 Eric Richardson
#
#       This program is free software; you can redistribute it and/or
#       modify it under the terms of the GNU General Public License
#       as published by the Free Software Foundation; either version 2
#       of the License, or (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  
#       02111-1307, USA.
#
#       For information, contact eThreads:
#           ethreads@ethreads.com
#           http://ethreads.com
#
#  This is the eThreadsIII core.  All eThreadsIII programs call this 
#  core for basic functionality.
#
#---------------------------------------------------------------------

#----------------#
# Initialization #
#----------------#

package eThreads::core;
use strict;
use Storable qw(store retrieve);
use Date::Format;
use Hook::WrapSub qw(wrap_subs mwrap_subs unwrap_subs);

# AGGGGHHHH -- there's got to be a better way
no strict "refs";

use DBI;
use vars qw(
	@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %e $VERSION $core $viewer 
	$db $m_db %posts %input
);

$VERSION = "0.0.1";

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(%e $db $m_db %input %posts);
@EXPORT_OK = qw();

require "cfg.main";
%{$e{settings}} = &settings;

#--------------------#
# Some Documentation #
#--------------------#

=head1 NAME

eThreads - The eThreadsIII core

=head1 SYNOPSIS

coming soon...

=head1 DESCRIPTION

This module provides the core functionality for eThreadsIII compliant Perl 
programs.  

=cut

#-------------#
# Module Core #
#-------------#

sub start {
	my $class = shift;
	my %args = (
		@_,
	);
	$e{script} = $args{script};

	# load all possible functions out of the function map
	$class->load_function_map;

	# process our input and assign it to %input	
	$class->get_vars;

	# load the language information out of the language module
	$class->load_language($e{settings}{d_lang});

	# connect the maintenance database.  we wait to connect $db later because 
	# we don't have any forum information yet.
	$class->connect_db("m");

	# take the preset fields defined in the db module and load it into memory
	@{$e{fields}{presets}} = &db::fields::presets;

	# just to save some time later, make a text string out of this array
	$e{fields}{t_presets} = join(",",@{$e{fields}{presets}});

	# forum could get passed in via args, but if not (the normal behavior), 
	# we get it from the input
	my $forum = ($args{forum}) ? $args{forum} : $input{forum};

	my $forum_id;
	if ($e{settings}{domain_rooting}) {
		($forum,$forum_id) = $class->reroot_forum($forum);
	} else {
		if (!$forum) {
			$forum_id = $class->get_default_id;
		} else {
			$forum_id = $class->forum_name2id($forum);
		}
	}

	$e{options}{authenticate} = 1 if (
		(
			$input{username} && !$e{status}{sidetrack} && $input{forum} && 
			$e{script} ne $e{settings}{scripts}{view}
		) || $args{get_rights}
	);

	if ($forum) {
		if ($forum_id) {
			# woo hoo!  forum exists!
		} else {
			# since we're transitioning to true parenting in eThreads 1.2, 
			# some forum lookups that worked fine previously will fail now.
			# Since we're nicy cuddly people, we'll put in a little fuzzy 
			# matching here to try and help them find the forum they're looking 
			# for.

			$class->forum_info();
			$class->fuzzy_forum_finder_function($forum);
			exit;
		}

		if ($e{options}{authenticate}) {
			require "module.auth.$e{settings}{d_auth}" or $class->bail(
				0,"Invalid auth type: $e{settings}{d_auth}"
			);
	
			$class->auth::get_info($input{username},$forum_id);
	
			%{$e{user}{rights}} = $class->auth::get_rights(
				user	=> $e{user}{id},
				forum	=> $forum_id
			);
		}

		$class->forum_info($forum,$forum_id);

		if ($e{forum}{type} == 1) {
			$class->browse_child_forums($forum_id) if (!$args{disable_browse});
		} else {
			&connect_db;
		}
	} else {
		if ($e{options}{authenticate}) {
			require "module.auth.$e{settings}{d_auth}" or $class->bail(
				0,"Invalid auth type: $e{settings}{d_auth}"
			);

			$class->auth::get_info($input{username},$forum_id);
	
			%{$e{user}{rights}} = $class->auth::get_rights(
				user	=> $e{user}{id},
				forum	=> $forum_id,
			);
		}

		$class->forum_info('',$forum_id);
		$class->browse_child_forums($forum_id) if (
			!$args{disable_browse}
		);
	}

	$class->make_rain if (
		($input{drop} && $input{drop} ne"all") || $input{show}
	);

	# TODO: Could there be valuable stuff returned inside of this blessed var?


	$core = bless ( { }, $class );
}

#----------

sub login {
	require "module.auth.apache";
	&auth::login;
}

#----------

# this subroutine is called by other members of the eThreads package which simply 
# need blessed access to the core.  It does no startup, it simply returns a blessed 
# reference and exports its globals

sub substart {
	my $class = shift;
	return ( { }, $class );
}

#----------

# this subroutine gets the domain name we're being accessed at, looks it up in 
# the d_bindings tbl to find what directory the name is rooted at, and prepends 
# the root name to the forum name entered

sub reroot_forum {
	my ($class,$forum) = @_;

	# now lookup the domain in the d_bindings tbl
	my $find_root = $m_db->prepare("
		select 
			$e{settings}{db}{tbls}{f_bindings}.id,
			$e{settings}{db}{tbls}{f_bindings}.name 
		from 
			$e{settings}{db}{tbls}{d_bindings},
			$e{settings}{db}{tbls}{f_bindings} 
		where 
			$e{settings}{db}{tbls}{d_bindings}.domain = ? and 
			$e{settings}{db}{tbls}{d_bindings}.rootdir = 
			$e{settings}{db}{tbls}{f_bindings}.id
	");

	$class->bail(0,"find_root: ".$m_db->errstr) unless (
		$find_root->execute($ENV{SERVER_NAME})
	);

	my ($r_id,$r_name);
	$find_root->bind_columns(\$r_id,\$r_name);

	$class->bail(
		0,"could not find root for domain '$ENV{SERVER_NAME}'"
	) unless (
		$find_root->fetch
	);

	# store these values for later
	$e{cached}{r_id} 	= $r_id;
	$e{cached}{r_name} 	= $r_name;

	my $forum_id = $class->forum_name2id($forum);

	return ($forum,$forum_id);
} 

#----------

sub get_root_id {
	return $e{cached}{r_id};
}

#----------

# this subroutine is my apology for ever introducing non-true parenting.  It 
# sucks (non-true parenting...  not this subroutine).

sub fuzzy_forum_finder_function {
	my $class = shift;
	# this is the forum they want.  At this point we have no idea whether this 
	# forum really exists, or if it's a typo.
	my $forum = shift;

	# we're going to treat this like a search engine.  We first select all 
	# forum names matching $forum anywhere

	my $descript;	
	my $descript_v;
	if ($input{search_descript}) {
		$descript 		= "or $e{settings}{db}{tbls}{preset_headers}.descript like '%$forum%'";
	}

	my $ph = $e{settings}{db}{tbls}{preset_headers};
	my $fb = $e{settings}{db}{tbls}{f_bindings};

	my $get_fuzzies = $m_db->prepare("
		select $fb.name,$ph.descript,$ph.path from $fb,$ph where 
		$fb.name like ? $descript and $fb.id = $ph.id
	");

	$class->bail(0,"get_fuzzies failure: ".$m_db->errstr) unless (
		$get_fuzzies->execute('%'.$forum.'%')
	);

	$class->header('Forum Possibilities');

	my @matches;
	my %d;
	while (my ($f,$d,$p) = $get_fuzzies->fetchrow_array) {
		if ($f =~ m!/$forum$!gi) {
			unshift @matches, $f;
		} else {
			push @matches, $f;
		}

		$d{$f}{descript} = $d;
		$d{$f}{path} = $p;
	}

	print $e{language}{forum_finder_explain};
	print "<p>";

	if (@matches) {
		$class->list_forums(\@matches,\%d);
	} else {
		$_ = $e{language}{no_matching_forums};
			s!#{link}!$e{forum}{path}/$e{script}/!gi;
		print;
	}

	$class->footer;
	
}

#----------

sub login {
	require "module.auth.$e{settings}{d_auth}";
	&auth::login;
}

#----------

=item B<update_glomule_timestamp>

	$core->update_glomule_timestamp(
		tbl			=> (tbl),
		key_field	=> (key field),
		key			=> (key),
		skey_opts	=> {
			skey_field	=> (skey_field),
			skey		=> (skey),
		},
		recursive	=> (0 or 1),
		flat		=> (0 or 1),
	);

This subroutine updates a timestamp (recursively if desired).  All skey 
information is optional.  Recursive tells the sub whether or not to update 
the timestamps of children of this glomule.  Flat sets whether this is a 
flat table or a key,ident,value table.

=cut

sub update_glomule_timestamp {
	my $class = shift;
	my %args = @_;

	if ($args{flat}) {
		my $skey_opts = 
			"and $args{skey_opts}{skey_field} = $args{skey_opts}{skey}" 
			if ($args{skey_opts});

		my $update_ts = $m_db->prepare("
			update $args{tbl} set updated = ? where $args{key_field} = ? 
			$skey_opts
		");

		$update_ts->execute(time,$args{key});
	} else {
		$class->set_value(
			tbl			=> $args{tbl},
			key_field	=> $args{key_field},
			key			=> $args{key},
			ident		=> 'updated',
			value		=> time,
			%{$args{skey_opts}},
		);
	}


	# now, if $args{recursive} = 1, look for children
	if ($args{recursive}) {
		# find children of this forum
		my $get_chiluns = $m_db->prepare("
			select id from $e{settings}{db}{tbls}{preset_headers} 
			where child_of=?
		");

		$get_chiluns->execute($args{key});

		return unless $get_chiluns->rows;

		my $cid;
		$get_chiluns->bind_columns(\$cid);
		while ($get_chiluns->fetch) {
			# launch updates fo' dem too...
			$class->update_glomule_timestamp(
				@_,
				key			=> $cid,
			);
		}
	}
}

#----------

=item B<forum_gname2fname>

	my $fname = $core->forum_gname2fname($gname);

While this function may appear pointless to some, it actually serves a valid 
purpose.  In domain rooted situations, name2name takes a given name and 
returns the full name with domain root attached, perhaps for use in the 
database.

=cut

sub forum_name2fname {
	my ($class,$name) = @_;
	my $fname;

	# take care of non domain root situations first
	if ($e{settings}{domain_rooting}) {
		# if we reach this point we know we're in a domain rooted environment
	
		# get the name of the root
		my $root = $class->forum_id2name(
			$class->get_root_id
		);

		$fname = $root . "/" . $name;
	} else {
		$fname = $name;
	}

	$fname =~ s!//!!g;
	$fname =~ s!^/!!;

	return $fname;
}

#----------

sub forum_name2id {
	my ($class,$name) = @_;

	if ($e{settings}{domain_rooting} && $name !~ m!^\.!) {
		# we need to prepend the root name to $name
		$name = $e{cached}{r_name} . "/" . $name;
		$name =~ s!^/!!;
		$name =~ s!/$!!;
	} else {
		# we do nothing to it
	}

	my $get_id = $m_db->prepare("
		select id from $e{settings}{db}{tbls}{f_bindings} where name=?
	");
	$class->bail(0,"get_id failure: ".$m_db->errstr) unless (
		$get_id->execute($name)
	);
	return $get_id->fetchrow_array;
}

#----------

sub forum_id2name {
	my ($class,$id) = @_;

	my $get_name = $m_db->prepare("
		select name from $e{settings}{db}{tbls}{f_bindings} where id=?
	");
	$class->bail(0,"get_name failure: ".$m_db->errstr) unless (
		$get_name->execute($id)
	);

	if ($e{settings}{domain_rooting}) {
		my $name = $get_name->fetchrow_array;

		# since we're domain rooted, we need to rip the invisible root off

		
	} else {
		my $name = $get_name->fetchrow_array;
		
		return $name unless ($name =~ m!^\.!);
		return '';
	}
}

#----------

=item B<user_name2id>

	my $uid = $core->user_name2id($username);

When given a username, returns the unique id given to that user.

=cut

sub user_name2id {
	my ($class,$username) = @_;

	my $get_uid = $m_db->prepare("
		select id from $e{settings}{db}{tbls}{users} where username = ?
	");

	$class->bail(0,"get_uid: ".$m_db->errstr) unless (
		$get_uid->execute($username)
	);

	return $get_uid->fetchrow_array;
}

#----------

=item B<user_id2name>

	my $username = $core->user_id2name($uid);

When given a user id, returns the username for that user.

=cut

sub user_id2name {
	my ($class,$id) = @_;

	my $get_username = $m_db->prepare("
		select username from $e{settings}{db}{tbls}{users} where id = ?
	");

	$class->bail(0,"get_username: ".$m_db->errstr) unless (
		$get_username->execute($id)
	);

	return $get_username->fetchrow_array;
}

#----------

sub htmltable_2col {
	my $class = shift;
	my %args = @_;

	# get a copy of the input data
	my @data = @{$args{data}};

	my $width = ($e{tweak}{htmlCOL2_LEFT} + $e{tweak}{htmlCOL2_RIGHT});
	print <<EOP;
	<table border=0 width=$width>
	<tr bgcolor=#$e{tweak}{htmlTITLE_BAR_COLOR}>
		<td colspan=2>
			<b><font color=#$e{tweak}{htmlTITLE_FONT_COLOR}>
				$args{title}
			</b></font>
		</td>
	</tr>
EOP

	my %colors = (
		'0'	=> {
			c	=> $e{tweak}{htmlROW1_COLOR},
			fc	=> $e{tweak}{htmlROW1_FONT_COLOR},
		},
		'1'	=> {
			c	=> $e{tweak}{htmlROW2_COLOR},
			fc	=> $e{tweak}{htmlROW2_FONT_COLOR},
		},
	);

	my $row_count;
	while (my $row_data = shift @data) {
		my $eoo = ($row_count++)%2;
		my ($left,$right) = @{$row_data};
		print <<EOP;
		<tr bgcolor=#$colors{$eoo}{c}>
			<td width=$e{tweak}{htmlCOL2_LEFT}>
				$left
			</td>
			<td width=$e{tweak}{htmlCOL2_RIGHT}>
				$right
			</td>
		</tr>
EOP
	}

	print "</table>";
}

#----------

sub htmltable_3col {
	my $class = shift;
	my %args = @_;

	# get a copy of the input data
	my @data = @{$args{data}};

	my $width = (
		$e{tweak}{htmlCOL3_LEFT} + $e{tweak}{htmlCOL3_MIDDLE} + $e{tweak}{htmlCOL2_RIGHT}
	);

	print <<EOP;
	<table border=0 width=$width>
	<tr bgcolor=#$e{tweak}{htmlTITLE_BAR_COLOR}>
		<td colspan=3>
			<b><font color=#$e{tweak}{htmlTITLE_FONT_COLOR}>
				$args{title}
			</b></font>
		</td>
	</tr>
EOP

	my %colors = (
		'0'	=> {
			c	=> $e{tweak}{htmlROW1_COLOR},
			fc	=> $e{tweak}{htmlROW1_FONT_COLOR},
		},
		'1'	=> {
			c	=> $e{tweak}{htmlROW2_COLOR},
			fc	=> $e{tweak}{htmlROW2_FONT_COLOR},
		},
	);

	my $row_count;
	while (my $row_data = shift @data) {
		my $eoo = ($row_count++)%2;
		my ($left,$center,$right) = @{$row_data};
		print <<EOP;
		<tr bgcolor=#$colors{$eoo}{c}>
			<td width=$e{tweak}{htmlCOL3_LEFT}>
				$left
			</td>
			<td width=$e{tweak}{htmlCOL3_RIGHT}>
				$center
			</td>
			<td width=$e{tweak}{htmlCOL3_RIGHT}>
				$right
			</td>
		</tr>
EOP
	}

	print "</table>";
}

#----------

# this subroutine opens the function map and loads the functions out of it.

sub load_function_map {
	my $class = shift;
	if (-e"$e{settings}{function_map}") {
		require "$e{settings}{function_map}";
		my %functions = &function_map::load_functions;
		foreach my $function (keys %functions) {
			$e{functions}{$function} = $functions{$function};
		}
	} else {
		$class->bail(0,"The function map could not be loaded: $!");
	}
}

#----------

# this subroutine takes $input{function}, and tries to figure out the 
# appropriate subroutine to call based on the function map

sub function_finder {
	my $class = shift;
	if (!$input{function}) {
		# main_menu is the default no function specified subroutine
		&main::main_menu;
	} elsif (
		$e{functions}{$input{function}} && 
		$e{functions}{$input{function}}{$e{script}}
	) {
		# first determine the subroutine name
		my $subroutine;
		if ($e{functions}{$input{function}}{$e{script}} ne "1") {
			$subroutine = $e{functions}{$input{function}}{$e{script}};
		} elsif ($e{functions}{$input{function}}{subroutine}) {
			$subroutine = $e{functions}{$input{function}}{subroutine};
		} else {
			$subroutine = $input{function};
		}

		# now find out what package we should be looking in
		my $package;
		if ($e{functions}{$input{function}}{class_var}) {
			my $foo = "main::$e{functions}{$input{function}}{class_var}";
			$package = ${$foo};
		} else {
			$package = bless ( { }, "main" );
		}

		$package->$subroutine();
	} else {
		# NOTE (05/27/2000 - e) -- I don't think anyone can get to this error.
		# If eThreads doesn't recognize something as a function, it assumes it 
		# is a child glomule and looks for the glomule. 

		# they're lost
		$class->bail(0,$e{language}{bad_function});
	}
}

#----------

=item B<add_sub_wrap>

	$core->add_sub_wrap(
		before	=> \&before,
		sub		=> "sub",
		after	=> \&after,
	);

This subroutine adds a wrap layer around "sub".  This may or may not be the 
only wrap layer depending on if other glomlets need to wrap the same sub.

=cut

sub add_sub_wrap {
	my $class = shift;
	my %args = @_;

	return if (!$args{sub} || (!$args{before} && !$args{after}));

	if ($e{wrapped}{$args{sub}}) {
		# unwrap so we can re-wrap
		&Hook::WrapSub::unwrap_subs($args{sub});
	} else {
		# we don't need to unwrap first
	}

	# now re-wrap
	push @{$e{wrapped}{$args{sub}}{before}}, $args{before} if ($args{before});
	push @{$e{wrapped}{$args{sub}}{after}}, $args{after} if ($args{after});

	Hook::WrapSub::mwrap_subs(
		before	=> [@{$e{wrapped}{$args{sub}}{before}}],
		subs	=> [$args{sub}],
		after	=> [@{$e{wrapped}{$args{sub}}{after}}],
	);
}

#----------

sub load_glomule {
	my $class = shift;

	# initialize the glomule
	$e{glomule} = $class->init_glomule($e{forum}{type});

	# figure out what plugins this glomule uses
	my $get_glomlets = $m_db->prepare("
		select ident from $e{settings}{db}{tbls}{plugins} 
		where forum = ? and user = ?
	");

	# we only load system glomlets here.  User glomlets load later so 
	# they have less power.
	$class->bail(0,"get_glomlets: ".$m_db->errstr) unless (
		$get_glomlets->execute($e{forum}{id},0)
	);

	my ($glomlet);
	$get_glomlets->bind_columns(\$glomlet);

	while ($get_glomlets->fetch) {
		if (-e "module.glomlet.$glomlet") {
			require "module.glomlet.$glomlet";
			my $package = "eThreads::glomlet::$glomlet";
			$e{glomlet}{$glomlet} = $package->init();
		} else {
			$class->bail(0,"load_glomule: glomlet '$glomlet' not found.");
		}
	}

	# load the forum_type options into place
	my %gs = $e{glomule}->settings;
	foreach my $key (keys %{$gs{options}}) {
		$e{options}{$key} = $gs{options}{$key};
	}

	%{$e{fields}{schema}} = $e{glomule}->fields_schema;

	# let's do some query assembly
	@{$e{fields}{get_posts}} 	= $e{glomule}->fields_get_posts;
	@{$e{fields}{get_post}} 	= $e{glomule}->fields_get_post;

	#@{$e{fields}{presets}}		= $e{glomule}->fields_presets;

	# just to save some time later...
	my $field;
	my @get_posts = @{$e{fields}{get_posts}};
	$e{fields}{t_get_posts} .= "$field," while ($field = shift(@get_posts));
	$e{fields}{t_get_posts} =~ s/,$//;

	my @get_post = @{$e{fields}{get_post}};
	$e{fields}{t_get_post} .= "$field," while ($field = shift(@get_post));
	$e{fields}{t_get_post} =~ s/,$//;

	$e{glomule}->startup;
}

#----------

=item B<init_glomule>

	my $handler = $core->init_glomule($type);

When given a glomule type, checks to see if it is valid and runs the glomule's 
init function if it is.  It them returns the handler given to it by the init 
function.

=cut

sub init_glomule {
	my ($class,$type) = (shift,shift);

	if (-e "module.glomule.$type") {
		require "module.glomule.$type";
		my $package = "eThreads::glomule::$type";

		# initial the glomule, passing it any remaining arguments given to 
		# us, and then return the handler to the caller
		return $package->init(@_);
	} else {
		$class->bail(0,"init_glomule: Glomule type '$type' invalid.");
	}
}

#----------

=item B<set_value>

	$core->set_value(
		tbl		=> (tbl),
		key_field	=> (key field),
		key		=> (key),
		skey_field	=> (secondary key field),
		skey		=> (secondary key),
		ident		=> (identifier),
		value		=> (new value),
		set_zero_val	=> (1 or 0 (DEFAULT)),
	);

This function automatically detects whether it should insert, update, or 
delete from a standard (key,ident,value) table.  If set_zero_val is 
specified, values of 0 are written to the db.  If not, a null value is 
understood to mean deleting the entry.

=cut

sub set_value {
	my $class = shift;
	my %args = (@_,);
	my ($skey,$i_skeyf,$i_skeyv);

	$args{value} = '0' if (!$args{value} && $args{set_zero_val});

	if ($args{skey_field}) {
		$skey	 	= "and $args{skey_field} = $args{skey}";
		$i_skeyf	= ",".$args{skey_field};
		$i_skeyv	= ",".$args{skey};
	}

	# select to determine if there is a current value set
	my $select = $m_db->prepare("	
		select ident from $args{tbl} 
		where $args{key_field} = ? and ident=? $skey
	");
	$class->bail(0,"set_value select failure: ".$m_db->errstr) unless (
		$select->execute($args{key},$args{ident})
	);

	if ($select->rows && ($args{value} || $args{set_zero_val})) {
		# if an entry exists, and there was a value input or we're 
		# setting zero values, then update existing entry

		my $update = $m_db->prepare("
			update $args{tbl} set value = ? 
			where ident = ? and $args{key_field} = ? $skey
		");
		$class->bail(0,"set_value update failure: ".$m_db->errstr) unless (
			$update->execute($args{value},$args{ident},$args{key})
		);
	} elsif ($select->rows) {
		# if there is an entry, there's no input value, and zero values are 
		# illegal, delete the entry

		my $delete = $m_db->prepare("
			delete from $args{tbl} 
			where ident = ? and $args{key_field} = ? $skey
		");
		$class->bail(0,"set_value delete failure: ".$m_db->errstr) unless (
			$delete->execute($args{ident},$args{key})
		);
	} elsif ($args{value} || $args{set_zero_val}) {
		# if there was no match, and there's an input value or we're allowing 
		# zero values, create a new entry

		my $create = $m_db->prepare("
			insert into $args{tbl}($args{key_field},ident,value$i_skeyf) 
			values(?,?,?$i_skeyv)
		");
		$class->bail(0,"set_value create failure: ".$m_db->errstr) unless (
			$create->execute($args{key},$args{ident},$args{value})
		);
	} else {
		# do nothing
	}
}

#----------

sub info {
	my $class = shift;
	# eventually this should be called to print out information such as core  
	# version, imageset info, language module info, etc.  For now, it doesn't

	$class->header("Forum Information");

	$class->footer;
}

#----------

=item B<email>

	$core->email(
		to			=> (to),
		reply_to	=> (reply_to),
		subject		=> (subject),
		body		=> (body),
	);

This subroutine sends out email using the parameters given to it.

=cut

sub email {
	#my ($class,$recipient,$subject,$body,$reply_to) = @_;
	my $class = shift;
	my %args = @_;

	$class->bail(0,"no recipient specified in email") unless ($args{to});

	my $email;
	if ($args{to} =~ /<.*>/) {
		($email) = $args{to} =~ /<(.*)>/;
	} else {
		$email = $args{to};
	}

	open(EMAIL, "| $e{settings}{mail_prog} -f$e{settings}{admin_email} $email"
	) or $class->bail(0,"Could not send email: $!");

	my @MONTHS = (
		'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
	);

	my @DAYS = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	my ($msec,$mmin,$mhr,$mmday,$mmon,$myear,$mwday,$mrest) = localtime;
	$myear += 1900;
	my $mmin = "0$mmin" if ($mmin < 10);
	my $day = $DAYS[$mwday];

	print EMAIL "Date: $DAYS[$mwday], $mmday $MONTHS[$mmon] $myear $mhr:$mmin\n";
	print EMAIL "Reply-to: $args{reply_to}\n" if ($args{reply_to});
	print EMAIL "From: $e{settings}{auto_email_from}\n";
	print EMAIL "To: $args{to}\n";
	print EMAIL "Subject: $args{subject}\n\n";
	print EMAIL "$args{body}";
	print EMAIL <<EOP;

---------------------------------------
eThreads: a new breed of forum software
http://ethreads.com
---------------------------------------
EOP
	close EMAIL;
}

#----------

sub connect_db {
	my ($class,$which_db) = @_;
	require "module.db.$e{settings}{db}{type}";
	if ($which_db eq"m") {
		$class->bail(0,"Could not connect m_db : $!") unless (
			$m_db	= &db::connect_mdb
		);
	} else {
		# if i was less lazy i would search and replace to get rid of 
		# the seperate references to $m_db and $db since they're one 
		# now.  i don't feel like doing that right now, though, and 
		# this gives me the option of changing my mind some day.
		$db = $m_db;
	
		%{$e{db}} = &db_info;
	}
}

#----------

sub header {
	my ($class,$title) = @_;

	if (!$e{status}{content_type}) {
		print "Content-type: text/html\n\n";
		$e{status}{content_type} = 1;
	}
	
	my $header = $e{look}{header};
	unless ($e{status}{header} || $input{no_header}) {
		$_ = $header;
			my $ad = $class->load_ad if (/#AD/);
			s/#AD/$ad/g;

			while (m!#{include ([^}]+)}!gi) {
				my $results = $class->include_url($1);
				s/#{include $1}/$results/gi;
			}

			s/#{title}/$title/g;

			if (m!#{search_box}!gi) {
				my $sb = $class->print_search_box(
					query 	=> $input{query},
				);

				s!#{search_box}!$sb!gi;
			}
		print;
		$e{status}{header} = 1;
	}
}

#----------

sub footer {
	my ($class,$title) = @_;
	my $footer = $e{look}{footer};
	unless ($e{status}{footer} || $input{no_footer}) {
		$_ = $footer;
			my $ad = &load_ad if (/#AD/);
			s/#AD/$ad/g;

			while (m!#{include ([^}]+)}!gi) {
				my $results = $class->include_url($1);
				s/#{include $1}/$results/gi;
			}

			if (m!#{search_box}!gi) {
				my $sb = $class->print_search_box(
					query 	=> $input{query},
				);

				s!#{search_box}!$sb!gi;
			}
		print;
		$e{status}{footer} = 1;
	}
}

#----------

sub print_search_box {
	my $class = shift;
	my %args = @_;

	my $box = qq(<form action="$e{forum}{path}/$e{script}/$input{forum}/search" method=get>$e{look}{search_box}</form>);
	$box =~ s!#{query}!$args{query}!gi;

	return $box;
}

#----------

sub include_url {
	my ($class,$url) = @_;

	# strip encapsulating quotes
	$url =~ s/^"(.*)"$/$1/g;

	$url = "http://localhost$url" if ($url =~ m!^/!);

	require LWP::Simple;
	my $results = LWP::Simple::get($url);

	return $results;
}

#----------

# this is some really, really basic ad loading code.  so far there 
# is no admin interface for defining what ads appear on what forums.  
# it would be easy to write one external to eThreads, though.  Use it 
# if you wish.

sub load_ad {
	my ($class,$html,@ad_ids);
	my $get_ads_for_forum = $m_db->prepare("
		select ad_id from ad_bindings where forum='$input{forum}'
	");

	$class->bail(0,$m_db->errstr) unless ($get_ads_for_forum->execute);
	while (my $id = $get_ads_for_forum->fetchrow_array) {
		push @ad_ids, $id;
	}
	my $num_ads = $get_ads_for_forum->rows;

	if ($num_ads) {
		my $n = int(rand($num_ads));
	
		my $get_ad = $m_db->prepare("
			select html from ads where id=$ad_ids[$n]
		");
	
		$class->bail(0,$m_db->errstr) unless ($get_ad->execute);
		$html = $get_ad->fetchrow_array;
	}
	
	return $html;
}

#----------

sub make_rain {
	my $class = shift;
	# normal drops
	my @drops = split(",",$input{drop});
	while (my $drop = pop(@drops)) {
		$e{rain}{$drop} = 1;
	}

	# reverse drops
	my @r_drops = split(",",$input{show});
	if (@r_drops) {
		my ($r_drops,$drop);
		$r_drops .= "$drop," while ($drop = shift(@r_drops));
		$r_drops =~ s/,$//;

		# find ancestors of these posts
		my $get_ancestors = $m_db->prepare("
			select aid from $e{settings}{db}{tbls}{bindings} 
			where forum=$e{forum}{id} and cid in ( $r_drops )
		");

		$class->bail(
			0,"couldn't get ancestor: " . $m_db->errstr
		) unless ($get_ancestors->execute);

		while (my $aid = $get_ancestors->fetchrow_array) {
			$e{rain}{$aid} = 1;
		}
	}

	# now rebuild the drop list for if they want to keep dropping
	$input{drop} = "";
	foreach my $id (keys %{$e{rain}}) {
		$input{drop} .= "$id,";
	}
}

#----------

sub get_posts {
	my $class = shift;
	my $option = shift;
	my $query;
	my $godfather;

	if ($option == 0) {
		# find children...
		my $id = shift;
		$query = "where child_of=$id";
		while ($id = shift) {
			$query .= " or child_of=$id";
		}
	} elsif ($option == 1) {
		# get specific posts...
		my $id = shift;
		$query = "where id=$id";
		while ($id = shift) {
			$query .= " or id=$id";
		}
		# assorted options
		$godfather = 1;
		$e{options}{no_max_threads} = 1;
	} elsif ($option == 2) {
		# browsers beware... we're getting all posts
	} elsif ($option == 3) {
		# get all posts by user
		my $user = shift;
		$query = "where username='$user'";

		# assorted options
		$godfather = 1;
		$e{options}{no_max_threads} = 1;
	} else {
		$class->bail(0,"Bad option inputted to get_posts");
	}

	if ($e{rain}) {
		foreach my $drop (keys %{$e{rain}}) {
			$query .= " or child_of=$drop";
		}
	}

	my $get_posts = $db->prepare("
		select $e{fields}{t_get_posts} from $e{forum}{main_tbl} $query
	");

	$class->bail(0,$db->errstr) unless ($get_posts->execute);

	# we'll use @children if we need to go any deeper into the tree
	my @children;
	
	my $status_check = "and ($e{forum}{main_db}.$e{forum}{main_tbl}.status = 1)"
		unless ($e{script} eq"$e{settings}{scripts}{admin}");

	my $s_time = time;

	my %r_bind;
	while (my $result = $get_posts->fetchrow_arrayref) {
		my %tmp;
		my @fields = @{$e{fields}{get_posts}};

		my $i;
		while (my $field = shift(@fields)) {
			$tmp{$field} = $result->[$i];
			$i++;
		}

		my $parent = ($tmp{child_of} && !$godfather) ? $tmp{child_of} : '0';

		%{$posts{$parent}{$tmp{id}}} = %tmp;

		# reverse bind for use in child collection
		$r_bind{$tmp{id}} = $tmp{child_of};

		push @children, $tmp{id};
	}

	# prepare our child finding query.  isn't this one ugly monster?

	# NOTE: if the data table and bindings table are in different databases, the
	#		main $m_db user ($e{settings}{db}{user}) MUST have select perms in  
	#		the $e{forum}{main_db} db.  Otherwise, this query will fail.

	if (@children) {
		my $bind = $e{settings}{db}{main}.".".$e{settings}{db}{tbls}{bindings};
		my $main = $e{forum}{main_db}.".".$e{forum}{main_tbl};

		my $get_children = $m_db->prepare("
			select $bind.aid,count($bind.cid) from $bind,$main
			where $bind.aid in (".join(",",@children).") and 
			$bind.forum = $e{forum}{id} and ($bind.cid = $main.id) 
			$status_check group by $bind.aid
		");

		$core->bail(
			0,"get_children failure: ".$m_db->errstr
		) unless ($get_children->execute);

		my ($aid,$cid_count);
		$get_children->bind_columns(\$aid,\$cid_count);
		while ($get_children->fetchrow_arrayref) {
			$posts{$r_bind{$aid}}{$aid}{children} = $cid_count;
		}
	}

	# figure out if we're doing any drop depth stuff
	if (
		($input{depth} || $e{prefs}{d_depth}) && 
		!$e{status}{current_drop_depth}
	) {
		# we are going to be dropping, and this is our first time in get_posts

		# figure out how far we're going
		$e{status}{final_drop_depth} = 
			$input{depth} ? $input{depth} : $e{prefs}{d_depth};

		$e{status}{final_drop_depth}--;

		# now get the other posts we'll need
		$e{status}{current_drop_depth}++;
			$class->get_posts(0,@children) if (@children);
		$e{status}{current_drop_depth}--;

	} elsif ($e{status}{current_drop_depth}) {
		# we are dropping, and we're going through get_posts for at least the 
		# second time

		# do we stop here, or do we keep going?
		if (
			$e{status}{final_drop_depth} > $e{status}{current_drop_depth} && 
			@children
		) {
			# we keep going
			$e{status}{current_drop_depth}++;
			$class->get_posts(0,@children);
			$e{status}{current_drop_depth}--;
		} else {
			# we stop here
		}
	} else {
		# we're not doing any drop stuff
	}
}

#----------

sub buttons {
	my $class = shift;
	my $called_from = shift;
	my $other = shift;

	sub up {
		if ($other) {
			"$e{forum}{path}/$e{script}/$input{forum}/view_post?id=$other"
		} else {
			"$e{forum}{path}/$e{script}/$input{forum}/"
		}
	}

	my %buttons = (
		signup	=> "$e{forum}{path}/$e{settings}{scripts}{view}/$input{forum}/signup",
		options	=> "$e{forum}{path}/$e{script}/$input{forum}/options",
		login	=> "$e{forum}{path}/$e{script}/$input{forum}/login",
		post	=> "$e{forum}{path}/$e{script}/$input{forum}/post",
		reply	=> "$e{forum}{path}/$e{script}/$input{forum}/post?child_of=$input{id}",
		up		=> up,
	);

	my @disabled = $e{glomule}->disable_buttons($called_from);

	while (my $button = shift(@disabled)) {
		delete $buttons{$button};
		delete $e{images}{$button."_button"};
	}
	
	foreach my $button (keys %buttons) {
		my $ibutton = $button . "_button";
		if ($e{images}{$ibutton} =~ /#LINK/) {
			$e{images}{$ibutton} =~ s!#LINK!<a href="$buttons{$button}">!g;
			$e{images}{$ibutton} =~ s!#E_LINK!</a>!g;
		} else {
			$e{images}{$ibutton} = qq(
				<a href="$buttons{$button}">$e{images}{$ibutton}</a>
			);
		}
	}	

	print "$e{images}{bar_top}";
	print "$e{images}{login_button}$e{images}{signup_button}" unless ($e{user}{username});
	print $e{images}{options_button} if ($e{user}{username});
	print $e{images}{post_button} if ($called_from eq"top");
	if ($called_from eq"post"){
		print $e{images}{reply_button} unless ($e{post}{status} == 2);
		print $e{images}{up_button};
	}
	print "$e{images}{bar_bottom}";
}

#----------

sub get_post {
	my ($class,$id) = @_;

	my $get_post = $db->prepare("
		select $e{fields}{t_get_post} from 
		$e{forum}{main_tbl} where id=?
	");
	$class->bail(0,$db->errstr) unless ($get_post->execute($id));
	my @results = $get_post->fetchrow_array;

	my @fields = @{$e{fields}{get_post}};
	my %p;

	while (my $field = shift(@fields)) {
		$p{$field} = shift(@results);
	}

	my $status_check = "and ($e{forum}{main_db}.$e{forum}{main_tbl}.status = 1)"
		unless ($e{script} eq"$e{settings}{scripts}{admin}");

	my $get_children = $m_db->prepare("
		select $e{settings}{db}{main}.$e{settings}{db}{tbls}{bindings}.cid from 
		$e{settings}{db}{main}.$e{settings}{db}{tbls}{bindings},$e{forum}{main_db}.$e{forum}{main_tbl}
		where $e{settings}{db}{main}.$e{settings}{db}{tbls}{bindings}.aid=? and
		$e{settings}{db}{main}.$e{settings}{db}{tbls}{bindings}.forum = $e{forum}{id} and 
		($e{settings}{db}{main}.$e{settings}{db}{tbls}{bindings}.cid = $e{forum}{main_db}.$e{forum}{main_tbl}.id)
		$status_check
	");

	$class->bail(0,"get_post get_children: ".$m_db->errstr) unless (
		$get_children->execute($id)
	);
	$p{children} = $get_children->rows;

	$p{id} = $id;
	return %p;
}

#----------

sub timestamp_to_date {
	my ($class,$timestamp,$format) = @_;

	my $date = time2str($format,$timestamp);
	return $date;
}

#----------

sub browse_child_forums {
	my ($class,$parent,$option,$no_footer) = @_;

	$class->header($e{language}{avail_forums});
	#print "$e{forum}{intro}<p>" unless ($class);

	my $ph = $e{settings}{db}{tbls}{preset_headers};
	my $fb = $e{settings}{db}{tbls}{f_bindings};

	my $get_forums = $m_db->prepare("
		select 
			$fb.name,$ph.descript,$ph.path,$ph.type
		from $ph,$fb where $ph.id = $fb.id and $ph.child_of = ? 
	");
	$class->bail(0,$m_db->errstr) unless ($get_forums->execute($parent));

	# load the glomule registry so we know what should be visible.
	require "module.glomule.registry";
	my $registry = eThreads::glomule::registry->init();
	my %registry = $registry->main;

	my @forums;
	my %d;
	my ($f,$d,$p,$t);
	$get_forums->bind_columns(\$f,\$d,\$p,\$t);
	while ($get_forums->fetch) {
		if ($option == 1 || ($f !~ /^\./ && !$registry{$t}{invisible} && $d)) {
			push @forums, $f;
			%{$d{$f}} = (
				descript	=> $d,
				type		=> $t,
				path		=> $p,
			);
		} 
	}

	$class->list_forums(\@forums,\%d);

	$class->footer unless ($no_footer);
	$e{status}{sidetrack} = 1;
}

#----------

sub list_forums {
	my ($class,$forums,$d) = @_;
	my %d = %{$d};	

	my @data = ([qq(<b>$e{language}{glomule}:</b>),qq(<b>$e{language}{description}:</b>)]);

	while (my $f = shift @{$forums}) {
		my $pf;
		if ($e{settings}{domain_rooting} &! ($e{forum}{id} == $class->get_default_id)) {
			($pf) = $f =~ m!^[^/]+/(.*)!;
		} else {
			$pf = $f;
		}

		push @data, [
			qq(<a href="$d{$f}{path}/$e{script}/$pf">$pf</a>),
			qq($d{$f}{descript})
		];      
	}   

	$class->htmltable_2col(
		title   => $e{language}{child_glomules},
		data    => \@data, 
	);  

}

#----------

# load in language defaults from the module.lang.$language file.

sub load_language {
	my ($class,$language) = @_;
	require "module.lang.$language";
	%{$e{language}} = &language::words;
}

#----------

sub bail {
	my ($class,$tables,$error) = @_;
	my $timestamp = time;

	$class->header("An Error Has Occured");

	print "</table>" while ($tables--);

	my $email;
	if ($e{forum}{admin_email}) {
		$email = $e{forum}{admin_email};
	} else {
		$email = $e{settings}{admin_email};
	}

	$e{language}{error_occured} =~ s/#EMAIL/<a href="mailto:$email">$email<\/a>/;

	print <<EOP;
	<p><hr><p>
	$e{language}{error_occured}
	<p>
	$timestamp : $error
	<p><hr><p>
EOP

	$class->footer;

	# insert email code here

	die "eThreads : $input{forum} : $timestamp : $error\n";
}

#----------

sub get_default_id {
	my ($class) = @_;

	if (!$e{cached}{d_id}) {
		$e{cached}{d_id} = $class->forum_name2id('.default');
		return $e{cached}{d_id};
	} else {
		return $e{cached}{d_id};
	}
}

#----------

# load stuff out of the cache, unless it doesn't exist in the cache or the information 
# in the database is newer, in which case we call the cache subroutine to cache new info 
# out of the database.  Duh.

sub forum_info {
	my ($class,$forum,$forum_id) = @_;
	my (%c_forum,%c_images,%c_tweak,%c_words,%c_look);

	if (!$forum_id) {
		$forum_id = $class->get_default_id;
	}

	# now we take the forum id and attempt to load the appropriate cache.  If it doesn't 
	# exist we'll write a new cache

	#-------------------------#
	# load basic glomule info #
	#-------------------------#

	if (-e"$e{settings}{cache_dir}/cache.$forum_id.forum") {
		# grab forum information out of our stored hash
		$e{forum} = retrieve("$e{settings}{cache_dir}/cache.$forum_id.forum") or $class->bail(
			0,"Could not open $e{settings}{cache_dir}/cache.$forum_id.forum : $!"
		);

		# grab customized words out of the cache
		my $c_words = retrieve("$e{settings}{cache_dir}/cache.$forum_id.words") or $class->bail(
			0,"Could not open $e{settings}{cache_dir}/cache.$forum_id.words : $!"
		);

		# overload the default wordset with customized ones.  By doing it this way words that 
		# aren't defined in the cache aren't overwritten.
		foreach my $word (keys %{$c_words}) {
			$e{language}{$word} = ${$c_words}{$word};
		}

		# there isn't a wordlist timestamp, so we use the one from presets.  When 
		# wordlists are changed, the preset timestamp is updated to reflect that.
		my $db_ts = $m_db->prepare("
			select updated from $e{settings}{db}{tbls}{preset_headers} 
			where id = ?
		");
		$class->bail(0,$m_db->errstr) unless ($db_ts->execute($forum_id));

		my ($preset_ts) = $db_ts->fetchrow_array;

		$class->cache($forum,$forum_id,"forum") if ($preset_ts > $e{forum}{updated});
	} else {
		# no cache, so we write a new one
		$class->cache($forum,$forum_id,"forum");
	}

	# i know...  this is an out of the way, all around crappy place to be 
	# calling outside routines, but I need the forum_type stuff loaded in time 
	# to use it when caching prefs.  I can't load it in $core->start, though, 
	# because I don't know the forum type until now.  Hence, I make the call here.

	$class->load_glomule; 

	#--------------------------#
	# load glomule preferences #
	#--------------------------#

	if (-e"$e{settings}{cache_dir}/cache.$forum_id.prefs") {
		# first load the pre-existing cache
		$e{prefs} = retrieve("$e{settings}{cache_dir}/cache.$forum_id.prefs");
		
		# now get the timestamp for the forum default prefs.  If we're somewhere 
		# where the user is logged in, the user's prefs will be loaded later in 
		# the user startup.  User prefs override default forum prefs.

		my $get_ts = $m_db->prepare("
			select value from $e{settings}{db}{tbls}{prefs} 
			where ident=? and user=? and forum=?
		");

		# first get the default pref ts
		$class->bail(0,"d get_ts failure: ".$m_db->errstr) unless (
			$get_ts->execute('updated','0',$forum_id)
		);
		$class->bail(0,"prefs get_ts: ".$m_db->errstr) unless (
			$get_ts->execute
		);

		my $d_ts = $get_ts->fetchrow_array;

		$class->cache($forum,$forum_id,"prefs") if ($d_ts > $e{prefs}{updated});
	} else {
		$class->cache($forum,$forum_id,"prefs");
	}

	#-------------------------#
	# import user preferences #
	#-------------------------#

	# override real prefs with user prefs
	foreach my $u_pref (keys %{$e{u_prefs}}) {
		$e{prefs}{$u_pref} = $e{u_prefs}{$u_pref};
	}

	#-------------------#
	# load glomule look #
	#-------------------#

	{
		# determine which look id we should be loading
		my $pick_look = $m_db->prepare("
			select id from $e{settings}{db}{tbls}{theme_headers} 
			where forum = ? and class = ?
		");

		$class->bail(0,"pick_look: ".$m_db->errstr) unless (
			$pick_look->execute($e{forum}{id},$e{forum}{type})
		);

		$class->bail(0,"No look for: $e{forum}{id}/$e{forum}{type}") unless (
			my $look = $pick_look->fetchrow_array
		);

		# check for the cache.  If it exists, use it.
		if (-e"$e{settings}{cache_dir}/cache.look.$forum_id.$look") {
			$e{look} = retrieve("$e{settings}{cache_dir}/cache.look.$forum_id.$look") or 
				$class->bail(0,"Opening Cache Failed: $!\n");

			# now compare the updated value from the cache with the database
			my $look_ts = $m_db->prepare("
				select updated from $e{settings}{db}{tbls}{theme_headers} where id=?
			");

			$class->bail(0,"look ts grab failed: ".$m_db->errstr) unless (
				$look_ts->execute($look)
			);
	
			$class->cache($forum,$forum_id,"look",$look) if ($look_ts->fetchrow_array > $e{look}{updated});
		} else {
			$class->cache($forum,$forum_id,"look",$look);
		}

	}

	#---------------------#
	# load glomule tweaks #
	#---------------------#

	if (-e"$e{settings}{cache_dir}/cache.$forum_id.tweak") {
		# get the tweaks out of the cache
		$e{tweak} = retrieve("$e{settings}{cache_dir}/cache.$forum_id.tweak");
		
		my $db_ts = $m_db->prepare("
			select value from $e{settings}{db}{tbls}{tweaks} where forum = ? and ident = 'updated'
		");

		$class->bail(0,$m_db->errstr) unless ($db_ts->execute($forum_id));

		my ($tweak_ts) = $db_ts->fetchrow_array;
		$class->cache($forum,$forum_id,"tweak") if ($tweak_ts > $e{tweak}{updated});
	} else {
		$class->cache($forum,$forum_id,"tweak");
	}

	#-----------------#
	# load icon theme #
	#-----------------#

	if (-e"$e{settings}{cache_dir}/cache.$e{look}{images}.images") {
		# get the images out of the cache
		$e{images} = retrieve("$e{settings}{cache_dir}/cache.$e{look}{images}.images");

		my $db_ts = $m_db->prepare("
			select value from $e{settings}{db}{tbls}{iconthemes} 
			where theme='$c_images{name}' and ident='updated'
		");

		$class->bail(0,$m_db->errstr) unless ($db_ts->execute);

		my $imageset_ts = $db_ts->fetchrow_array;

		$class->cache($forum,$forum_id,"images") if (
			$imageset_ts > $e{images}{updated} || 
			$e{look}{images} ne"$e{images}{name}"
		);
	} else {
		$class->cache($forum,$forum_id,"images");
	}
}

#----------

sub cache {
	my ($class,$forum,$forum_id,$sector) = (shift,shift,shift,shift);

	#--------------------------#
	# cache basic glomule info #
	#--------------------------#

	if ($sector eq"forum") {
		%{$e{forum}} = ();

		#---------------------#
		# load preset headers #
		#---------------------#

		# first load the preset headers.  these are the same for all 
		# glomules of all types

		my $get_preset_headers = $m_db->prepare("
			select id,descript,path,updated,child_of,admin_email,type 
			from $e{settings}{db}{tbls}{preset_headers} where id=?
		");

		$class->bail(0,"get_preset_headers: ".$m_db->errstr) unless (
			$get_preset_headers->execute($forum_id)
		);

		(
			$e{forum}{id},$e{forum}{descript},$e{forum}{path},$e{forum}{updated},
			$e{forum}{child_of},$e{forum}{admin_email},$e{forum}{type}
		) = $get_preset_headers->fetchrow_array;

		#------------------#
		# load preset data #
		#------------------#

		# now load the preset data.  This is data that may vary on depending on 
		# the glomule class selected.

		# this is silly to have to create an array with one element, but i can't figure 
		# out a cleaner way without redoing g_load_tbl

		my @id = ($e{forum}{id});

		my %preset_data = $class->g_load_tbl(
			tbl		=> $e{settings}{db}{tbls}{preset_data},
			ident	=> "id",
			ids		=> \@id,
		);

		foreach my $ident (keys %{$preset_data{$e{forum}{id}}}) {
			$e{forum}{$ident} = $preset_data{$e{forum}{id}}{$ident} unless ($e{forum}{$ident});
		}

		#--------------------#
		# store preset cache #
		#--------------------#

		store(
			\%{$e{forum}}, "$e{settings}{cache_dir}/cache.$forum_id.forum"
		) or $class->bail(
			0,"Couldn't write $e{settings}{cache_dir}/cache.$forum_id.forum"
		);

		#---------------------#
		# cache language mods #
		#---------------------#

		my @forum_tree = $class->build_forum_tree($forum_id);

		my %mods = $class->g_load_tbl(
			tbl		=> $e{settings}{db}{tbls}{words},
			ident	=> 'forum',
			ids		=> \@forum_tree
		);

		my %c_words;
		while (my $id = shift(@forum_tree)) {
			foreach my $word (keys %{$mods{$id}}) {
				if (!$c_words{$word}) {
					$c_words{$word} = $mods{$id}{$word};
					$e{language}{$word} = $mods{$id}{$word};
				}
			}
		}	

		# now write the changed wording into the cache
		store(
			\%c_words,"$e{settings}{cache_dir}/cache.$forum_id.words"
		) or $class->bail(
			0,"Couldn't write $e{settings}{cache_dir}/cache.$forum_id.words"
		);

	#------------------#
	# cache look theme #
	#------------------#

	} elsif ($sector eq"look") {
		# NOTE (06/01/2000 - e): I'm taking out the ability to create multiple 
		# look themes per class for right now.  Although I would like to bring 
		# this functionality back, the inheritance issues are too much for me 
		# right now, so eThreads will only support one look per class in 1.2.

		# wipe out any old look info
		%{$e{look}} = ();

		# first we get the information provided by the theme_headers table

		my $get_theme_headers = $m_db->prepare("
			select id,forum,name,descript,updated,class 
			from $e{settings}{db}{tbls}{theme_headers} 
			where id = ?
		");
		$class->bail(0,"get_theme_headers: ".$m_db->errstr) unless (
			$get_theme_headers->execute(shift)
		);

		(
			$e{look}{id},$e{look}{forum},$e{look}{name},
			$e{look}{descript},$e{look}{updated},$e{look}{class}
		) = $get_theme_headers->fetchrow_array;

		# now get the information out of the theme_data table.  This is where 
		# most of the look information is stored.  

		my %look = $class->load_theme(
			$e{forum}{id},$e{look}{id},$e{look}{class}
		);

		foreach my $key (keys %look) {
			$e{look}{$key} = $look{$key};
		}

		store(
			\%{$e{look}},
			"$e{settings}{cache_dir}/cache.look.$forum_id.$e{look}{id}"
		) or $class->bail(
			0,"Could not open $e{settings}{cache_dir}/cache.look.$forum_id.$e{look}{id} for writing."
		);

	#------------------#
	# cache icon theme #
	#------------------#

	} elsif ($sector eq"images") {
		my $get_imageset = $m_db->prepare("
			select ident,value from $e{settings}{db}{tbls}{iconthemes} where theme='$e{look}{images}'
		");
		$class->bail(0,$m_db->errstr) unless ($get_imageset->execute);

		while (my ($ident,$value) = $get_imageset->fetchrow_array) {
			$e{images}{$ident} = $value;
		}
	
		store(\%{$e{images}},"$e{settings}{cache_dir}/cache.$e{look}{images}.images") or $class->bail(
			0,"Could not open $e{settings}{cache_dir}/cache.$e{look}{images}.images for writing."
		);

	#--------------#
	# cache tweaks #
	#--------------#

	} elsif ($sector eq"tweak") {
		# make sure the tweak hash is empty
		%{$e{tweak}} = ();

		my @tree = $class->build_forum_tree($forum_id);

		my %tweaks = $class->g_load_tbl(
			tbl		=> $e{settings}{db}{tbls}{tweaks},
			ident	=> 'forum',
			ids		=> \@tree
		);

		# we shift here because the front of the array has overwrite precedence
		while (my $id = shift(@tree)) {
			foreach my $ident (keys %{$tweaks{$id}}) {
				$e{tweak}{$ident} = $tweaks{$id}{$ident} unless ($e{tweak}{$ident});
			}
		}

		# now store our new tweak cache
		store(\%{$e{tweak}},"$e{settings}{cache_dir}/cache.$forum_id.tweak") or $class->bail(
			0,"Could not open $e{settings}{cache_dir}/cache.$forum_id.tweak for writing."
		);

	#---------------------------#
	# cache glomule preferences #
	#---------------------------#

	} elsif ($sector eq"prefs") {
		# make sure the prefs hash is empty
		%{$e{prefs}} = ();

		my @tree = $class->build_forum_tree($forum_id);
		my %prefs = $class->g_load_tbl(
			tbl		=> $e{settings}{db}{tbls}{prefs},
			ident	=> 'forum',
			ids		=> \@tree,
			extra	=> "and user = '0'"
		);

		# we shift here because the front of the array has overwrite precedence
		while (my $id = shift(@tree)) {
			foreach my $ident (keys %{$prefs{$id}}) {
				$e{prefs}{$ident} = $prefs{$id}{$ident} if (!$e{prefs}{$ident});
			}
		}

		# now tack on the default prefs for anything not already defined
		my %d_prefs = $e{glomule}->prefs;
		foreach my $pref (keys %d_prefs) {
			$e{prefs}{$pref} = $d_prefs{$pref}{d_val} unless ($e{prefs}{$pref});
		}

		# now store our new prefs cache
		store(\%{$e{prefs}},"$e{settings}{cache_dir}/cache.$forum_id.prefs") or $class->bail(
			0,"Could not open $e{settings}{cache_dir}/cache.$forum_id.prefs for writing."
		);

	} else {
		$class->bail(0,"Improper sector call for caching");
	}
}

#----------

sub load_theme {
	my ($class,$forum_id,$look_id,$g_class) = @_;

	my @parents = $class->build_forum_tree($forum_id);

	my $get_parent_d_looks = $m_db->prepare(
		"select id,forum from $e{settings}{db}{tbls}{theme_headers} 
		where forum in (" . join(",",@parents) . ") and class = ?"
	);

	$class->bail(0,"get_parent_d_looks failure: ".$m_db->errstr) unless (
		$get_parent_d_looks->execute($g_class)
	);

	my %bind;

	my @p_looks = ($look_id);
	while (my ($p_look,$forum) = $get_parent_d_looks->fetchrow_array) {
		unshift @p_looks, $p_look;
		$bind{$forum} = $p_look;
	}

	my %looks = $class->g_load_tbl(
		tbl		=> $e{settings}{db}{tbls}{theme_data},
		ident	=> 'id',
		ids		=> \@p_looks
	);

	my %look;

	foreach my $parent (@parents) {
		foreach my $key (keys %{$looks{$bind{$parent}}}) {
			$look{$key} = $looks{$bind{$parent}}{$key} unless ($look{$key});
		}
	}

	return %look;
}

#----------

# build an array of the forums you'd need to load to cache recursively for this forum

sub build_forum_tree {
	my ($class,$id) = @_;
	my @tree;

	if (@{$e{forum_tree}{$id}}) {
		@tree = @{$e{forum_tree}{$id}};
	} else {
		my $get_parent = $m_db->prepare("
			select child_of from $e{settings}{db}{tbls}{preset_headers} where id=?
		");
	
		# obviously we start our tree with the forum they're accessing
		@tree = ($id);
		my $parent = $id;
	
		do {
			$get_parent->execute($parent);
			$parent = $get_parent->fetchrow_array;
			push @tree, $parent if ($parent);
		} while ($parent);

		# all trees end with the default forum
		push @tree, $class->get_default_id;

		@{$e{forum_tree}{$id}} = @tree;
	}
	
	return @tree;
}

#----------

=item B<g_load_tbl>

	my %hash = $core->g_load_tbl(
		tbl	=> (table),
		ident	=> (ident field),
		ids	=> (array ref of ident values to load),
		extra	=> (extra sql qualifiers to use),
	);

g_load_tbl is a generic interface for loading data out of the eThreads 
standard ($ident,ident,value) format for tables.  It can be given an array 
of $ident keys in order to load inherited values.  Using the "extra" argument, 
g_load_tbl can also load data out of tables with more than three columns (as 
long as the table contains the required $ident,ident,value format.

=cut

sub g_load_tbl {
	my $class = shift;
	my %args = (
		@_,
	);

	my %tmp;

	my $get_tbl = $m_db->prepare("
		select $args{ident},ident,value from $args{tbl} 
		where $args{ident} in (".join(",",@{$args{ids}}).")
		$args{extra}
	");

	$get_tbl->execute();

	my ($id,$ident,$value);
	$get_tbl->bind_columns(\$id,\$ident,\$value);
	
	while ($get_tbl->fetch) {
		$tmp{$id}{$ident} = $value;
	}

	return %tmp;
}

#----------

sub get_vars {
	my ($info);

	if ($ENV{'REQUEST_METHOD'} eq "POST") {
		read(STDIN,$info,$ENV{"CONTENT_LENGTH"});
	} else {
		$info=$ENV{QUERY_STRING};
	}

	foreach (split(/&/,$info)) {
		my ($var,$val) = split(/=/,$_,2);
		$var =~ s/\+/ /g;
		$val =~ s/\+/ /g;
		$val =~ s/%([0-9,A-F]{2})/sprintf("%c",hex($1))/ge;
		$input{$var} .= ", " if ($input{$var});
		$input{$var} .= $val;
	}
	
	$ENV{PATH_INFO} =~ s!^/!!;
	$ENV{PATH_INFO} =~ s!/$!!;

	$ENV{PATH_INFO} =~ m!/([^/]+)$!;
	if ($e{functions}{$1}) {
		($input{forum},$input{function}) = $ENV{PATH_INFO} =~ m!(.*)/([^/]+)!;
	} else {
		$input{forum} = $ENV{PATH_INFO};
	}

	$input{username} = $ENV{REMOTE_USER};
}

#----------

#-------------#
# Change Logs #
#-------------#

# $Log: core.pm,v $
# Revision 1.36  2000/07/12 01:51:27  eric
# * fixed change_intro code
# * made update_glomule_timestamp documentation more clear
#
# Revision 1.35  2000/07/12 00:43:11  eric
# * fixed forum_id2name so that .default isn't returned as such
# * removed two warns
#
# Revision 1.34  2000/07/11 19:40:25  eric
# * fixed glomule data table deletion code
# * fixed phantom cache bug
# * made delete glomule code show glomule name instead of id
#
# Revision 1.33  2000/07/11 18:53:27  eric
# * ummm...  i did stuff...  good stuff, i think.
#   (WTF do you expect?!?!?  It's a 1000+ line diff)
#
# Revision 1.32  2000/07/10 20:54:23  eric
# * merged BCI and tgp devel trees
# * cleaned up some code in forum_info and cache
#
# Revision 1.31  2000/06/07 18:14:52  eric
# * glomule creation fixes
# * glomule deletion fixes
# * fixed all old references to presets
# * domain rooting work
# * glomule module work
# * assorted other fixes
#
# Revision 1.30  2000/06/06 00:01:17  eric
# * finished integrating look classes and the preset_headers/preset_data
#
# Revision 1.29  2000/06/01 00:32:06  eric
# * monster commit
# * initial glomlet support
# * started hacking presets into something more flexible
# * started hacking glomule class and inheritance support directly into
#   look themes
#
# Revision 1.28  2000/05/11 00:54:54  eric
# * committing Gospelcom patches
#
# Revision 1.27  2000/05/01 19:04:12  eric
# * more work on domain rooting
#
# Revision 1.26  2000/04/29 16:39:21  eric
# * merging eThreads1_2-devel tree back into main eThreads tree
#
# Revision 1.25.4.13.4.53  2000/04/22 20:31:07  eric
# * work on the domain rooting code
# * added the glomule::disable_buttons sub to the rest of the glom types
# * added a '</form>' whose absense was dorking up picky CSS
#
# Revision 1.25.4.13.4.52  2000/04/22 17:00:34  eric
# * lots of class fixes
# * added the ability for glomules to choose buttons to delete
#
# Revision 1.25.4.13.4.51  2000/04/22 14:25:11  eric
# * fixed some class errors
#
# Revision 1.25.4.13.4.50  2000/04/21 23:24:40  eric
# * fixed some problems with inherited looks
#
# Revision 1.25.4.13.4.49  2000/04/21 22:19:06  eric
# * admin: fixed create_user reference to old style f_name l_name
# * core.pm: changed browse_child_forums to not show glomule if it didn't
#   have a description
#
# Revision 1.25.4.13.4.48  2000/04/15 22:49:24  eric
# * made an exception in $core->start to not authenticate if its the
#   view script
# * moved all user notification to the remailer
#
# Revision 1.25.4.13.4.47  2000/04/12 01:01:33  eric
# * changed some function map syntax
# * corrected some annoying behavior in function_finder
#
# Revision 1.25.4.13.4.46  2000/04/11 01:00:34  eric
# * fix for forums with d_depth > 0 and no posts
#
# Revision 1.25.4.13.4.45  2000/04/11 00:50:45  eric
# * fixed some timestamp updating
# * fixed language mod caching
#
# Revision 1.25.4.13.4.44  2000/04/09 20:40:26  eric
# * changes and such...
#
# Revision 1.25.4.13.4.43  2000/03/15 23:26:41  eric
# * added function htmltable_3col.
#
# Revision 1.25.4.13.4.42  2000/03/14 00:45:35  eric
# * changed some calling info to be more consistant
# * fixed a child finding bug when there were no posts
# * a little formatting cleanup
#
# Revision 1.25.4.13.4.41  2000/03/13 23:51:11  eric
# * rewrote $core->list_forums to use $core->htmltable_2col
#
# Revision 1.25.4.13.4.40  2000/03/13 02:15:14  eric
# * 20x+ speed improvement due to child finding SQL optimization
#
# Revision 1.25.4.13.4.39  2000/03/12 00:43:40  eric
# * optimization tweak...  fetchrow_arrayref is supposed to be faster than
#   fetchrow_array
#
# Revision 1.25.4.13.4.38  2000/03/11 18:51:19  eric
# * misc. tweaks in the road towards 1.2-stable
#
# Revision 1.25.4.13.4.37  2000/03/07 22:33:41  eric
# * rewrote restricted wordlist editor to build in support for recursion
#
# Revision 1.25.4.13.4.36  2000/03/06 22:14:43  eric
# * fixed modify_language function
#
# Revision 1.25.4.13.4.35  2000/03/06 21:57:22  eric
# * created glomule registry
# * coined "glomule" term to refer to data holders (formerly we used
#   "forum", but that's too specific).  Glomule comes from the word
#   agglomeration, meaning "a confused or disordered mass".
#
# Revision 1.25.4.13.4.34  2000/03/03 00:54:26  eric
# * updated rights code
#
# Revision 1.25.4.13.4.33  2000/02/24 21:23:31  eric
# * added explanation paragraph for forum_finder
#
# Revision 1.25.4.13.4.32  2000/02/24 20:37:26  eric
# * fixed some maintenance issues
#
# Revision 1.25.4.13.4.31  2000/02/24 15:53:04  eric
# * fixed rights loading
#
# Revision 1.25.4.13.4.30  2000/02/24 15:26:32  eric
# * fixed some rights loading
# * fixed user pref caching
#
# Revision 1.25.4.13.4.29  2000/02/23 18:33:54  eric
# * fixed forum deletion
# * created $core->forum_name2id and $core->forum_id2name
#
# Revision 1.25.4.13.4.28  2000/02/23 18:07:20  eric
# * fixed tweak editing
#
# Revision 1.25.4.13.4.27  2000/02/23 07:08:03  eric
# * moved user info around in $core->start to set user info before
#   loading forum_type info.
#
# Revision 1.25.4.13.4.26  2000/02/23 06:51:26  eric
# * ummm...  i did stuff.  lots of stuff.
#
# Revision 1.25.4.13.4.25  2000/02/22 22:15:45  eric
# * added caching code for prefs
# * changed call syntax for g_load_tbl
#
# Revision 1.25.4.13.4.24  2000/02/22 20:58:12  eric
# * rewrote core::start function and changed arg style
# * wrote forum finder
# * redid browse_child_forum backend to be generic
#
# Revision 1.25.4.13.4.23  2000/02/21 19:09:04  eric
# * updated user information to use new user tbl structure
#
# Revision 1.25.4.13.4.22  2000/02/18 18:20:24  eric
# * rewrote change_icontheme (formerly change_imageset)
# * rewrote view_icontheme (formerly view_imageset)
# * abstracted some value setting code out to a core sub
#
# Revision 1.25.4.13.4.21  2000/02/16 17:44:38  eric
# * rewrote most of the search engine matching code
# * fixed post modification
#
# Revision 1.25.4.13.4.20  2000/02/12 19:58:58  eric
# * migrated wordmods over to new standard db structure
# * abstracted forum_tree building code
#
# Revision 1.25.4.13.4.19  2000/02/12 19:13:38  eric
# * rewrote tweak caching code to support recursive pref loading and
#   new db structure
#
# Revision 1.25.4.13.4.18  2000/02/12 02:45:53  eric
# * commiting changes from hosehead
#
# Revision 1.25.4.13.4.17  2000/01/18 23:40:50  eric
# * rewrote calendar forum_type module to work with new structure
#
# Revision 1.25.4.13.4.16  2000/01/18 20:42:38  eric
# * implemented server side includes
# * changed search_box placeholder to new style
#
# Revision 1.25.4.13.4.15  2000/01/18 00:55:04  eric
# * added search to function map
# * worked on search function
#
# Revision 1.25.4.13.4.14  2000/01/13 22:46:58  eric
# * rewrote theme modification code
# * rewrote theme creation code
# * changed theme database structure to split tables with ident,value pair
#
# Revision 1.25.4.13.4.13  2000/01/13 19:15:04  eric
# * fixed presets caching
# * moved preset fields to db module
# * fixed r_drop with forum ids
#
# Revision 1.25.4.13.4.12  2000/01/13 17:21:16  eric
# * reverted to previous presets table structure
# * changed forum cache code to use forum_type::fields::presets
#
# Revision 1.25.4.13.4.11  2000/01/11 01:10:35  eric
# * started changeover to new-style presets table
#
# Revision 1.25.4.13.4.10  1999/12/22 21:28:52  eric
# * drop to new posts now works
# * renamed router function to function_finder
#
# Revision 1.25.4.13.4.9  1999/12/22 18:41:16  eric
# * new post code
# * schema work
#
# Revision 1.25.4.13.4.8  1999/12/21 22:16:27  eric
# * broke the post code mightily
# * started work on drop-to-post
#
# Revision 1.25.4.13.4.7  1999/11/25 21:43:19  eric
# * finished transition to forum_type specified data table structure
# * added ability to use any retrieved field in view_post or print_thread
#
# Revision 1.25.4.13.4.6  1999/11/24 01:04:19  eric
# * changed get_posts over to forum_type based field specs.
#
# Revision 1.25.4.13.4.5  1999/11/23 02:54:07  eric
# * converted cache code to use Shareable.pm
# * added check in $core->start to see if forum exists before trying to
#   load forum info
#
# Revision 1.25.4.13.4.4  1999/11/13 20:36:31  eric
# * some sublevel forum fixes in the cache loading sub
# * fixed a call to the wrong db for error info in viewer.pm
#
# Revision 1.25.4.13.4.3  1999/11/12 01:03:56  eric
# * initial try at drop depths and stuff (both user inputted and preset)
#
# Revision 1.25.4.13.4.2  1999/11/10 18:43:47  eric
# * more function map work
# * changed admin permissions code to utilize function unmapping
# * created calendar module
#
# Revision 1.25.4.13.4.1  1999/09/27 23:22:27  eric
# * started changeover to new forum name system
# * started changeover to new function calling system
#
# Revision 1.25.4.13  1999/09/03 12:25:05  eric
# * rolled $u_db into $m_db
#
# Revision 1.25.4.12  1999/08/26 14:04:27  eric
# * updated all headers to conform to standard eThreads header
#
# Revision 1.25.4.11  1999/08/26 02:06:58  eric
# * updated default error message
#
# Revision 1.25.4.10  1999/08/24 20:08:14  eric
# * merging in changes from BCI tree
#
# Revision 1.25.4.9  1999/08/18 19:11:59  eric
# * email subscription fixes
#
# Revision 1.25.4.8  1999/08/18 06:34:12  eric
# * forgot field change in cache code
#
# Revision 1.25.4.7  1999/08/18 06:30:55  eric
# * forum_type modules and code
# * first revision of instamailer (subscription notifier)
# * some subscription code in members
#
# Revision 1.25.4.6  1999/08/17 21:55:43  eric
# * small db call changes
#
# Revision 1.25.4.5  1999/06/25 20:27:15  eric
# * more search code work.  added some new forumset fields for search stuff
#
# Revision 1.25.4.4  1999/06/24 22:37:33  eric
# * started search code
#
# Revision 1.25.4.3  1999/06/22 20:02:22  eric
# * fixes for invitation only forums
#
# Revision 1.25.4.2  1999/06/22 14:43:47  eric
# * fixed type that caused 500's on non type 3 forums
#
# Revision 1.25.4.1  1999/06/22 14:37:41  eric
# * added support for password protected forums
#
# Revision 1.25  1999/05/30 17:40:33  eric
# * removed a really annoying warn
#
# Revision 1.24  1999/05/30 16:32:12  eric
# * rewrote button bar code
#
# Revision 1.23  1999/05/27 00:19:06  eric
# * various changes to get ready for eThreads 0.9
#
# Revision 1.22  1999/05/20 23:16:10  eric
# * imagesets moved to new iconthemes.
# * updated button bar to use icon themes
#
# Revision 1.21  1999/05/20 22:52:44  eric
# * slightly revised rights code
# * added email subroutine
# * removed some warns
#
# Revision 1.20  1999/05/15 20:34:34  eric
# * doh...  forgot a change.
#
# Revision 1.19  1999/05/15 20:33:52  eric
# * added some changes to make the news system work.  Should not affect
#   normal use
#
# Revision 1.18  1999/04/29 23:54:23  eric
# * updated call to get_rights to conform to new syntax
# * updated browse_child_forums to not list forums with type > 1 (news)
#
# Revision 1.17  1999/04/29 22:49:32  eric
# * removed some deleted preset and tweak fields
# * fixed code to decide when to authenticate
#
# Revision 1.16  1999/04/13 23:41:51  eric
# * moved imageset loading code over to forumsets setting
#
# Revision 1.15  1999/04/13 23:16:09  eric
# * added call to auth::get_rights
# * added another look thingy
#
# Revision 1.14  1999/04/09 06:24:48  eric
# * added profile_html to forumset caching
# * added code for get_posts option 3
#
# Revision 1.13  1999/04/06 21:29:26  eric
# * forum looks
# 	* new caching code
# 	* modified header and footer to use forum looks
#
# Revision 1.12  1999/03/26 17:54:31  eric
# * authentication fix: don't authenticate top level
#
# Revision 1.11  1999/03/24 01:06:19  eric
# * fixed language loader
#
# Revision 1.10  1999/03/23 23:09:38  eric
# * moved all words and phrases into single hash level
# * new wordset tweak code (and caching)
#
# Revision 1.9  1999/03/22 00:46:02  eric
# * moved authentication code to auth module
# * moved content-type into start routine
#
# Revision 1.8  1999/03/21 22:28:05  eric
# * image caches now forum independant
#
# Revision 1.7  1999/03/20 16:51:00  eric
# * fixed some caching code to make image set changing work
#
# Revision 1.6  1999/03/07 00:41:15  eric
# * some fixes for admin browsing stuff
#
# Revision 1.5  1999/02/27 20:58:43  eric
# * added another start option for admin so directories wouldn't
#   auto-browse in core and sidetrack
# * fixed cache code so type would successfully cache
#
# Revision 1.4  1999/02/27 17:41:43  eric
# * lots of tweaks for admin and maintenance (mostly in browsing)
#
# Revision 1.3  1999/02/19 20:55:23  eric
# * various button_bar changes
#
# Revision 1.2  1999/02/09 22:14:08  eric
# * changed get_post to return a hash
# * changed $e{input} to $input
# * probably fixed other junk
#
# Revision 1.1  1999/02/07 18:08:51  eric
# * core functions from former eThreads.pm
#

#---------------#
# End of Script #
#---------------#

1;
