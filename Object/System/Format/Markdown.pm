package eThreads::Object::System::Format::Markdown;

@ISA = qw( eThreads::Object::System::Format );

use strict;

use Digest::MD5;

#----------

sub new {
	my $class = shift;
	my $switch = shift;

	$class = bless( { _=>$switch } , $class );

	return $class;
}

#----------

sub activate {
	my $class = shift;

	$class->{g} = $class->_init_globals;

	return $class;
}

#----------

sub format {
	my $class = shift;
	my $text = shift;

	my $sum = Digest::MD5::md5_hex($text);

	if (my $ftxt = $class->{_}->cache->memory->get_raw("markdown",$sum)) {
		return $ftxt;
	} else {
		my $ftxt = $class->Markdown($text);
		$class->{_}->cache->memory->set_raw("markdown",$sum,$ftxt);
		return $ftxt;
	}
}

#----------

sub _init_globals {
	my $class = shift;

	my $g = {};

	$g->{nested_brackets} = qr{
		(?>
		   [^\[\]]+
		 |
		   \[
			(??{ $g->{nested_brackets} })
		\]
		)*
	}x;

	$g->{escape_table} = {};
	# Table of hash values for escaped characters:
	foreach my $char (split //, '\\`*_{}[]()#.!') {
		$g->{escape_table}{$char} = Digest::MD5::md5_hex($char);
	}

	$g->{html_blocks} 	= {};
	$g->{urls} 			= {};
	$g->{titles} 		= {};

	$g->{empty_element_suffix} = " />";     # Change to ">" for HTML output
	$g->{tab_width} = 4;

	return $g;
}

#----------

sub Markdown {
	#
	# Main function. The order in which other subs are called here is
	# essential. Link and image substitutions need to happen before
	# _EscapeSpecialChars(), so that any *'s or _'s in the <a>
	# and <img> tags get encoded.
	#

	my $class = shift;
	my $text = shift;

	# Clear the global hashes. If we don't clear these, you get conflicts
	# from other articles when generating a page which contains more than
	# one article (e.g. an index page that shows the N most recent
	# articles):
	#%g_urls = ();
	#%g_titles = ();
	#%g_html_blocks = ();

	# Standardize line endings:
	$text =~ s{\r\n}{\n}g; 	# DOS to Unix
	$text =~ s{\r}{\n}g; 	# Mac to Unix

	# Make sure $text ends with a couple of newlines:
	$text .= "\n\n";
	
	# Convert all tabs to spaces.
	$text = $class->_Detab($text);

	# Strip any lines consisting only of spaces and tabs.
	# This makes subsequent regexen easier to write, because we can
	# match consecutive blank lines with /\n+/ instead of something
	# contorted like /[ \t]*\n+/ .
	$text =~ s/^[ \t]+$//mg;

	# Turn block-level HTML blocks into hash entries
	$text = $class->_HashHTMLBlocks($text);

	# Strip link definitions, store in hashes.
	$text = $class->_StripLinkDefinitions($text);

	# _EscapeSpecialChars() must be called very early, to get
	# backslash escapes processed.
	$text = $class->_EscapeSpecialChars($text);

	$text = $class->_RunBlockGamut($text);

	$text = $class->_UnescapeSpecialChars($text);

	return $text . "\n";
}

sub _RunBlockGamut {
#
# These are all the transformations that form block-level
# tags like paragraphs, headers, and list items.
#
	my $class = shift;
	my $text = shift;

	$text = $class->_DoHeaders($text);

	# Do Horizontal Rules:
	$text =~ s{^( ?\* ?){3,}$}{\n<hr$class->{g}{empty_element_suffix}\n}gm;
	$text =~ s{^( ?- ?){3,}$}{\n<hr$class->{g}{empty_element_suffix}\n}gm;

	$text = $class->_DoLists($text);

	$text = $class->_DoCodeBlocks($text);

	$text = $class->_DoBlockQuotes($text);

	# Make links out of things like `<http://example.com/>`
	$text = $class->_DoAutoLinks($text);

	# We already ran _HashHTMLBlocks() before, in Markdown(), but that
	# was to escape raw HTML in the original Markdown source. This time,
	# we're escaping the markup we've just created, so that we don't wrap
	# <p> tags around block-level tags.
	$text = $class->_HashHTMLBlocks($text);

	$text = $class->_FormParagraphs($text);

	return $text;
}


sub _RunSpanGamut {
#
# These are all the transformations that occur *within* block-level
# tags like paragraphs, headers, and list items.
#

	my $class = shift;
	my $text = shift;

	$text = $class->_DoCodeSpans($text);

	# Fix unencoded ampersands and <'s:
	$text = $class->_EncodeAmpsAndAngles($text);

	# Process anchor and image tags. Images must come first,
	# because ![foo][f] looks like an anchor.
	$text = $class->_DoImages($text);
	$text = $class->_DoAnchors($text);


	$text = $class->_DoItalicsAndBold($text);
	
	# Do hard breaks:
	$text =~ s/ {2,}\n/ <br$class->{g}{empty_element_suffix}\n/g;

	return $text;
}


sub _DoAutoLinks {
	my $class = shift;
	my $text = shift;

	$text =~ s{<((https?|ftp):[^'">\s]+)>}{<a href="$1">$1</a>}gi;
	
	# Email addresses: <address@domain.foo>
	$text =~ s{
		<
		(
			[-.\w]+
			\@
			[-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+
		)
		>
	}{
		$class->_EncodeEmailAddress($1);
	}egix;
	
	return $text;
}


sub _EncodeEmailAddress {
#
#	Input: an email address, e.g. "foo@example.com"
#
#	Output: the email address as a mailto link, with each character
#		of the address encoded as either a decimal or hex entity, in
#		the hopes of foiling most address harvesting spam bots. E.g.:
#
#	  <a href="&#x6D;&#97;&#105;&#108;&#x74;&#111;:&#102;&#111;&#111;&#64;&#101;
#       x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;">&#102;&#111;&#111;
#       &#64;&#101;x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;</a>
#
#	Based on a filter by Matthew Wickline, posted to the BBEdit-Talk
#	mailing list: <http://tinyurl.com/yu7ue>
#

	my $class = shift;
	my $addr = shift;

	srand;
	my @encode = (
		sub { '&#' .                 ord(shift)   . ';' },
		sub { '&#x' . sprintf( "%X", ord(shift) ) . ';' },
		sub {                            shift          },
	);

	$addr = "mailto:" . $addr;

	$addr =~ s{(.)}{
		my $char = $1;
		if ( $char eq '@' ) {
			# this *must* be encoded. I insist.
			$char = $encode[int rand 1]->($char);
		} elsif ( $char ne ':' ) {
			# leave ':' alone (to spot mailto: later)
			my $r = rand;
			# roughly 10% raw, 45% hex, 45% dec
			$char = (
				$r > .9   ?  $encode[2]->($char)  :
				$r < .45  ?  $encode[1]->($char)  :
							 $encode[0]->($char)
			);
		}
		$char;
	}gex;

	$addr = qq{<a href="$addr">$addr</a>};
	$addr =~ s{">.+?:}{">}; # strip the mailto: from the visible part

	return $addr;
}


sub _HashHTMLBlocks {
	my $class = shift;
	my $text = shift;

	# Hashify HTML blocks:
	# We only want to do this for block-level HTML tags, such as headers,
	# lists, and tables. That's because we still want to wrap <p>s around
	# "paragraphs" that are wrapped in non-block-level tags, such as anchors,
	# phrase emphasis, and spans. The list of tags we're looking for is
	# hard-coded:
	my $block_tag_re = qr/p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script/;
	
	# First, look for nested blocks, e.g.:
	# 	<div>
	# 		<div>
	# 		tags for inner block must be indented.
	# 		</div>
	# 	</div>
	#
	# The outermost tags must start at the left margin for this to match, and
	# the inner nested divs must be indented.
	# We need to do this before the next, more liberal match, because the next
	# match will start at the first `<div>` and stop at the first `</div>`.
	$text =~ s{
				(						# save in $1
					^					# start of line  (with /m)
					<($block_tag_re)	# start tag = $2
					\b					# word break
					(.*\n)*?			# any number of lines, minimally matching
					</\2>				# the matching end tag
					[ \t]*				# trailing spaces/tabs
					(?=\n+|\Z)	# followed by a newline or end of document
				)
			}{
				my $key = Digest::MD5::md5_hex($1);
				$class->{g}{html_blocks}{$key} = $1;
				"\n\n" . $key . "\n\n";
			}egmx;


	#
	# Now match more liberally, simply from `\n<tag>` to `</tag>\n`
	#
	$text =~ s{
				(						# save in $1
					^					# start of line  (with /m)
					<($block_tag_re)	# start tag = $2
					\b					# word break
					(.*\n)*?			# any number of lines, minimally matching
					.*</\2>				# the matching end tag
					[ \t]*				# trailing spaces/tabs
					(?=\n+|\Z)	# followed by a newline or end of document
				)
			}{
				my $key = Digest::MD5::md5_hex($1);
				$class->{g}{html_blocks}{$key} = $1;
				"\n\n" . $key . "\n\n";
			}egmx;
	# Special case just for <hr />. It was easier to make a special case than
	# to make the other regex more complicated.	
	$text =~ s{
				(?:
					(?<=\n\n)		# Starting after a blank line
					|				# or
					\A\n?			# the beginning of the doc
				)
				(						# save in $1
					[ \t]*
					<(hr)				# start tag = $2
					\b					# word break
					([^<>])*?			# 
					/?>					# the matching end tag
					(?=\n{2,}|\Z)		# followed by a blank line or end of document
				)
			}{
				my $key = Digest::MD5::md5_hex($1);
				$class->{g}{html_blocks}{$key} = $1;
				"\n\n" . $key . "\n\n";
			}egx;

	return $text;
}


sub _StripLinkDefinitions {
#
# Strips link definitions from text, stores the URLs and titles in
# hash references.
#
	my $class = shift;
	my $text   		= shift;

	# Link defs are in the form: ^[id]: url "optional title"
	while ($text =~ s{
						^[ \t]*\[(.+)\]:	# id = $1
						  [ \t]*
						  \n?				# maybe *one* newline
						  [ \t]*
						(\S+)				# url = $2
						  [ \t]*
						  \n?				# maybe one newline
						  [ \t]*
						(?:
							# Todo: Titles are delimited by "quotes" or (parens).
							["(]
							(.+?)			# title = $3
							[")]
							[ \t]*
						)?	# title is optional
						(?:\n+|\Z)
					}
					{}mx) {
		$class->{g}{urls}{lc $1} = $2;	# Link IDs are case-insensitive
		if ($3) {
			$class->{g}{titles}{lc $1} = $3;
			$class->{g}{titles}{lc $1} =~ s/"/&quot;/g;
		}
	}

	return $text;
}


sub _DoImages {
	#
	# Turn Markdown image shortcuts into <img> tags.
	#

	my $class = shift;
	my $text   		= shift;

	#
	# First, handle reference-style labeled images: ![alt text][id]
	#
	$text =~ s{
		(				# wrap whole match in $1
		  !\[
		    (.*?)		# alt text = $2
		  \]
		  [ \t]?		# optional space or tab
		  \[
		    (.+?)		# id = $3
		  \]
		  
		)
	}{
		my $result;
		my $whole_match = $1;
		my $alt_text    = $2;
		my $link_id     = lc $3;

		if (defined $class->{g}{urls}{$link_id}) {
			my $url = $class->{g}{urls}{$link_id};
			$url =~ s! \* !&#42;!gx;		# We've got to encode these to avoid
			$url =~ s! _  !&#95;!gx;		# conflicting with italics/bold.
			$result = "<img src=\"$url\" alt=\"$alt_text\"";
			if (defined $class->{g}{titles}{$link_id}) {
				my $title = $class->{g}{titles}{$link_id};
				$title =~ s! \* !&#42;!gx;
				$title =~ s! _  !&#95;!gx;
				$result .=  " title=\"$title\"";
			}
			$result .= $class->{g}{empty_element_suffix};
		}
		else {
			# If there's no such link ID, leave intact:
			$result = $whole_match;
		}

		$result;
	}xsge;

	#
	# Next, handle inline images:  ![alt text] (url "optional title")
	# Don't forget: encode * and _

	$text =~ s{
		(				# wrap whole match in $1
		  !\[
		    (.*?)		# alt text = $2
		  \]
		  \(			# literal paren
		  	[ \t]*
			(\S+)		# src url = $3
		  	[ \t]*
			(			# title = $4
			  (['"])	# quote char = $5
			  .*
			  \5		# matching quote
			  [ \t]*
			)?			# title is optional
		  \)
		)
	}{
		my $result;
		my $whole_match = $1;
		my $alt_text    = $2;
		my $url	  		= $3;
		my $title		= $4;

		$url =~ s! \* !&#42;!gx;		# We've got to encode these to avoid
		$url =~ s! _  !&#95;!gx;		# conflicting with italics/bold.
		$result = "<img src=\"$url\" alt=\"$alt_text\"";
		if (defined $title) {
			$title =~ s! \* !&#42;!gx;
			$title =~ s! _  !&#95;!gx;
			$result .=  " title=$title"; # $title already quoted
		}
		$result .= $class->{g}{empty_element_suffix};

		$result;
	}xsge;

	return $text;
}


sub _DoAnchors {
	#
	# Turn Markdown link shortcuts into XHTML <a> tags.
	#

	my $class = shift;
	my $text   		= shift;

	#
	# First, handle reference-style links: [link text] [id]
	#
	$text =~ s{
		(					# wrap whole match in $1
		  \[
		    ($class->{g}{nested_brackets})	# link text = $2
		  \]
		  [ ]?				# one optional space
		  \[(.*?)\]			# link ID = $3
		)
	}{
		my $result;
		my $whole_match = $1;
		my $link_text   = $2;
		my $link_id     = lc $3;

		if ($link_id eq "") {
			$link_id = lc $link_text;     # for shortcut links like [this][].
		}

		if (defined $class->{g}{urls}{$link_id}) {
			my $url = $class->{g}{urls}{$link_id};
			$url =~ s! \* !&#42;!gx;		# We've got to encode these to avoid
			$url =~ s! _  !&#95;!gx;		# conflicting with italics/bold.
			$result = "<a href=\"$url\"";
			if ( defined $class->{g}{titles}{$link_id} ) {
				my $title = $class->{g}{titles}{$link_id};
				$title =~ s! \* !&#42;!gx;
				$title =~ s! _  !&#95;!gx;
				$result .=  " title=\"$title\"";
			}
			$result .= ">$link_text</a>";
		}
		else {
			$result = $whole_match;
		}
		$result;
	}xsge;

	#
	# Next, inline-style links: [link text](url "optional title")
	#
	$text =~ s{
		(				# wrap whole match in $1
		  \[
		    ($class->{g}{nested_brackets})	# link text = $2
		  \]
		  \(			# literal paren
		  	[ \t]*
			(.+?)		# href = $3
		  	[ \t]*
			(			# title = $4
			  (['"])	# quote char = $5
			  .*
			  \5		# matching quote
			)?			# title is optional
		  \)
		)
	}{
		my $result;
		my $whole_match = $1;
		my $link_text   = $2;
		my $url	  		= $3;
		my $title		= $4;

		$url =~ s! \* !&#42;!gx;		# We've got to encode these to avoid
		$url =~ s! _  !&#95;!gx;		# conflicting with italics/bold.
		$result = "<a href=\"$url\"";
		if ($title) {
			$title =~ s! \* !&#42;!gx;
			$title =~ s! _  !&#95;!gx;
			$result .=  " title=$title";
		}
		$result .= ">$link_text</a>";

		$result;
	}xsge;

	return $text;
}


sub _DoHeaders {
	my $class = shift;
	my $text = shift;

	# Setext-style headers:
	#	  Header 1
	#	  ========
	#  
	#	  Header 2
	#	  --------
	#
	$text =~ s{ (.+)[ \t]*\n=+[ \t]*\n+ }{
		"<h1>"  .  $class->_RunSpanGamut($1)  .  "</h1>\n\n";
	}egx;
	
	$text =~ s{ (.+)[ \t]*\n-+[ \t]*\n+ }{
		"<h2>"  .  $class->_RunSpanGamut($1)  .  "</h2>\n\n";
	}egx;


	# atx-style headers:
	#	# Header 1
	#	## Header 2
	#	## Header 2 with closing hashes ##
	#	...
	#	###### Header 6
	#
	$text =~ s{
			^(\#{1,6})	# $1 = string of #'s
			[ \t]*
			(.+?)		# $2 = Header text
			[ \t]*
			\#*			# optional closing #'s (not counted)
			\n+
		}{
			my $h_level = length($1);
			"<h$h_level>"  .  $class->_RunSpanGamut($2)  .  "</h$h_level>\n\n";
		}egmx;

	return $text;
}


sub _DoLists {
	#
	# Form HTML ordered (numbered) and unordered (bulleted) lists.
	#
	my $class = shift;
	my $text = shift;
	my $less_than_tab = $class->{g}{tab_width} - 1;

	$text =~ s{
			(
			  (
			    ^[ ]{0,$less_than_tab}
			    (\*|\d+[.])
			    [ \t]+
			  )
			  (?s:.+?)
			  (
			      \z
			    |
				  \n{2,}
				  (?=\S)
				  (?![ \t]* (\*|\d+[.]) [ \t]+)
			  )
			)
		}{
			my $list_type = ($3 eq "*") ? "ul" : "ol";
			my $list = $1;
			# Turn double returns into triple returns, so that we can make a
			# paragraph for the last item in a list, if necessary:
			$list =~ s/\n{2,}/\n\n\n/g;
			my $result = $class->_ProcessListItems($list);
			$result = "<$list_type>\n" . $result . "</$list_type>\n";
			$result;
		}egmx;

	return $text;
}

sub _ProcessListItems {
	my $class = shift;
	my $list_str = shift;

	# trim trailing blank lines:
	$list_str =~ s/\n{2,}\z/\n/;


	$list_str =~ s{
		(\n)?							# leading line = $1
		(^[ \t]*)						# leading whitespace = $2
		(\*|\d+[.]) [ \t]+				# list marker = $3
		((?s:.+?)						# list item text   = $4
		(\n{1,2}))
		(?= \n* (\z | \2 (\*|\d+[.]) [ \t]+))
	}{
		my $item = $4;
		my $leading_line = $1;
		my $leading_space = $2;

		if ($leading_line or ($item =~ m/\n{2,}/)) {
			$item = $class->_RunBlockGamut($class->_Outdent($item));
			#$item =~ s/\n+/\n/g;
		}
		else {
			# Recursion for sub-lists:
			$item = $class->_DoLists($class->_Outdent($item));
			chomp $item;
			$item = $class->_RunSpanGamut($item);
		}

		"<li>" . $item . "</li>\n";
	}egmx;

	return $list_str;
}



sub _DoCodeBlocks {
	#
	#	Process Markdown `<pre><code>` blocks.
	#	

	my $class = shift;
	my $text = shift;

	$text =~ s{
			(.?)			# $1 = preceding character
			(:)				# $2 = colon delimiter
			(\n+)			# $3 = newlines after colon
			(	            # $4 = the code block -- one or more lines, starting with a space/tab
			  (?:
			    (?:[ ]{$class->{g}{tab_width}} | \t)  # Lines must start with a tab or a tab-width of spaces
			    .*\n+
			  )+
			)
			((?=^[ ]{0,$class->{g}{tab_width}}\S)|\Z)	# Lookahead for non-space at line-start, or end of doc
		}{
			my $prevchar  = $1;
			my $newlines  = $3;
			my $codeblock = $4;

			my $result; # return value
			
			#
			# Check the preceding character before the ":". If it's not
			# whitespace, then the ":" remains; if it is whitespace,
			# the ":" disappears completely, along with the space character.
			#
			my $prefix = "";
			unless (($prevchar =~ m/\s/) or ($prevchar eq "")) {
					$prefix = "$prevchar:";
			}
			$codeblock = $class->_EncodeCode($class->_Outdent($codeblock));
			$codeblock = $class->_Detab($codeblock);
			$codeblock =~ s/\A\n+//; # trim leading newlines
			$codeblock =~ s/\s+\z//; # trim trailing whitespace

			$result = $prefix . "\n\n<pre><code>" . $codeblock . "\n</code></pre>\n\n";

			$result;
		}egmx;

	return $text;
}


sub _DoCodeSpans {
	#
	# 	*	Backtick quotes are used for <code></code> spans.
	# 
	# 	*	You can use multiple backticks as the delimiters if you want to
	# 		include literal backticks in the code span. So, this input:
	#     
	#         Just type ``foo `bar` baz`` at the prompt.
	#     
	#     	Will translate to:
	#     
	#         <p>Just type <code>foo `bar` baz</code> at the prompt.</p>
	#     
	#		There's no arbitrary limit to the number of backticks you
	#		can use as delimters. If you need three consecutive backticks
	#		in your code, use four for delimiters, etc.
	#
	#	*	You can use spaces to get literal backticks at the edges:
	#     
	#         ... type `` `bar` `` ...
	#     
	#     	Turns to:
	#     
	#         ... type <code>`bar`</code> ...
	#

	my $class = shift;
	my $text = shift;

	my $backtick_count;

	$text =~ s@
			(`+)		# Opening run of `
			(.+?)		# the code block
			(?<!`)
			(??{ $backtick_count = length $1; "`{$backtick_count}";  })
			(?!`)
		@
			my $c = $2;
			$c =~ s/^[ \t]*//g; # leading whitespace
			$c =~ s/[ \t]*$//g; # trailing whitespace
			$c = $class->_EncodeCode($c);
			"<code>$c</code>";
		@egsx;

	return $text;
}


sub _DoItalicsAndBold {
	my $class = shift;
	my $text = shift;

	# <strong> must go first:
	$text =~ s{ (\*\*|__) (?=\S) (.+?) (?<=\S) \1 }{<strong>$2</strong>}gsx;
	# Then <em>:
	$text =~ s{ (\*|_) (?=\S) (.+?) (?<=\S) \1 }{<em>$2</em>}gsx;

	return $text;
}


sub _DoBlockQuotes {
	my $class = shift;
	my $text = shift;

	$text =~ s{
		  (								# Wrap whole match in $1
			(
			  ^[ \t]*>[ \t]?			# '>' at the start of a line
			    .+\n					# rest of the first line
			  (.+\n)*					# subsequent consecutive lines
			  \n*						# blanks
			)+
		  )
		}{
			my $bq = $1;
			$bq =~ s/^[ \t]*>[ \t]?//gm;	# trim one level of quoting
			$bq = $class->_RunBlockGamut($bq);		# recurse
			$bq =~ s/^/\t/g;
			
			"<blockquote>\n$bq\n</blockquote>\n\n";
		}egmx;


	return $text;
}


sub _FormParagraphs {
	#
	#	Params:
	#		$text - string to process with html <p> tags
	#

	my $class = shift;
	my $text = shift;

	# Strip leading and trailing lines:
	$text =~ s/\A\n+//;
	$text =~ s/\n+\z//;

	my @grafs = split(/\n{2,}/, $text);
	my $count = scalar @grafs;

	#
	# Wrap <p> tags.
	#
	foreach (@grafs) {
		unless (defined( $class->{g}{html_blocks}{$_} )) {
			$_ = $class->_RunSpanGamut($_);
			s/^([ \t]*)/<p>/;
			$_ .= "</p>";
		}
	}

	#
	# Unhashify HTML blocks
	#
	foreach (@grafs) {
		if (defined( $class->{g}{html_blocks}{$_} )) {
			$_ = $class->{g}{html_blocks}{$_};
		}
	}

	return join "\n\n", @grafs;
}


sub _EscapeSpecialChars {
	my $class = shift;
	my $text = shift;
	my $tokens ||= $class->_TokenizeHTML($text);

	$text = '';   # rebuild $text from the tokens
	my $in_pre = 0;	 # Keep track of when we're inside <pre> or <code> tags.
	my $tags_to_skip = qr!<(/?)(?:pre|code|kbd|script)[\s>]!;

	foreach my $cur_token (@$tokens) {
		if ($cur_token->[0] eq "tag") {
			# Within tags, encode * and _ so they don't conflict
			# with their use in Markdown for italics and strong.
			# We're replacing each such character with its
			# corresponding MD5 checksum value; this is likely
			# overkill, but it should prevent us from colliding
			# with the escape values by accident.
			$cur_token->[1] =~  s! \* !${ $class->{g}{escape_table} }{'*'}!gx;
			$cur_token->[1] =~  s! _  !${ $class->{g}{escape_table} }{'_'}!gx;
			$text .= $cur_token->[1];
		} else {
			my $t = $cur_token->[1];
			if (! $in_pre) {
				$t = $class->_EncodeBackslashEscapes($t);
				# $t =~ s{([a-z])/([a-z])}{$1&thinsp;/&thinsp;$2}ig;
			}
			$text .= $t;
		}
	}
	return $text;
}


sub _EncodeAmpsAndAngles {
	# Smart processing for ampersands and angle brackets that need to be 
	# encoded.

	my $class = shift;
	my $text = shift;

	# Ampersand-encoding based entirely on Nat Irons's Amputator MT plugin:
	#   http://bumppo.net/projects/amputator/
 	$text =~ s/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w{1,8});)/&amp;/g;

	# Encode naked <'s
 	$text =~ s{<(?![a-z/?\$!])}{&lt;}gi;

	return $text;
}


sub _EncodeCode {
	#
	# Encode/escape certain characters inside Markdown code runs.
	# The point is that in code, these characters are literals,
	# and lose their special Markdown meanings.
	#
	my $class = shift;
    local $_ = shift;

	# Encode all ampersands; HTML entities are not
	# entities within a Markdown code span.
	s/&/&amp;/g;

	# Do the angle bracket song and dance:
	s! <  !&lt;!gx;
	s! >  !&gt;!gx;

	# Now, escape characters that are magic in Markdown:
	s! \* !${ $class->{g}{escape_table} }{'*'}!gx;
	s! _  !${ $class->{g}{escape_table} }{'_'}!gx;
	s! {  !${ $class->{g}{escape_table} }{'{'}!gx;
	s! }  !${ $class->{g}{escape_table} }{'}'}!gx;
	s! \[ !${ $class->{g}{escape_table} }{'['}!gx;
	s! \] !${ $class->{g}{escape_table} }{']'}!gx;

	return $_;
}


sub _EncodeBackslashEscapes {
	#
	#   Parameter:  String.
	#   Returns:    The string, with after processing the following backslash
	#               escape sequences.
	#
	my $class = shift;
    local $_ = shift;

    s! \\\\  !${ $class->{g}{escape_table} }{'\\'}!gx;		# Must process escaped backslashes first.
    s! \\`   !${ $class->{g}{escape_table} }{'`'}!gx;
    s! \\\*  !${ $class->{g}{escape_table} }{'*'}!gx;
    s! \\_   !${ $class->{g}{escape_table} }{'_'}!gx;
    s! \\\{  !${ $class->{g}{escape_table} }{'{'}!gx;
    s! \\\}  !${ $class->{g}{escape_table} }{'}'}!gx;
    s! \\\[  !${ $class->{g}{escape_table} }{'['}!gx;
    s! \\\]  !${ $class->{g}{escape_table} }{']'}!gx;
    s! \\\(  !${ $class->{g}{escape_table} }{'('}!gx;
    s! \\\)  !${ $class->{g}{escape_table} }{')'}!gx;
    s! \\\#  !${ $class->{g}{escape_table} }{'#'}!gx;
    s! \\\.  !${ $class->{g}{escape_table} }{'.'}!gx;
    s{ \\!  }{${ $class->{g}{escape_table} }{'!'}}gx;

    return $_;
}


sub _UnescapeSpecialChars {
	#
	# Swap back in all the special characters we've hidden.
	#

	my $class = shift;
	my $text = shift;

	while( my($char, $hash) = each(%{ $class->{g}{escape_table} }) ) {
		$text =~ s/$hash/$char/g;
	}
    return $text;
}


sub _TokenizeHTML {
	#
	#   Parameter:  String containing HTML markup.
	#   Returns:    Reference to an array of the tokens comprising the input
	#               string. Each token is either a tag (possibly with nested,
	#               tags contained therein, such as <a href="<MTFoo>">, or a
	#               run of text between tags. Each element of the array is a
	#               two-element array; the first is either 'tag' or 'text';
	#               the second is the actual value.
	#
	#
	#   Derived from the _tokenize() subroutine from Brad Choate's MTRegex 
	#   plugin.
	#       <http://www.bradchoate.com/past/mtregex.php>
	#

	my $class = shift;
    my $str = shift;
    my $pos = 0;
    my $len = length $str;
    my @tokens;

    my $depth = 6;
    my $nested_tags = join('|', ('(?:<[a-z/!$](?:[^<>]') x $depth) . (')*>)' x  $depth);
    my $match = qr/(?s: <! ( -- .*? -- \s* )+ > ) |  # comment
                   (?s: <\? .*? \?> ) |              # processing instruction
                   $nested_tags/ix;                   # nested tags

    while ($str =~ m/($match)/g) {
        my $whole_tag = $1;
        my $sec_start = pos $str;
        my $tag_start = $sec_start - length $whole_tag;
        if ($pos < $tag_start) {
            push @tokens, ['text', substr($str, $pos, $tag_start - $pos)];
        }
        push @tokens, ['tag', $whole_tag];
        $pos = pos $str;
    }
    push @tokens, ['text', substr($str, $pos, $len - $pos)] if $pos < $len;
    \@tokens;
}


sub _Outdent {
	#
	# Remove one level of line-leading tabs or spaces
	#

	my $class = shift;
	my $text = shift;
	
	$text =~ s/^(\t|[ ]{1,$class->{g}{tab_width}})//gm;
	return $text;
}


sub _Detab {
	#
	# Cribbed from a post by Bart Lateur:
	# <http://www.nntp.perl.org/group/perl.macperl.anyperl/154>
	#

	my $class = shift;
	my $text = shift;
	
	$text =~ s/(.*?)\t/$1.(' ' x ($class->{g}{tab_width} - length($1) % $class->{g}{tab_width}))/ge;
	return $text;
}

#----------

#----------

1;
