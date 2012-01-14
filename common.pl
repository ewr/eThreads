#!/usr/bin/perl
#########################################################
# 	$Id: common.pl,v 1.20 1998/06/13 17:20:48 eric Exp $
#
#	eThreads - Threaded forum software for the web
#	Copyright (C) 1998 Eric Richardson
#
#	This program is free software; you can redistribute it and/or
# 	modify it under the terms of the GNU General Public License
#	as published by the Free Software Foundation; either version 2
#	of the License, or (at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#	For information on eThreads, contact Eric Richardson at 
#	eric@gospelcom.net , or check out the web site at
#	http://www.ericrichardson.com/e-threads/
#
#	This script has all the main display routines
#	for eThreads.  Instead of changing scripting in
#	both view and member, all display changes will
#	be made here.  Only scripting that varies
#	depending on whether the user is logged in or
#	not will be made to the respective scripts.
#
#	$Log: common.pl,v $
#	Revision 1.20  1998/06/13 17:20:48  eric
#	Moved db specific calls to *.module files.  These are specified at
#	system configuration.  All &db_* calls go to these modules.
#
#	Revision 1.18  1998/06/11 13:07:26  eric
#	Added cool little thing to show all threads.
#
#	Revision 1.17  1998/06/09 21:43:58  eric
#	Another patch by Peter Green.  This one let's you ascend and descend
#	while sorting by date.  It also makes that whole segment more fault-
#	tolerant.
#
#	Revision 1.16  1998/06/09 16:21:53  eric
#	Patches from Peter Green.  Threads load faster, assorted other cool fixes.
#
#	Revision 1.15  1998/05/16 20:47:11  eric
#	Replaced text options at the bottom of the screen with
#	graphics.  It'll bump up the size of image sets, but
#	they'll look better.
#
#	Revision 1.14  1998/05/10 21:35:48  eric
#	 - print_drop_tree was displaying too many bars before dropped messages. It
#	   doesn't anymore.
#	 - added height and width tags to the right-arrow and bar graphics in the
#	   little intro on display_main_threads (or whatever that is)
#
#	Revision 1.13  1998/05/09 02:13:38  eric
#	The threads display is now its own subroutine.
#	This allows it to be called from get-post, causing
#	amazing new possibilities.
#
#	Revision 1.12  1998/04/25 16:26:16  eric
#	Moved $dbh connection to common.pl
#	Clarified the hard-coded variables
#	Updated &log_error to send email to admin
#	Cleaned up assorted code
#	 - Thanks to Alan Ritari for these suggestions
#
#	Revision 1.11  1998/04/25 14:15:53  eric
#	Changed hardcoded path in select_group to point to $web_path
#
#	Revision 1.10  1998/04/25 02:11:23  eric
#	Merged get_vars_post into get_vars.
#	Added subroutines from common-post.pl into common.pl
#
#	Revision 1.9  1998/04/23 22:39:45  eric
#	Fixed assorted drop down bugs
#
#	Revision 1.8  1998/04/22 21:55:48  eric
#	Added GPL code to comments.
#
#	Revision 1.7  1998/04/22 20:21:46  eric
#	Removed some leftover debugging information
#
#	Revision 1.6  1998/04/22 16:37:29  eric
#	Added ability to drop infinitely.  Still a problem with the
#	script not displaying posts besides the ones being dropped.
#	That should be easy to fix.
#
#	Revision 1.5  1998/04/22 16:06:46  eric
#	Added two variables for signup from view
#	fixed footer Log In link to point to member
#
#	Revision 1.4  1998/04/21 02:30:33  eric
#	Fixed RCS Id
#
#	Revision 1.3  1998/04/21 02:25:55  eric
#	Playing with RCS stuff
#
#########################################################

# Do not change this line.
use DBI;

BEGIN {
	require "config";
}

# You also need to change the following use DBD:: line to reflect your 
# database type.  For example, for mSQL, you would have...
# use DBD::mSQL;

use DBD::mysql;

# Unless you're hacking the source, you shouldn't have to change anything
# below here.

############################
# - - -  Subroutines - - - #
############################

sub main_topics_list {
	&html_header;

	print <<EOP;
	<FONT SIZE=4>Topics up for discussion:</FONT>
	<font size=3>
	<BR>(?) - Number of replies&nbsp;&nbsp;&nbsp;&nbsp;
	<IMG SRC="$bar" height=10 width=20> = No Replies
	&nbsp;&nbsp;&nbsp;
	<IMG SRC="$right_arrow" height=10 width=20> = One or More Replies
	<P>
EOP
	$id = 0;
	&thread_tree;
	print qq(<a href="$spath/$script?$options&syntax=10">
	<img src="$post_img" border=0 height=30 width=70 alt="post"></a>);

	&html_footer;
}

##########
##########

sub thread_tree {
	# already sorted by date; clicking on 'sort by date' again should reverse the direction
	# option==3 will be descending; option==4 will be ascending (default)
	$asc_desc1 = ($option == 4 ? 3 : 4);
	$asc_desc2 = ($asc_desc1 == 3 ? "desc" : "asc");

	print <<EOP;
	<b>Order By: <a href="$spath/$script?$options&option=1">Subject</a> -
	<a href="$spath/$script?$options&option=2">Poster</a> -
	<a href="$spath/$script?$options&option=$asc_desc1">Date</a></b>
	<table border=0>
	<tr><td width=200>
	<b>Subject:</b>
	</td><td width=100>
	<b>Posted by:</b>
	</td><td width=100>
	<b>Posted on:</b>
	</td></tr>
EOP
	$option = 4 if ($option > 3 || !$option);
	if ($option > 2) {
		$topics = $dbh->prepare("select subject,name,email,id,timestamp from $tbl where replyto=$id order by timestamp $asc_desc2");
	} elsif ($option == 2) {
		$topics = $dbh->prepare("select subject,name,email,id,timestamp from $tbl where replyto=$id order by name");
	} else {
		$topics = $dbh->prepare("select subject,name,email,id,timestamp from $tbl where replyto=$id order by subject");
	}
	unless($topics->execute) {
		&log_error;
	}   
	else {
		$drop_this = $drop;
		@DROP = split(",",$drop);
		
		# build a new table when there are more than twenty entries
		$rowcnt = 20;
		
		while (($subject,$name,$email,$id,$timestamp) = $topics->fetchrow_array) {
			&check_for_replies;
			&time;      
			print "<TR><TD>";
			unless ($drop eq"$id") {
				print qq(<IMG BORDER=0 SRC="$bar" ALT="--" HEIGHT=10 WIDTH=20>) if ($replies == 0);
				print qq(<a href="$spath/$script?$options$more_options&drop=$id"><IMG BORDER=0 SRC="$right_arrow" ALT="->" HEIGHT=10 WIDTH=20></a>($replies)) if ($replies != 0 && $drop_this !~ /$id/);
			}
			print qq(<a href="$spath/$script?$options$more_options"><IMG BORDER=0 SRC="$down_arrow" ALT="\\/" HEIGHT=10 WIDTH=20></a>) if ($drop_this =~ /$id/);
			print qq( <a href="$spath/$script?$options&syntax=20&id=$id">$subject</a></td><td><a href="mailto:$email">$name</a></td><td>$mon/$mday/$year at $hour:$min:$sec</td></tr>);
			$level=1;   
			&print_drop_tree if ($drop == $id);
			
			# twenty entries; make a new table! (count each tree as one entry for ease)
			unless (--$rowcnt) {
				print <<EOP;
				</table><table border=0>
				<tr><td width=200>
				</td><td width=200>
				</td><td width=100>
				</td></tr>
EOP
			}
		}
		print "</table>";
		print <<EOP;
		<P><HR align=left><P>
EOP
	}
}

##########
##########

sub show_all_threads {
	&html_header;

	$print_tree = $dbh->prepare("select subject,id,name,timestamp,replyto from $tbl order by timestamp desc");
	&log_error unless ($print_tree->execute);
	while (($subject,$id,$name,$timestamp,$replyto) = $print_tree->fetchrow_array) {
		$$replyto{$id}{subject} = $subject;
		$$replyto{$id}{name} = $name;
		$$replyto{$id}{timestamp} = $timestamp;
	}

	$thread = 0;
	&list_threads_in_hash;

	&html_footer;
}

sub list_threads_in_hash {	
	foreach $thread_id (keys %$thread) {
		while ($print_level < $level) {
			print "--";
			$print_level++;
		}
		$print_level = 0;
		print "$$thread{$thread_id}{subject} - $thread_id<br>";
		my $old_thread = $thread;
		my $old_level = $level;
		$thread = $thread_id;
		$level++;
		&list_threads_in_hash;
		$level = $old_level;
		$thread = $old_thread;
	}
}

sub print_drop_tree {
	$blah4 = ($level - 3);
	$blah3 = ($level - 2);
	$blah2 = ($level - 1); 
	$drop = $DROP[$blah2];
	$two_drops_ago = $DROP[$blah2];
	$last_drop = $DROP[$blah3];
	$next_drop = $DROP[$level];
	$drop_responses = $dbh->prepare("select subject,id,name,timestamp from $tbl where replyto=$drop");
	if ($drop_responses->execute) {
		while (($subject,$id,$name,$timestamp) = $drop_responses->fetchrow_array) {
			print qq(<tr><td>);
			$blah = 0;
			while ($blah < $level) {
				print qq(<img src="$bar" ALT="--" HEIGHT=10 WIDTH=20>);
				$blah++;
			}
			&check_for_replies;
			print qq(
			<a href="$spath/$script?$options$more_options&drop=$drop_this,$id">
			<img border=0 src="$right_arrow" ALT="->" HEIGHT=10 WIDTH=20>
			</a>($replies)
			) if ($replies != 0 && $drop_this !~ /$id/);

			print qq(
			<a href="$spath/$script?$options$more_options&drop=$two_drops_ago">
			<img src="$down_arrow" ALT="\/" border=0 height=10 width=20></a>
			) if ($drop_this =~ /$id/);

			print qq(
			<img src="$bar" ALT="--" HEIGHT=10 WIDTH=20>
			) if ($replies == 0);
			print qq(
			<A HREF="$spath/$script?$options&id=$id&syntax=20">
			$subject</a></td><td><a href="mailto:$email">$name</a>
			</td><td>$mon/$mday/$year at $hour:$min:$sec</td></tr>
			);

			$level++ if ($id == $next_drop);
			&print_drop_tree if ($id == $next_drop);
		}
	}
}

##########
##########

sub posts_by_sender {
	&html_header;

	$get_posts = $dbh->prepare("select id,subject,timestamp from $tbl where user='$name'");
	
	unless($get_posts->execute) {
		print <<EOP;
		Sorry.  For some reason that query didn't complete.  The user you tried 
		to search on may not be a registered user.  They may have posted without 
		logging in.  Sorry, I'll work on that.
		<p>
		<b>E'</b>
		<p>get_posts: $get_posts
EOP #' <--- this quote is a hack for nedit
	} 
	else {
		$fullname = $dbm->prepare("select fullname from users where username='$name'");
		$fullname->execute;
		$name = $fullname->fetchrow_array if ($fullname);

		print <<EOP;
		<b>Posts by $name</b>:
		<p>
EOP
		while (($id,$subject,$timestamp) = $get_posts->fetchrow_array) {
			&time;
			print qq($mon/$mday/$year at $hour:$min:$sec - <a href="$spath/$script?$options&syntax=20&id=$id">$subject</a><br>);
		}
	}

	&html_footer;
}

##########
##########

sub check_for_replies {
	$replies = 0;
	$get_replies = $dbh->prepare("select posted from $tbl where replyto = $id");
	unless ($get_replies->execute) {
		&log_error;
	} 
	else {
		$replies = $get_replies->rows;
	}
}

##########
##########

sub get_post {
	&html_header;

	$get_message = $dbh->prepare("select name,email,subject,message,timestamp,replyto,user from $tbl where id=$id");
	unless($get_message->execute) {
		&log_error;
	}
	 else {
		$id2 = $id;
		($name,$email,$subject,$message,$timestamp,$replyto,$user) = $get_message->fetchrow_array;
		&time;
		print qq(<a href="$spath/$script?$options&syntax=150&id=$id">D E L E T E</a> - <a href="$spath/$script?$options&syntax=151&id=$id">M O D I F Y</a><br>) if ($admin eq"$who");
		print <<EOP;
		Posted by: $name (<a href="mailto:$email">$email</a>) on $mon/$mday/$year at $hour:$min:$sec
		<br> - <a href="$spath/$script?$options&syntax=30&name=$user">Other Posts by $name</a>
		<p><blockquote>$message</blockquote><p>
EOP
		
		# Print the Thread Tree
		print <<EOP;
EOP
		
		# First, we check to see if there are replies to this post...
		$get_replies = $dbh->prepare("select id from $tbl where replyto=$id");
		$get_replies->execute;
		$replies = $get_replies->rows;

		# If there are no replies, we'll change some stuff so that the tree 
		# is the tree for the post this is a reply to.
		if ($replies <= 0) {
			
			# First, we get the subject, etc. for the previous post...
			$get_replyto_info = $dbh->prepare("select subject,name from $tbl where id=$replyto");
			$get_replyto_info->execute;
			($subject,$name) = $get_replyto_info->fetchrow_array;
			$this_id = $id;
			$id = $replyto;

		}

		# First, we print the info for the top-level post...
		unless ($id == 0) {
			print "No replies to this post.<p>" if ($replies == 0); 
			print "<b>Replies to ";
			print qq(<a href="$spath/$script?$options&syntax=20&id=$id">) if ($replies == 0);
			print "$subject";
			print "</a>" if ($replies == 0);
			print " by $name:</b><p>";
		}
		
		# If we've hit the top, let's let 'em know...
		else {
			print "<br><hr width=200 align=left><br>";
			print "There are no replies to this message.<br>The next level up is the top level.<br>";
			print "<br><hr width=200 align=left><br>";
		}

		&thread_tree unless ($id == 0);


		print qq(<p><a href="$spath/$script?$options&syntax=10&id=$id2">
			<img src="$reply_img" border=0 height=30 width=70 alt="reply"</a>
			<a href="$spath/$script?$options">
			<img src="$up_img" border=0 height=30 width=70 alt="go up"></a>
		);
	}
	&html_footer;
}
##########
##########

sub write_message {
	&html_header;
	
	print <<EOP;
	<b>Enter your message below:</b>
	<form action="$spath/$post_script" METHOD=POST>
	<input type=hidden name=who value="$who">
	<p>
EOP
	unless ($username) {
		print <<EOP;
		<i>You really should become a member, <a href="$spath/$script?$options&syntax=signup">click here to sign up</a></i>
		<input type=hidden name=member value="0">
		<br>Name: <input type=text name="fullname" size=30>
		<br>Email: <input type=text name="email" size=30>
EOP
	}
	print qq(<input type=hidden name=id value="$id">) if ($id);
	if ($username) {
		print qq(<input type=hidden name=username value="$username"><input type=hidden name=password value="$password">);
	}
	
	if ($id) {
		$get_subject = $dbh->prepare("select subject from $tbl where id=$id");
		$get_subject->execute;
		$subject = $get_subject->fetchrow_array if ($get_subject);
	}

	print qq(<input type=hidden name=replyto value="$id">) if ($id);
	print qq(<br>Subject: <input type=text name="subject" size=30>) unless($id);
	print qq(<br>Subject: <input type=text name="subject" size=30 value="Re: $subject">) if($id);
	print <<EOP;
	<br>Message Body:
	<br><textarea name="message" rows=10 cols=50>
</textarea>
	<br>Submit: <font color=#000000><input type=submit name=submit value="Post Your Message"></font>
	</form>
EOP

	
	
	&html_footer;
}

##########
##########

sub admin_delete {
	&html_header;
	&check_for_replies;
	if ($replies == 0) {
		print <<EOP;
		Ok.  This one doesn't have any replies to it.  So we can delete it cleanly.
		<p><a href="$spath/$post_script?$options&syntax=120&id=$id&level=0">Delete message $id</a><p>
EOP #' <--- this quote is a hack for nedit
	}
	if ($replies != 0) {
		print <<EOP;
		There are replies to this message.  Deleting it would leave these replies stranded.
		 You have three options...
		<p> - <a href="$spath/$post_script?$options&syntax=120&id=$id&level=1">Delete Message Contents</a>
		<br> - <a href="$spath/$post_script?$options&syntax=120&id=$id&level=2">Delete Message and All Replies</a>
		<br> - <a href="$spath/$script?$options&syntax=151&id=$id">Modify Message</a><p>
EOP
	}
	&html_footer;
}

##########
##########

sub admin_modify {
	&html_header;

	$get_message_info = $dbh->prepare("select subject,message from $tbl where id=$id");
	unless ($get_message_info->execute) {
		&log_error;
	} 
	else {
		($subject,$body) = $get_message_info->fetchrow_array;
		$body =~ s/<br>//g;
		print <<EOP;
		<b>$subject</b>
		<br><blockquote>$body</blockquote>
		<p><hr><p>
		<form action="$spath/$post_script" METHOD=POST>
		<input type=hidden name="syntax" value="110">
		<input type=hidden name="id" value="$id">
		<input type=hidden name="who" value="$who">
		Subject: <input type=text name=subject value="$subject" size=20>
		<br>
		Body:
		<br><textarea name="message" cols=60 rows=10>
$body
</textarea>
		<br>Submit: <font color=#000000><input type=submit name=submit value="Submit Modified Message">
		</form>
EOP
        }


	&html_footer;
}

##########
##########

sub select_group {
	print "Location: $web_path/e-threads-help.html\n\n" unless($who);
	if ($who) {
		# $dbm is always connected to the main eThreads database
		&db_connect_dbm;
		die "oh no! there's no database" unless ($dbm);
		$get_group = $dbm->prepare("select db,tbl,html_header,html_footer,graphic_option,path from presets where name = '$who'");
		&log_error unless ($get_group->execute);

		($db,$tbl,$html_header,$html_footer,$graphic_option,$path) = $get_group->fetchrow_array;

		# Now we can connect $dbh to their database
		&db_connect_dbh;
		die "uh oh! the database is gone!" unless ($dbh);
	}
}

##########################
# The boring subroutines #
##########################

sub options {
	$password = crypt($password,$who) if ($syntax eq"logon");
	$spath = $path;

	$bar = "$web_path/bar-$graphic_option.gif";
	$right_arrow = "$web_path/right-arrow-$graphic_option.gif";
	$down_arrow = "$web_path/down-arrow-$graphic_option.gif";

	$options_img = "$web_path/options-$graphic_option.gif";
	$reply_img = "$web_path/reply-$graphic_option.gif";
	$post_img = "$web_path/post-$graphic_option.gif";
	$login_img = "$web_path/login-$graphic_option.gif";
	$signup_img = "$web_path/signup-$graphic_option.gif";
	$up_img = "$web_path/up-$graphic_option.gif";

	if ($ENV{'REMOTE_USER'}) {
		$script = "member";
		$post_script = "member-post";
	}
	else {
		$script = "view";
		$post_script = "post";
	}
	$options = "who=$who";
	$more_options = "&option=$option" if ($option);
	$more_options = "$more_options&syntax=$syntax" if ($syntax);
	$more_options = "$more_options&id=$id" if ($id);
}

sub time {
	$time = $timestamp unless (@_);
	# What day is it, anyway?
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp) unless (@_);
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime if (@_);
	$year += $year >= 80 ? 1900 : 2000;

	$mon++;

	$mon = $mon < 10 ? "0$mon" : $mon;
	$mday = $mday < 10 ? "0$mday" : $mday;
	$min = $min < 10 ? "0$min" : $min;
	$sec = $sec < 10 ? "0$sec" : $sec;
}

sub get_vars { 
	# Get the CGI POST input
        if ($ENV{'REQUEST_METHOD'} eq "POST") {
                read(STDIN,$info,$ENV{"CONTENT_LENGTH"});
        } 
	else {
                $info=$ENV{QUERY_STRING};
        }
        foreach (split(/&/,$info)) {
            ($var,$val) = split(/=/,$_,2);
                $var =~ s/\+/ /g;
            $val =~ s/\+/ /g;
            $val =~ s/%([0-9,A-F]{2})/sprintf("%c",hex($1))/ge;
            $value{$var} .= ", " if (defined($value{$var}));
            $value{$var} .= $val;
        }
	
	# Define some variables
	$who = $value{'who'};
	$syntax = $value{'syntax'};
	$fullname = $value{'fullname'};
	$email = $value{'email'};
	$submit = $value{'submit'};
	$drop = $value{'drop'};
	$id = $value{'id'};
	$error = $value{'error'};
	$name = $value{'name'};
	$option = $value{'option'};
	$signup_username = $value{'signup_username'};
	$signup_password = $value{'signup_password'};

	# Variables only for post subroutines

	$subject = $value{'subject'};
	$subject =~ s/\'/\\\'/g;
	$subject =~ s/</&lt\;/g;
	$subject =~ s/\n/<br>/g;
	$message = $value{'message'};
	$message =~ s/\'/\\\'/g;
	$message =~ s/</&lt\;/g;
	$message =~ s/\n/<br>/g;
	$email = $value{'email'};
	$email =~ s/\'/\\\'/g;
	$fullname = $value{'fullname'};
	$fullname =~ s/\'/\\\'/g;
	$replyto = $value{'replyto'};
	$level = $value{'level'};
	$new_username = $value{'new_username'};
	$new_password = $value{'new_password'};
	$old_username = $value{'old_username'};
	$new_fullname = $value{'new_fullname'};
	$new_email = $value{'new_email'};
}

sub html_header {
	print "Content-type: text/html\n\n" unless ($html);
	print "$html_header";
	print "<b>A D M I N I S T R A T I V E&nbsp;&nbsp;&nbsp;I N T E R F A C E</b><p>" if ($admin eq"$who");
	print "You are logged in as: <i>$username</i><p>" if ($username);
}

sub html_footer {

	print qq(<a href="$spath/$script?$options&syntax=75">
		<img src="$options_img" border=0 height=30 width=70 alt="options"></a>
	) if ($username);
	print qq(
		<a href="$spath/member?$options">
		<img src="$login_img" border=0 height=30 width=70 alt="login"></a>
		<a href="$spath/$script?$options&syntax=signup">
		<img src="$signup_img" height=30 width=70 alt="signup" border=0></a>
	) unless($username);
	print "$html_footer";
}

sub log_error {

	# let's see if it was an error passed to the subroutine from
        # somewhere or a database error...
        my $errmsg = $_[0] || $dbh->errstr;

        print "$errmsg... blah blah blah";
        if (system("$mail_program -s'eThreads error' $admin_email < $errmsg")) {
		$admin_notified = 1;
        }

	print "Content-type: text/html\n\n" unless ($html);
	$errmsg = $dbh->errstr;
	print <<EOP;
	<HTML><BODY>
	<h1>Error!</h1>
	<p>Sorry, but the eThreads engine was unable to complete your query. 
	Please inform the owner of the page that linked you to this address, 
	or, if you typed the address, check the URL you entered.  If this 
	appears and you are sure the URL was working before, please email 
	<a href="mailto:$admin_email">$admin_email</a>.
	<p>
EOP
	print "The Administrator was notified with a copy of the error." if ($admin_notified); 
	print <<EOP;
	<p>
	 - The eThreads Team
EOP

die;

}

################################
# # # # Post subroutines # # # #
################################

sub post_message {
	$replyto = $id if($id);
	$replyto = 0 unless($id);

	$timestamp = time;

	&db_post_message;

	$results_from_post = $dbh->do($post_message);
	&log_error unless ($results_from_post);
}

##########
##########

sub modify_message_user {
        $get_current_info = $dbh->prepare("select subject,message,user,name from $tbl where id=$id");
        unless ($get_current_info->execute) {
                &log_error;
        } 
	else {
                $timestamp = time;
                ($subject_old,$message_old,$user_old,$name_old) = $get_current_info->fetchrow_array;
                $subject = $subject_old unless($subject);
                $message = $message_old unless($message);
                $post_update = "update $tbl set subject='$subject', message='$message', timestamp=$timestamp where id=$id and user='$username'";
                &log_error unless ($posted_update = $dbh->do($post_update));
        }
}

##########
##########

sub delete_message_user {
        &check_for_replies;
        if ($replies == 0) {
                $delete_message = "delete from $tbl where id=$id and user='$username'";
                $deleted = $dbh->do($delete_message);
                &log_error unless($deleted);
        }
}

##########
##########

sub modify_message_admin {
        $get_current_info = $dbh->prepare("select subject,message from $tbl where
 id=$id");
        unless ($get_current_info->execute) {
                &log_error;
        } 
	else {
                ($subject_old,$message_old) = $get_current_info->fetchrow_array;
                $subject = $subject_old unless($subject);
                $message = $message_old unless($message);
                $post_update = "update $tbl set subject='$subject', message='$message' where id=$id";
                $posted_update = $dbh->do($post_update);
                &log_error unless ($posted_update);
        }
}

##########
##########

sub delete_message_admin {
        if ($level == 0) {
                $delete_message = "delete from $tbl where id=$id";
                $deleted = $dbh->do($delete_message);
                &log_error unless($deleted);
        }
        if ($level == 1) {
                $delete_message_contents = "update $tbl set message='This message\\'s contents were deleted by the administrator.' where id=$id";
                $deleted = $dbh->do($delete_message_contents);
                &log_error unless($deleted);
        }
        if ($level == 2) {
                # First, we delete the original message
                $dbh->do("delete from $tbl where id=$id");
                # Now we try to find replies to that message
                # Hold on, this could get ugly
                $replyto = $id;
                &delete_code;
        }
}

##########
##########

sub delete_code {
        &check_for_replies;
        if ($replies != 0) {
                $find_replies = $dbh->prepare("select id from $tbl where replyto=$id");
                $find_replies->execute;
                while (($id) = $find_replies->fetchrow_array) {
                        &delete_code;
                        $delete = "delete from $tbl where id=$id";
                        $deleted = $dbh->do($delete);
                }
        }
}

##########
##########

sub modify_user_profile {
	&options;
	# If the new username is different from the old username, let's check if someone 
	# else has the new one
	
	# First things first, let's make sure the new username isn't null.
	print "Location: $spath/member?$options&syntax=76&error=20\n\n" unless($new_username);
	die unless ($new_username);
	
	if ($new_username ne"$old_username") {
		$check_for_existing_user = $dbm->prepare("select username from users where username='$new_username'");
		unless ($check_for_existing_user->execute) {
			&log_error;
		}
		else {
			($username_exists) = $check_for_existing_user->fetchrow_array;
			print "Location: $spath/member?$options&syntax=76&error=10\n\n" if ($username_exists);
			die if ($username_exists);
		}
		
		# Now, if the new username is free, we'll create a new entry, then delete the old one
		unless ($username_exists) {
			# First we create the new entry
			&log_error unless ($create_new_user = $dbm->do("insert into users(username,password,fullname,email) values('$new_username','$new_password','$new_fullname','$new_email'"));
			
			# If that went through, we can delete the old entry
			&log_error unless ($delete_old_user = $dbm->do("delete from users where username='$old_username'"));
			
			# They should be done now, let's send 'em back
			print "Location: $spath/member?$options\n\n";
			die;
		}
	}
	
	# If the username is the same, they just wanted to change something easy.
	if ($new_username eq"$old_username") {
		#First we get the old information
		$get_old_info = $dbm->prepare("select password,email,fullname from users where username='$old_username'");
		unless ($get_old_info->execute) {
			&log_error;
		}
		else {
			($old_password,$old_email,$old_fullname) = $get_old_info->fetchrow_array;
		}
		# Now we encrypt the new password, unless it's blank.
		$new_password = crypt(k9,$new_password) if ($new_password);
		
		# We don't like empty values
		$new_fullname = $old_fullname unless ($fullname);
		$new_email = $old_email unless ($email);
		$new_password = $old_password unless ($new_password);
		
		# Now we update their record in the database
		&log_error unless ($update_user_info = $dbm->do("update users set password='$new_password', fullname='$new_fullname', email='$new_email' where username='$new_username'"));
		
		# If we made it this far, let's send them back to member. 
		print "Location: $spath/member?$options\n\n";
		die;
	}
}

##################################
# # # # End of subroutines # # # #
##################################

1;
