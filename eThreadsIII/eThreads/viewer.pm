#---------------------------------------------------------------------
#  $Id: viewer.pm,v 1.28 2000/07/11 18:53:27 eric Exp $
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
#  This is the viewer portion of the eThreadsIII core.
#
#---------------------------------------------------------------------

#----------------#
# Initialization #
#----------------#

package eThreads::viewer;
use strict;
no strict "refs";
use DBI;
use eThreads::core;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %e $VERSION $db $core $m_db %posts %input);

$VERSION = "0.0.1";

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(%e $db $m_db %input %posts);
@EXPORT_OK = qw();

#--------------------#
# Some Documentation #
#--------------------#

=head1 NAME

eThreads::viewer - The eThreadsIII viewer module

=head1 SYNOPSIS

coming soon...

=head1 DESCRIPTION

This module provides some viewer functionality for eThreadsIII compliant Perl 
programs.  

=head1 What is Provided

=cut

#-------------#
# Module Core #
#-------------#

=item B<start>

	$viewer->start();

Returns a handler for viewer routines.  Also calls $core->substart to give 
viewer routines access to core.

=cut

sub start {
	my $class = shift;
	$core = eThreads::core->substart;
	bless ( { }, $class );
}

#----------

=item B<substart>

	$viewer->substart();

Returns a handler for viewer routines.
(NOTE -- This routine is intended for modules who don't wish any startup 
processing which occurs in $viewer->start to occur again.)

=cut

sub substart {
	my $class = shift;
	bless ( { }, $class );
}

#----------

=item B<search>

	$viewer->search;

This routine is the eThreads search engine.  It is usually called via the 
associated function and gets its input directly from the query string.

=cut

sub search {
	my $class = shift;
	my $query = $input{query};
	$core->header("Search for: $query");
	my (@terms,$sql_query);

	# build our SQL query by breaking up what we're searching for
	# - we'll start by preserving stuff in quotes
	$_ = $query;
	@terms = /"([^"]+)"/g ;
	$query =~ s/"([^"]+)"//g;
	# - now we throw everything else into terms
	push @terms,split(" ", $query);

	# before we destroy @terms, i want a copy...
	my @tterms = @terms;

	# get the list of searchable fields from the forum_type schema
	my @s_fields;

	foreach my $field (keys %{$e{fields}{schema}}) {
		push @s_fields, $field if ($e{fields}{schema}{$field}{search});
		if ($e{fields}{t_get_posts} !~ /$field/) {
			push @{$e{fields}{get_posts}}, $field;
			$e{fields}{t_get_posts} .= ",$field";
		}
	}

	my $t_search;
	{
		my @s_fields = @s_fields;
		$t_search = "(".shift(@s_fields)." like '\%#{term}\%' or ";

		while (my $field = shift(@s_fields)) {
			$t_search .= "$field like '\%#{term}\%' or ";
		}
	}

	$t_search =~ s! or $!) or !;

	# now break it back apart
	while (my $term = shift(@terms)) {
		$term =~ s/_/\\_/g;
		$term =~ s/\%/\\\%/g;
		my $t_search = $t_search;
		$t_search =~ s/#{term}/$term/gi;
		$sql_query .= $t_search;
	}
	$sql_query =~ s/ or $//g;

	my $find_posts = $db->prepare("
		select id from $e{forum}{main_tbl} where $sql_query
	");

	$core->bail(0,$db->errstr) unless ($find_posts->execute);

	my @ids;
	while (my $id = $find_posts->fetchrow_array) {
		push @ids, $id;
	}

	$core->get_posts(1,@ids) if (@ids);

	# build a static regexp from the wordlist
	my $regexp = join(';', map { "push \@m, /(\$tterms[$_])/io" } 0..$#tterms);
	$regexp = eval "sub { \$_ = shift; my \@m; $regexp; return \@m; }";

	# now we give the ids with more matches higher scores
	{
		my @ids = @ids;
		while (my $id = shift(@ids)) {
			my @fields = @s_fields;
			while (my $field = shift(@fields)) {
				my @m = &$regexp($posts{0}{$id}{$field});
				while ($_ = shift @m) {
					tr/A-Z/a-z/;
					$posts{0}{$id}{matches}{$_}++;
				}
			}
		}	
	}
	my $count;

	# now create a text string of matched words and how many times they matched
	foreach my $id (keys %{$posts{0}}) {
		foreach my $t (keys %{$posts{0}{$id}{matches}}) {
			$posts{0}{$id}{t_matches} .= "$t ($posts{0}{$id}{matches}{$t}), ";
		}
		$posts{0}{$id}{t_matches} =~ s/, $//;
	}

	# generate the new id list based on scores
	sub crazily {
		$a->[2] =~ tr/A-Z/a-z/;
		$b->[2] =~ tr/A-Z/a-z/;
		($b->[1] . $a->[2]) cmp ($a->[1] . $b->[2])
	}

	my @sorted_ids =
		map { $_->[0] }
		sort { crazily }
		map { [ $_,scalar keys %{$posts{0}{$_}{matches}}, $posts{0}{$_}{title} ] }
		(keys %{$posts{0}});


	print $e{look}{search_results_top};
	while (my $id = shift(@sorted_ids)) {
		$_ = $e{look}{search_results_html};
			foreach my $key (keys %{$posts{0}{$id}}) {
				$class->parse_placeholder($key,\$posts{0}{$id}{$key});
			}

			s!#{link}!$e{forum}{path}/$e{script}/$input{forum}/view_post?id=$id!g;
		print;
	}
	print $e{look}{search_results_bottom};

	$core->footer;
}

#----------

=item B<change_forum_prefs>

	$viewer->change_forum_prefs(
		user   => (user_id),
		forum  => (forum_id),
	);

This subroutine allows a forum administrator to change the default prefs for a forum, 
or a user to change their custom prefs.  

=cut

sub change_forum_prefs {
	my $class = shift;
	my %args = (
		@_,
	);

	my %u_prefs;

	# get the forum_type default prefs
	my %prefs = $e{glomule}->prefs;

	if ($input{submit} || !$args{user}) {
		my @ids = $core->build_forum_tree($args{forum});

		my %tmp = $core->g_load_tbl(
			tbl		=> $e{settings}{db}{tbls}{prefs},
			ident	=> 'forum',
			extra	=> "and user = $args{user}",
			ids		=> \@ids,
		);

		while (my $id = shift @ids) {
			foreach my $pref (keys %{$tmp{$id}}) {
				$u_prefs{$pref} = $tmp{$id}{$pref} unless ($u_prefs{$pref});
			}
		}

		# after all the forums get their shots at the prefs, we tack on the forum_type defaults
		foreach my $pref (keys %prefs) {
			$u_prefs{$pref} = $prefs{$pref}{d_val} unless ($u_prefs{$pref});
		}
	}	

	if (!$args{user}) {
		# we don't want to edit the admin's user prefs, only the default 
		# prefs for the forum.
		%{$e{prefs}} = %u_prefs;
	}

	if (!$input{submit}) {

		my @data = ([
			qq(<b>Pref:</b>),
			qq(<b>Descript (default value):</b>),
			qq(<b>Value:</b>)
		]);

		print qq(<form action="$e{forum}{path}/$e{script}/$input{forum}/modify_prefs" method=post>);

		foreach my $pref (keys %prefs) {
			$e{prefs}{$pref} = $prefs{$pref}{d_val} if (!$e{prefs}{$pref});
			push @data, [
				$pref,
				qq(<font size=2>$prefs{$pref}{descript} ($prefs{$pref}{d_val})</font>),
				qq(<input type=text name='$pref' size=20 value='$e{prefs}{$pref}'>)
			];
		}
		
		push @data, [
			qq(<b>Submit:</b>),
			qq(&nbsp;),
			qq(<b><input type=submit name=submit value="Modify Prefs"></b>)
		];

		$core->htmltable_3col(
			title	=> "modify Prefs",
			data	=> \@data,
		);

		print qq(</form>);

	} else {
		my $changes;
		# determine what to do for each pref
		foreach my $pref (keys %prefs) {
			if ($input{$pref} ne $u_prefs{$pref}) {
				$core->set_value(
					tbl			=> $e{settings}{db}{tbls}{prefs},
					key_field	=> 'forum',
					key			=> $args{forum},
					ident		=> $pref,
					value		=> $input{$pref},
					skey_field	=> 'user',
					skey		=> $args{user}
				);
				$changes++;
			} else {
				# they didn't change the field
			}
		}

		if ($changes) {
			# now update the timestamp
#			$core->set_value(
#				tbl			=> $e{settings}{db}{tbls}{prefs},
#				key_field	=> 'forum',
#				key			=> $args{forum},
#				skey_field	=> 'user',
#				skey		=> $args{user},
#				ident		=> 'updated',
#				value		=> time,
#			);

			$core->update_glomule_timestamp(
				tbl			=> $e{settings}{db}{tbls}{prefs},
				key_field	=> 'forum',
				key			=> $args{forum},
				skey_opts	=> {
					skey_field	=> 'user',
					skey		=> $args{user},
				},
				recursive	=> 1,
			);

		}
	
		print <<EOP;
		Your new prefs were written.
		<p>
		<a href="$e{forum}{path}/$e{script}/$input{forum}/options">Return to Options</a>
EOP
	}
}

#----------

sub print_profile {
	my $user = $input{user};
	$core->header("User Profile for $user");

	my $get_user_info = $m_db->prepare("
		select name,email,signature,description
		from $e{settings}{db}{tbls}{users} where username=?
	");
	$core->bail(0,$m_db->errstr) unless ($get_user_info->execute($user));
	my ($name,$email,$signature,$descript) = $get_user_info->fetchrow_array;
	my $options = "&nbsp;"; # why... i believe I have none.
	$_ = $e{look}{profile_html};
		s/#USER/$user/g;
		s!#EMAIL!$email!g;
		s/#NAME/$name/g;
		s/#SIG/$signature/g;
		s/#DESCRIPT/$descript/g;
		s/#OPTIONS/$options/g;
	print;

	$core->footer;
}

#----------

sub posts_by_user {
	my $class = shift;
	my $user = $input{user};
	$core->header("Posts by: $user");

	$core->get_posts(3,$user);

	$class->thread_table_top;
	$class->print_threads(0,0,0);
	$class->thread_table_bottom;

	$core->footer;
}

#----------

sub print_threads {
	my ($class,$parent,$descend,$indent,$already_been_here) = @_;

	# find posts that have been posted within a certain timeframe
	&find_new_posts($parent) if ($e{options}{find_new_posts} && !$already_been_here);

	sub sort_dir {
		my $a = $a->[1];
		my $b = $b->[1];
		$a =~ tr/A-Z/a-z/;
		$b =~ tr/A-Z/a-z/;

		if (!$input{sort_dir} || $input{sort_dir} eq"up") {
			$b cmp $a
		} elsif ($input{sort_dir} eq"down") {
			$a cmp $b
		}
	}

	$input{s_field} = $e{options}{d_sort_field} unless ($input{s_field});

	my @keys = keys %{$posts{$parent}};

	# figure out which ids we want
	my @sorted_ids =
		map { $_->[0] }
		sort { sort_dir }
		map { [ $_, $posts{$parent}{$_}{$input{s_field}} ] }
		(keys %{$posts{$parent}});


	$input{start_num} = 0 unless ($input{start_num});
	
	$input{num_threads} = $e{tweak}{threadsMAX_THREADS_PER_PAGE} unless ($input{num_threads});

	@sorted_ids = splice @sorted_ids, $input{start_num}, $input{num_threads} if (
		$parent == $input{id} && !$e{options}{no_max_threads}
	);

	while (my $id = shift(@sorted_ids)) {
		$class->print_thread($parent,$id,$indent) if (
			$posts{$parent}{$id}{status} == 1 || 
			($e{script} eq"$e{settings}{scripts}{admin}" && $e{user}{rights}{moderate})
		);
		if ($posts{$id}) {
			my $indent = $indent;
			$indent++;	
			$class->print_threads($id,1,$indent,1);
		}
	}
}

#----------

sub print_thread {
	my ($class,$parent,$id,$indent) = @_;
	my %tmp = %{$posts{$parent}{$id}};
	$e{status}{thread_count}++;

	$e{settings}{links}{threads} = "#{path}/#{script}/#{forum}/#{function}?id=#{id}&start_num=#{start_num}&drop=#{drop}&show=#{show}";

	my ($color,$f_color);
	my $even = $e{status}{thread_count}%2;
	if ($even) {
		$color = $e{tweak}{threadsEVEN_ROW_COLOR};
		$f_color = $e{tweak}{threadsEVEN_FONT_COLOR};
	} else {
		$color = $e{tweak}{threadsODD_ROW_COLOR};
		$f_color = $e{tweak}{threadsODD_FONT_COLOR};
	}

	# all icons have a little target stuck to them
	my $icon = qq(<a name="$id"></a>);

	while ($indent--) {
		$icon .= $e{images}{spacer};
	}

	if ($e{rain}{$id}) {
		my $drop = &undrop($id);
		$icon .= qq(
			<a href="$e{forum}{path}/$e{script}/$input{forum}/$input{function}?id=$input{id}&start_num=$input{start_num}&drop=$drop#$id">
		 	$e{images}{dropped_response}</a>
		);
	} elsif ($e{new_posts}{$id}) {
		$_ = $e{images}{split_response_bar};
			s!#{new_drop}!$e{forum}{path}/$e{script}/$input{forum}/$input{function}?id=$input{id}&start_num=$input{start_num}&drop=$input{drop}&show=$e{new_posts}{$id}#$id!gi;
			s!#{drop}!$e{forum}{path}/$e{script}/$input{forum}/$input{function}?id=$input{id}&start_num=$input{start_num}&drop=$input{drop}$id#$id!gi;
			s!#{map}!map$id!gi;
		$icon .= $_;
	} elsif ($tmp{children}) {
		$icon .= qq(		
		<a href="$e{forum}{path}/$e{script}/$input{forum}/$input{function}?id=$input{id}&start_num=$input{start_num}&drop=$input{drop}$id#$id">
		 $e{images}{response_bar}</a>
		);
	} else {
		$icon .= $e{images}{no_response_bar};
	}
	
	if ($e{script} eq $e{settings}{scripts}{admin} && !$tmp{status}) {
		# status 0
		$tmp{title} = "$tmp{title} -- <b>un-approved</b>";
	}

	$_ = $e{look}{thread_html};
		s!#L_START!$e{forum}{path}/$e{script}/$input{forum}!g;
		s/#BG_COLOR/#$color/g;
		s/#F_COLOR/#$f_color/g;
		s/#ICONS/$icon/g;

		foreach my $key (keys %tmp) {
			$class->parse_placeholder($key,\$tmp{$key});
		}

	print;
	
}

#----------

sub find_new_posts {
	my $parent = shift;
	my %new_posts;

	# find posts whose timestamp is within a certain number of seconds before 
	# now, and who have $parent listed as an ancestor

	my $time = (time - ($e{prefs}{new_time}*3600));

	my $parent_check = "($e{settings}{db}{tbls}{bindings}.aid = $parent) and " if ($parent);
	my $status_check;
	if ($e{script} eq"$e{settings}{scripts}{admin}") {
		# we can see everything
	} else {
		$status_check = "and ($e{forum}{main_tbl}.status = 1)";
	}

	my $get_new_posts = $db->prepare("
		select $e{settings}{db}{tbls}{bindings}.aid,$e{forum}{main_tbl}.id 
		from $e{forum}{main_tbl},$e{settings}{db}{tbls}{bindings} 
		where 
			($e{forum}{main_tbl}.id = $e{settings}{db}{tbls}{bindings}.cid) and 
			$parent_check
			($e{forum}{main_tbl}.timestamp >= $time)
			$status_check
			and ($e{settings}{db}{tbls}{bindings}.forum=$e{forum}{id})
	");

	$core->bail(0,"get new posts failed: ".$db->errstr) unless ($get_new_posts->execute);

	while (my ($aid,$cid) = $get_new_posts->fetchrow_array) {
		$new_posts{$aid}{$cid} = 1;
	}
	
	foreach my $aid (keys %new_posts) {
		my $tmp;
		foreach	my $cid (keys %{$new_posts{$aid}}) {
			$tmp .= "$cid,";
		}
		$tmp =~ s/,$//;
		$e{new_posts}{$aid} = $tmp;
	}
}

#----------

sub thread_table_top {
	if ($input{no_thread_table}) {
		return 0;
	}

	my $l_start = "$e{forum}{path}/$e{script}/$input{forum}/$input{function}?id=$input{id}&start_num=$input{start_num}&";
	my $r_dir;

	$input{s_field} = $e{options}{d_sort_field} unless ($input{s_field});

	if ($input{sort_dir} eq"up" || !$input{sort_dir}) {
		$r_dir = "down";
	} else {
		$r_dir = "up";
	}

	$_ = $e{look}{thread_table_top};
		while (m/#{([^}]+)}/g) {
			my $link = $l_start;
			if ($1 eq"$input{s_field}") {
				$link .= "s_field=$1&sort_dir=$r_dir";
			} else {
				$link .= "s_field=$1&sort_dir=$input{sort_dir}";
			}
			s/#{$1}/<a href="$link">/gi;
		}
	print;
}

#----------

sub thread_table_bottom {
	if ($input{no_thread_table}) {
		return 0;
	}

	my ($p_link,$f_link);
	my $p_start_num = ($input{start_num} - $e{tweak}{threadsMAX_THREADS_PER_PAGE});
	my $f_start_num = ($input{start_num} + $e{tweak}{threadsMAX_THREADS_PER_PAGE});
	
	$input{id} = 0 unless $input{id};
	
	my $posts = keys %{$posts{$input{id}}};

	if ($input{start_num}) {
		$p_link = qq(
			<a href="$e{forum}{path}/$e{script}/$input{forum}/$input{function}?id=$input{id}&start_num=$p_start_num&s_field=$input{s_field}&sort_dir=$input{sort_dir}">
			Previous $e{tweak}{threadsMAX_THREADS_PER_PAGE} Posts</a>
		);
	} else {
		$p_link = qq(
			<i>No Previous Posts</i>
		);
	}

	if ($posts > ($input{start_num} + $e{tweak}{threadsMAX_THREADS_PER_PAGE})) {
		my $r_posts;
		
		my $r_posts = ($posts - $input{start_num} - $input{num_threads});

		if ($r_posts > $e{tweak}{threadsMAX_THREADS_PER_PAGE}) {
			$r_posts = $e{tweak}{threadsMAX_THREADS_PER_PAGE};
		}
		$f_link = qq(
			<a href="$e{forum}{path}/$e{script}/$input{forum}/$input{function}?id=$input{id}&start_num=$f_start_num&s_field=$input{s_field}&sort_dir=$input{sort_dir}">
			Next $r_posts Posts</a>
		);
	} else {
		$f_link = qq(
			<i>No Additional Posts</i>
		);
	}

	$_ = $e{look}{thread_table_bottom};
		s/#P_LINK/$p_link/g;
		s/#F_LINK/$f_link/g;
	print;
}

#----------

sub undrop {
	my $id = shift;
	my $puddle; #sorry

	foreach my $drop (keys %{$e{rain}}) {
		$puddle .= ",$drop" unless ($drop == $id);
	}

	$puddle =~ s/^,//g;
	return $puddle;
}

#----------

sub view_post {
	my $class = shift;
	my $options = shift;
	my $other_options = shift;
	my %p = @_;

	if ($p{username}) {
		$other_options .= qq(
			<a href="$e{forum}{path}/$e{script}/$input{forum}/posts_by_user?user=$p{username}">
			Other Posts by $p{poster}</a> - <a href="$e{forum}{path}/$e{script}/$input{forum}/profile?user=$p{username}">
			$p{poster}'s User Profile</a>
		);
	} else {
		# i have no other_options
	}

	$_ = $e{look}{post_html};
		s/#OPTIONS/$options/g;
		s/#O_OPTIONS/$other_options/g;

		foreach my $key (keys %p) {
			$class->parse_placeholder($key,\$p{$key});
		}
	print;
}

#----------

sub compose_post {
	my $class = shift;
	print qq(<form action="$e{forum}{path}/$e{script}/$input{forum}/post" method=post>);
	print qq(<input type=hidden name=child_of value='$input{child_of}'>);
	my ($poster,$email);

	if ($e{user}{username}) {
		$poster	= $e{user}{name};
		$email 	= $e{user}{email};
	} else {
		$poster	= qq(<input type=text name=poster size=20 value="$input{poster}">);
		$email 	= qq(<input type=text name=poster_email size=20 value="$input{poster_email}">);
	}

	$_ = $e{look}{c_post_html};
		s!#{submit}!<input type=submit name=submit value="Post Message">!g;
		s!#{preview}!<input type=submit name=preview value="Preview Message">!g;
		s!#{poster}!$poster!gi;
		s!#{poster_email}!$email!gi;

		foreach my $key (keys %{$e{fields}{schema}}) {
			s!#{$key}!!gi;
		}
	print;

	print "</form>";
}

#----------

# this subroutine takes an inputted message, does the same things to it that post would, 
# and then displays it for the user to see.  They can then choose to edit it or post it.

sub preview_post {
	my $class = shift;
	my %tmp;

	# set up the form for posting or going back to composition
	print qq(<form action="$e{forum}{path}/$e{script}/$input{forum}/post" method=post>);

	# we don't do any wordlist matching in preview mode
	$post::match_words = eval "sub { return 0; }";

	foreach my $field (keys %{$e{fields}{schema}}) {
		my $i_value = $input{$field};

		# run prepare_field on this field to simulate what post would do to the message
		my ($value,$score) = $class->prepare_field($field);
		$tmp{$field} = $value;

		# there has to be a cleaner way to do this.  I'm not quite sure how, 
		# but there's got to be a way to let the browser know that this field 
		# is exactly how I want it, and that I don't want any more escaping done 
		# to it.

		$i_value =~ s/"/%22/g;
		print qq(<input type=hidden name="$field" value="$i_value">);
	}

	$class->view_post(qq(
		<input type=submit name="submit" value="Post Message"></form> 
	),'',%tmp);
}

#----------

sub modify_post {
	my ($class,$id,$require_user) = @_;

	my %p = $core->get_post($id);

	if ($require_user) {
		$core->bail(0,qq(
			You must be the author of a post in order to edit it.
		)) unless ($p{username} eq $e{user}{username});
	}

	$p{body} =~ s/<br>//g;

	$_ = $e{look}{c_post_html};
		foreach my $key (keys %p) {
			$class->parse_placeholder($key,\$p{$key});
		}
		
		s!#{submit}!<input type=submit name="submit" value="Modify Post">!g;
		s!#{preview}!<i>Preview Not Available</i>!g;
	print;
}

#----------

sub parse_placeholder {
	my ($class,$key,$val) = @_;

	if ($e{fields}{schema}{$key}{type} eq"datetime") {
		my $date = $core->timestamp_to_date(${$val},$e{prefs}{datetime_format});
		s/#{$key}/$date/gi;
	} elsif ($e{fields}{schema}{$key}{type} eq"date") {
		my $date = $core->timestamp_to_date(${$val},$e{prefs}{date_format});
		s/#{$key}/$date/gi;
	} else {
		s/#{$key}/${$val}/gi;
	}
}

#----------

sub post {
	my $class = shift;

	my $score;			# lowest score wins
	my $status;			# queued (0) or displayed (1)
	my $fields;			# string version of @fields
	my @values;			# the values for those fields, in the correct order

	my %places;			# we insert placeholders into the values array for a 
						# couple things.  this hash keeps track of what spot in
						# the array those occupy so we can replace them later

	my @r_words;		# restricted words

	# the following two vars are packaged weirdly to get them to &prepare_field

	%post::r_words;		# nothing like duplication
	$post::match_words;	# this sub will be evaluated as a quick check for 
						# restricted words

	# set up the restricted word list so we can check for them in the 
	# appropriate fields

	# get our parent forums
	my @tree = $core->build_forum_tree($e{forum}{id});

	my %words = $core->g_load_tbl(
		tbl		=> $e{settings}{db}{tbls}{filter},
		ident	=> 'forum',
		ids		=> \@tree,
	);

	while (my $id = shift @tree) {
		foreach my $word (keys %{$words{$id}}) {
			if (!defined($post::r_words{$word})) {
				push @r_words, $word;
				$post::r_words{$word} = $words{$id}{$word};
			}
		}
	}

	if (@r_words) {
		# build a static regexp from the wordlist
		my $word_regexp = join('||', map { "m/\$r_words[$_]/o" } 0..$#r_words);
	
		# make word_regexp into a subroutine
		$post::match_words = eval "sub { \$_ = shift; $word_regexp }";
	} else {
		$post::match_words = eval "sub { return 0; }";
	}
	
	# let's go through the fields set up in the forum_type fields schema and 
	# do some processing
	
	foreach my $field (keys %{$e{fields}{schema}}) {
		# run prepare_field on this field.
		my ($value,$w_score) = $class->prepare_field($field);

		# should this score be the post score?
		$score = $w_score unless ($score > $w_score);

		# add this field to our array of fields we'll use later when inserting
		$fields .= "$field,";

		# flag placeholders
		if ($value =~ m!#{([^}]+)}!) {
			# how many values are already in @values?
			my $num_vals = @values;
			$places{$1} = $num_vals;
		}

		push @values, $value;
	}

	# figure out the status based on score and whether this is a moderated forum
	if ($score == 3 || $e{forum}{is_moderated}) {
		$values[$places{status}] = 0;
	} else {
		$values[$places{status}] = 1;
	}

	# get next id for db's that make you do that first
	my $id  = $core->db::get_next_id;
	$values[$places{id}] = $id;

	# strip ending commas
	$fields =~ s/,$//;

	my $num_fields = keys %{$e{fields}{schema}};

	my $placeholders;
	while ($num_fields--) {
		$placeholders .= "?,";
	}

	$placeholders =~ s/,$//;

	# now we should be all set to go ahead and post
	my $post = $db->prepare("
		insert into $e{forum}{main_tbl}($fields) values($placeholders)
	");
	$core->bail(0,"Posting Failed: ".$db->errstr) unless ($post->execute(@values));

	# now fetch the id that post was assigned
	$id = $core->db::get_message_id($post) unless ($id);

	# now we need to create bindings for this post.  it'll be bound to it's parent, 
	# and all ancestors of it's parent
	
	if ($input{child_of}) {
		my $bind = $m_db->prepare("
			insert into $e{settings}{db}{tbls}{bindings}(aid,cid,forum) values(?,?,?)
		");

		$core->bail(0,"binding failed: ".$m_db->errstr) unless (
			$bind->execute($input{child_of},$id,$e{forum}{id})
		);

		my $get_aids = $m_db->prepare("
			select aid from $e{settings}{db}{tbls}{bindings} 
			where cid = $input{child_of} and forum = $e{forum}{id}
		");

		$core->bail(
			0,"couldn't get ancestors of $input{child_of}: ".$m_db->errstr
		) unless ($get_aids->execute);

		while (my $aid = $get_aids->fetchrow_array) {
			$core->bail(0,"binding failed: ".$m_db->errstr) unless (
				$bind->execute($aid,$id,$e{forum}{id})
			);
		}
	} else {
		# binding to 0 is un-needed, so we won't do it
	}

	# send the admin email if the message scored
	if ($score) {
		$core->email(
			to		=> $e{forum}{admin_email},
			subject	=> $e{language}{potential_violation},
			body	=> qq(
A post made in one of your glomules contains a restricted word.  Please 
visit the post to determine the appropriate action.

http://$e{settings}{site_name}$e{forum}{path}/$e{settings}{scripts}{admin}/$input{forum}/view_post?id=$id

			),
		);
	}

	# send a message to the eThreads remailer so that the right people get email
	$class->send_email_notification(
		id	=> $id,
	);

	# ok, now let's print something out.

	if (!$e{forum}{is_moderated} && $score < 3) {
		$_ = $e{language}{post_success};
			s/#TITLE/$input{title}/gi;
			s!#URL!$e{forum}{path}/$e{script}/$input{forum}/view_post?id=$id!g;
		print;
	} else {
		$_ = $e{language}{post_queued};
			if ($input{child_of}) {
				s!#URL!$e{forum}{path}/$e{script}/$input{forum}/view_post?id=$input{child_of}!g;
			} else {
				s!#URL!$e{forum}{path}/$e{script}/$input{forum}/!g;
			}
		print;
	} 
}

#----------

=item B<send_email_notification>

    $viewer->send_email_notification (
		id	=> (message id),
    );

This forum notifies the appropriate people that a new post has been posted.  It 
does this by passing the message off to the eThreads remailer, which determines 
who should be notified and notifies them.

=cut

sub send_email_notification {
	my $class = shift;
	my %args = @_;
	my $auth_string;

	return unless ($e{settings}{email_subs});

	if (!$args{exists}) {
		# the first thing we do is create an auth string
		my @a = (48..57,65..90,97..122);
	
		$auth_string = pack(
			"C7",$a[rand(62)],$a[rand(62)],$a[rand(62)],$a[rand(62)],
			$a[rand(62)],$a[rand(62)],$a[rand(62)]
		);
	
		# log this info in the auth_string tbl
		my $insert_auth_string = $m_db->prepare("
			insert into $e{settings}{db}{tbls}{auth_strings}(
				forum,id,auth_string
			) values(?,?,?)
		");

		$core->bail(0,"insert_auth_string: ".$m_db->errstr) unless (
			$insert_auth_string->execute($e{forum}{id},$args{id},$auth_string)
		);
	} else {
		# get the existing auth string out of the db
		my $get_auth_string = $m_db->prepare("
			select auth_string from $e{settings}{db}{tbls}{auth_strings} 
			where forum = ? and id = ?
		");

		$core->bail(0,"get_auth_string: ".$m_db->errstr) unless (
			$get_auth_string->execute($e{forum}{id},$args{id})
		);

		$auth_string = $get_auth_string->fetchrow_array;
	}

	# now send an email to the remailer
	$core->email(
		to		=> "$e{settings}{remailer}-$e{forum}{id}-$args{id}-$auth_string\@$e{settings}{email_host}",
		from	=> $e{settings}{auto_email_from},
		subject	=> "",
		body	=> "",
	);
}

#----------

# this sub takes a field name as input, grabs the value from $input{$field}, and parses it 
# to determine what should actually go in that field.  It is called by &post and &preview_post

sub prepare_field {
	my ($class,$field) = @_;
	my $score;

	# first of all...  if this field gets a value auto-inserted into it, 
	# there's no point in wasting time parsing.
	if (defined($e{fields}{schema}{$field}{d_value})) {
		return $e{fields}{schema}{$field}{d_value};
		next;
	}

	# if they're logged in, we need to check if there is a default 
	# auth_value.  If so, we'll use that over anything input.
	if (defined($e{fields}{schema}{$field}{auth_value}) && $e{user}{username}) {
		return $e{fields}{schema}{$field}{auth_value};
		next;
	}

	# if they've gotten this far, it must be something they're allowed 
	# to enter
	if ($input{$field}) {
		# parse out html unless people are allowed to post with it
		if ($e{fields}{schema}{$field}{allow_html}) { 
			# allow html
			while ($input{$field} =~ m/<[\s+]?([^\s>]+)[\s+]?([^>]+?)?>/gi) {
				my $key = $1;
				my $tag = $key;
				$tag =~ s!^/!!;
				if ($e{settings}{allowed_tags}{$tag}) {
					# do nothing to the tag
				} else {
					$input{$field} =~ s/<[\s+]?$key[\s+]?$2?>//gi;
				}
			}
		} else {
			# parse it out...  
			$input{$field}	=~ s/<[^>]+>//g;
		}
	

		# add some line breaks
		if ($e{fields}{schema}{$field}{convert_newlines}) {
			$input{$field} =~ s/\n/<br>\n/g;
		}

		# do the quick check for restricted words
		if (&$post::match_words($input{$field})) {
			# doh...  now we have to see how they failed and compute their score
			foreach my $word (keys(%post::r_words)) {
				if ($input{$field} =~ m/$word/i) {
					$score = $post::r_words{$word};

					# if this is a replacement rule, we'll replace
					if ($post::r_words{$word} == 2) {
						$input{$field} =~ s/$word/####/gi;
					} 
				}
			}
		} else {
			# this field passes
		}

	} else {
		# hmmm...  is this field allowed to be left null?
		$core->bail(0,$e{language}{field_left_blank}.$field) if (
			$e{fields}{schema}{$field}{notnull}
		);
	}
	

	# egads, it's hack time.  We're de-escaping some quotation marks
	$input{$field} =~ s/%22/"/g;

	return $input{$field},$score;
}

#----------

#-------------#
# Change Logs #
#-------------#

# $Log: viewer.pm,v $
# Revision 1.28  2000/07/11 18:53:27  eric
# * ummm...  i did stuff...  good stuff, i think.
#   (WTF do you expect?!?!?  It's a 1000+ line diff)
#
# Revision 1.27  2000/07/10 20:54:23  eric
# * merged BCI and tgp devel trees
# * cleaned up some code in forum_info and cache
#
# Revision 1.26  2000/07/10 18:52:04  eric
# * misc
#
# Revision 1.25  2000/06/07 18:14:52  eric
# * glomule creation fixes
# * glomule deletion fixes
# * fixed all old references to presets
# * domain rooting work
# * glomule module work
# * assorted other fixes
#
# Revision 1.24  2000/06/06 00:01:17  eric
# * finished integrating look classes and the preset_headers/preset_data
#
# Revision 1.23  2000/05/11 00:24:23  eric
# * merging in Gospelcom submitted changes
#
# Revision 1.22  2000/05/01 21:10:59  eric
# * a little domain rooting work
# * some fixes for Netscape's sucky CSS handling
#
# Revision 1.21  2000/04/29 16:39:21  eric
# * merging eThreads1_2-devel tree back into main eThreads tree
#
# Revision 1.20.4.9.2.1.2.32  2000/04/22 20:31:07  eric
# * work on the domain rooting code
# * added the glomule::disable_buttons sub to the rest of the glom types
# * added a '</form>' whose absense was dorking up picky CSS
#
# Revision 1.20.4.9.2.1.2.31  2000/04/16 21:49:23  eric
# * fixes in the email calling with regards to moderation
#
# Revision 1.20.4.9.2.1.2.30  2000/04/15 22:49:24  eric
# * made an exception in $core->start to not authenticate if its the
#   view script
# * moved all user notification to the remailer
#
# Revision 1.20.4.9.2.1.2.29  2000/04/12 01:01:33  eric
# * changed some function map syntax
# * corrected some annoying behavior in function_finder
#
# Revision 1.20.4.9.2.1.2.28  2000/04/12 00:12:25  eric
# * fixed a small bug in post preview
#
# Revision 1.20.4.9.2.1.2.27  2000/04/11 00:50:45  eric
# * fixed some timestamp updating
# * fixed language mod caching
#
# Revision 1.20.4.9.2.1.2.26  2000/04/09 20:40:26  eric
# * changes and such...
#
# Revision 1.20.4.9.2.1.2.25  2000/03/27 20:54:38  eric
# * assorted tweaks and fixes
# * rewrote the news glomule module
#
# Revision 1.20.4.9.2.1.2.24  2000/03/11 18:51:19  eric
# * misc. tweaks in the road towards 1.2-stable
#
# Revision 1.20.4.9.2.1.2.23  2000/03/07 23:29:43  eric
# * just making the moderator's life a little easier
#
# Revision 1.20.4.9.2.1.2.22  2000/03/07 22:33:41  eric
# * rewrote restricted wordlist editor to build in support for recursion
#
# Revision 1.20.4.9.2.1.2.21  2000/02/26 15:33:50  eric
# * fixed some quotation mark bugs in the preview->post stuff
#
# Revision 1.20.4.9.2.1.2.20  2000/02/23 06:51:26  eric
# * ummm...  i did stuff.  lots of stuff.
#
# Revision 1.20.4.9.2.1.2.19  2000/02/21 19:09:04  eric
# * updated user information to use new user tbl structure
#
# Revision 1.20.4.9.2.1.2.18  2000/02/16 17:44:38  eric
# * rewrote most of the search engine matching code
# * fixed post modification
#
# Revision 1.20.4.9.2.1.2.17  2000/02/12 02:45:53  eric
# * commiting changes from hosehead
#
# Revision 1.20.4.9.2.1.2.16  2000/01/18 20:18:47  eric
# * fixes in the posting code (fixed bug where name wasn't getting set
#   in un-authenticated posting)
# * moved post inserts over to placeholder system to get rid of need
#   for escaping
#
# Revision 1.20.4.9.2.1.2.15  2000/01/18 00:55:04  eric
# * added search to function map
# * worked on search function
#
# Revision 1.20.4.9.2.1.2.14  2000/01/17 23:07:06  eric
# * moved members script over to function_finder
# * added message preview support to members script
# * started work on going from preview mode back to edit mode
#
# Revision 1.20.4.9.2.1.2.13  2000/01/17 22:39:30  eric
# * message preview is now functional
#
# Revision 1.20.4.9.2.1.2.12  2000/01/13 22:46:59  eric
# * rewrote theme modification code
# * rewrote theme creation code
# * changed theme database structure to split tables with ident,value pair
#
# Revision 1.20.4.9.2.1.2.11  2000/01/13 19:15:04  eric
# * fixed presets caching
# * moved preset fields to db module
# * fixed r_drop with forum ids
#
# Revision 1.20.4.9.2.1.2.10  2000/01/11 01:10:35  eric
# * started changeover to new-style presets table
#
# Revision 1.20.4.9.2.1.2.9  1999/12/22 21:28:52  eric
# * drop to new posts now works
# * renamed router function to function_finder
#
# Revision 1.20.4.9.2.1.2.8  1999/12/22 18:41:16  eric
# * new post code
# * schema work
#
# Revision 1.20.4.9.2.1.2.7  1999/12/21 22:16:28  eric
# * broke the post code mightily
# * started work on drop-to-post
#
# Revision 1.20.4.9.2.1.2.6  1999/11/25 22:09:46  eric
# * re-wrote $viewer->thread_table_top to allow sorting off any field
#
# Revision 1.20.4.9.2.1.2.5  1999/11/25 21:43:19  eric
# * finished transition to forum_type specified data table structure
# * added ability to use any retrieved field in view_post or print_thread
#
# Revision 1.20.4.9.2.1.2.4  1999/11/24 01:04:19  eric
# * changed get_posts over to forum_type based field specs.
#
# Revision 1.20.4.9.2.1.2.3  1999/11/13 20:36:31  eric
# * some sublevel forum fixes in the cache loading sub
# * fixed a call to the wrong db for error info in viewer.pm
#
# Revision 1.20.4.9.2.1.2.2  1999/11/10 18:43:47  eric
# * more function map work
# * changed admin permissions code to utilize function unmapping
# * created calendar module
#
# Revision 1.20.4.9.2.1.2.1  1999/10/16 17:04:50  eric
# * fixed some function map related stuff
# * added code to news forum_type locking down access
#
# Revision 1.20.4.9.2.1  1999/09/21 00:30:45  eric
# * fixed forum modification code
# * fixed typo in post modification code
#
# Revision 1.20.4.9  1999/09/03 12:25:05  eric
# * rolled $u_db into $m_db
#
# Revision 1.20.4.8  1999/08/26 14:04:27  eric
# * updated all headers to conform to standard eThreads header
#
# Revision 1.20.4.7  1999/08/24 20:08:14  eric
# * merging in changes from BCI tree
#
# Revision 1.20.4.6  1999/08/23 16:41:09  eric
# * changed assorted method=get's to method=post
#
# Revision 1.20.4.5  1999/08/18 19:35:11  eric
# * added fork call to instamailer to keep viewer::post from waiting
#   around for it to finish
# * added test in viewer::post to only call instamailer if email_subs
#   are enabled.
#
# Revision 1.20.4.4  1999/08/18 07:43:48  eric
# * finally fixed the last of the $e{forum}{user_tbl} linger calls...  how
#   did those stay around so long?
# * members:   code for unsubscribe and manage_email
# * viewer.pm: code to call instamailer when post made
#
# Revision 1.20.4.3  1999/08/18 06:30:56  eric
# * forum_type modules and code
# * first revision of instamailer (subscription notifier)
# * some subscription code in members
#
# Revision 1.20.4.2  1999/06/25 20:27:16  eric
# * more search code work.  added some new forumset fields for search stuff
#
# Revision 1.20.4.1  1999/06/24 22:37:33  eric
# * started search code
#
# Revision 1.20  1999/06/02 23:54:35  eric
# * removed calls to deleted tweaks
#
# Revision 1.19  1999/05/30 17:47:17  eric
# * thread_table_top: links to sort options
#
# Revision 1.18  1999/05/30 15:57:53  eric
# * fixed sort code to add case insensitivity
#
# Revision 1.17  1999/05/27 00:19:07  eric
# * various changes to get ready for eThreads 0.9
#
# Revision 1.16  1999/05/20 23:16:32  eric
# * updated print_thread to use icontheme syntax
#
# Revision 1.15  1999/05/20 22:53:17  eric
# * fixed profile code
# * temp look hack in icons
#
# Revision 1.14  1999/04/13 23:16:52  eric
# * got rid of old stuff
# * changed post composition to use forum{look}{c_post_html}
#
# Revision 1.13  1999/04/09 06:25:33  eric
# * posts_by_user code
# * print_profile code
# * assorted fixes for other things...
#
# Revision 1.12  1999/04/07 02:43:01  eric
# * removed some old warns
# * added modify_post function
#
# Revision 1.11  1999/04/06 21:30:47  eric
# * forum looks
# 	* modified print_thread & view_post to use forum looks
# 	* added thread_table_top & thread_table_bottom
#
# Revision 1.10  1999/03/26 17:54:51  eric
# * initial sort customization support
#
# Revision 1.9  1999/03/23 23:10:00  eric
# * moved all words and phrases to single hash level
#
# Revision 1.8  1999/03/09 12:02:32  eric
# * added missing " marks in buttons
#
# Revision 1.7  1999/03/07 00:41:39  eric
# * fixed authenticated posting in post subroutine
#
# Revision 1.6  1999/02/27 20:59:15  eric
# * moved eThreads::core start out of viewer->start
#
# Revision 1.5  1999/02/27 17:43:02  eric
# * option tweaks for admin stuff
# * other small tweaks
#
# Revision 1.4  1999/02/19 20:51:38  eric
# * posting!
#
# Revision 1.3  1999/02/09 22:14:39  eric
# * obviously, just stuff...
#
# Revision 1.2  1999/02/07 18:10:15  eric
# * decided some subroutines should stay in the core, so removed them here
#
# Revision 1.1.1.1  1999/02/07 18:04:04  eric
# * eThreads.pm submodules
#

#---------------#
# End of Script #
#---------------#

1;
