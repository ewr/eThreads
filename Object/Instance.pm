package eThreads::Object::Instance;

use strict;

sub new {
	my $class 	= shift;

	# this is going to be core
	my $core 	= shift;

	my $r = shift;

	$class = bless ( 
		{ 
			_			=> undef,
			container	=> undef,
			look		=> undef,
			template	=> undef,
			gholders	=> undef,
			input		=> undef,
			ap_request	=> $r,
			# etc...
		} , $class );

	# create objects object
	$class->{objects} = eThreads::Object::Objects->new($class);

	# create switchboard object
	my $swb = $class->{switchboard} = new eThreads::Object::Switchboard;
	$class->{_} = $class->{switchboard}->accessors;

	$swb->register("core",$core);
	$swb->register("settings",$core->settings);

	# register ourself with switchboard
	$swb->register("instance",$class);
	$swb->register("ap_request",$class->{ap_request});

	# register objects with switchboard
	$swb->register("objects",$class->{objects});

	# create cache object
	$class->{cache} 	= $class->new_object(
		$class->{_}->settings->{cache_obj}
	);
	$swb->register("cache",$class->{cache});

	# -- register some accessors lazily -- #

	$swb->register("RequestURI",sub {
		$class->new_object("RequestURI");
	});

	$swb->register("messages",sub {
		$class->new_object("Messages");
	});

	$swb->register("auth",sub {
		$class->new_object($class->{_}->settings->{auth_obj});
	});

	$swb->register("queryopts",sub {
		$class->new_object("QueryOpts");
	});

	$swb->register("gholders",sub {
		$class->new_object("GHolders");
	});

	# -- continue with initialization -- #

	# set our root...  this will set $class->{root} to be a Container 
	# object for the root
	$class->{root} = $class->determine_root();
	$swb->register("root",$class->{root});

	# what we do here is a sort of tree shaped lookup to see what 
	# all is going on.  We determine the mode, the mode determines the 
	# container, the container determines the look, and finally the 
	# look determines the template

	# figure out our mode
	$class->{mode}		= $class->determine_mode();
	$swb->register("mode",$class->{mode});

	# -- now return -- #

	return $class;
}

#----------

sub go {
	my $class = shift;

	$class->{_}->mode->go;
}

#----------

sub DESTROY {
	my $class = shift;

	$class->{_}->objects->DESTROY;
}

#----------

sub new_object {
	my $class = shift;
	my $type = shift;

	my $obj = $class->{_}->objects->create(
		$type,
		$class->{_},
		@_
	);

	return $obj;
}

#----------

sub _new_object_data {
	my $class = shift;

	return {
		%{$class->{_}},
		inst		=> $class,
		container	=> $class->{container},
		look		=> $class->{look},
		template	=> $class->{template},
		gholders	=> $class->{gholders},
		queryopts	=> $class->{queryopts}
	};
}

#----------

sub check_rights_for_glomule {
	my $class = shift;
	my $glomule = shift;

	if (1) {
		return 1;
	} else {
		$class->bail(
			"Cannot instantiate this glomule here.  Insufficient rights."
		);
	}
}

#--------------#
# object calls #
#--------------#

sub ap_request {
	return shift->{ap_request};
}

#--------------------#
# determine routines #
#--------------------#

sub determine_mode {
	my $class = shift;

	my $u = $class->{_}->RequestURI->unclaimed;

	my $obj;
	while ( my ($m,$s) = each %{ $class->{_}->settings->{modes} }) {
		if ($u =~ m!^(/?$s)!) {
			$class->{_}->RequestURI->claim($1);
			$obj =  $class->new_object("Mode::$m",$s);
			last;
		} else {
			# do nothing
		}
	}

	# reset the counter for each
	keys %{ $class->{_}->settings->{modes} };

	if ($obj) {
		return $obj;
	} else {
		# if we've found nothing, our mode is Normal 
		return $class->new_object("Mode::Normal");
	}
}

#----------

sub determine_root {
	my $class = shift;

	my $db = $class->{_}->core->get_dbh;

	if (!$class->{_}->settings->{virtual_root}) {
		my $root = $class->new_object("Container",
			id		=> $class->{_}->core->get_default_id,
			name	=> "",
			path	=> $class->{_}->settings->{d_path},
		);

		return $root;
	}

	# TODO: ok, so in 2.0 you could root off a domain/path combo, 
	# but I'm havign a lot of trouble figuring out how to work that in 
	# combination with the ability to have no script name and no path.  
	# so for now i'm just reducing domain roots to the domain.  That 
	# means one root per domain for now, but it's a change that would 
	# be confined here should someone want to add it in the future

	my $domain = $ENV{SERVER_NAME};

	my $get = $db->prepare("
		select 
			root,path 
		from 
			" . $class->{_}->tbl_name("domains") . "
		where 
			domain = ?
	");

	$get->execute($domain);

	my $croot;
	if ($get->rows) {
		# -- go ahead and root -- #

		my ($root,$path) = $get->fetchrow_array;

		$croot = $class->new_object("Container",
			id		=> $root,
			path	=> $path,
		);
	} else {
		# -- give default root -- #
		$croot = $class->new_object("Container",
			id		=> $class->{_}->get_default_id,
			name	=> "",
			path	=> $class->{_}->settings->{d_path},
		);
	}

	return $croot;
}

#------------------#
# caching routines #
#------------------#

sub cache_looks {
	my $class = shift;

	my $db = $class->{_}->core->get_dbh;

	my $get_looks = $db->prepare("
		select 
			id,
			name,
			container,
			is_default 
		from 
			" . $class->{_}->core->tbl_name("looks") . "
	");

	$class->bail("cache_looks failure: ".$db->errstr) 
		unless ($get_looks->execute);

	my ($id,$n,$c,$d);
	$get_looks->bind_columns( \($id,$n,$c,$d) );

	my $l = {};
	while ($get_looks->fetch) {
		my $ref = {
			name		=> $n,
			id			=> $id,
			container	=> $c,
		};
		$l->{$c}{$id} = $ref;
		$l->{$c}{DEFAULT} = $ref if ($d);
	}

	$class->{_}->cache->write_cache_file(
		tbl	=> "looks",
		ref	=> $l,
	);

	return $l;
}

#----------

sub cache_glomule_headers {
	my $class = shift;

	my $db = $class->{_}->core->get_dbh;

	my $get_h = $db->prepare("
		select 
			id,
			name,
			container,
			natural_type
		from
			" . $class->{_}->core->tbl_name("glomule_headers") . "
	");

	$get_h->execute() 
		or $class->{_}->core->bail(
			"cache_glomule_headers failure: ".$db->errstr
		);

	my ($id,$n,$c,$t);
	$get_h->bind_columns( \($id,$n,$c,$t) );

	my $gh = {};
	while ($get_h->fetch) {
		my $data = {
			id			=> $id,
			name		=> $n,
			container	=> $c,
			natural		=> $t,
		};

		$gh->{id}{ $id } = $data;
		$gh->{container}{ $c }{ $id } = $data;
		$gh->{name}{ $c }{ $n } = $data;
	}

	$class->{_}->cache->write_cache_file(
		tbl		=> "glomule_headers",
		ref		=> $gh,
	);

	return $gh;
}

#----------

sub cache_glomule_data {
	my $class = shift;
	my $id = shift;

	my $data = $class->{_}->core->g_load_tbl(
		tbl		=> $class->{_}->core->tbl_name("glomule_data"),
		ident	=> "id",
		ids		=> [$id],
		flat	=> 1,
	);

	$class->{_}->cache->write_cache_file(
		tbl		=> "glomule_data",
		first	=> $id,
		ref		=> $data,
	);

	return $data;
}

#----------

sub cache_containers {
	my $class = shift;

	my $db = $class->{_}->core->get_dbh;

	my $get_glomules = $db->prepare("
		select 
			id,name 
		from 
			" . $class->{_}->core->tbl_name("containers") . "
	");

	$class->{_}->bail("cache_glomule_hash error: ".$db->errstr) 
		unless ($get_glomules->execute);

	my ($id,$name);
	$get_glomules->bind_columns(\$id,\$name);

	my $g = {};
	while ($get_glomules->fetch) {
		$g->{$name} = $id;
	}

	$class->{_}->cache->write_cache_file(
		tbl	=> "containers",
		ref	=> $g,
	);

	return $g;
}

#----------

sub bail {
	my $class = shift;
	my $err = shift;

	$class->messages->print("Bail",$err);

	exit Apache::OK;	
}


#----------

=head1 NAME

eThreads::Object::Instance

=head1 SYNOPSIS

	my $inst = $core->new_object("Instance",$r);

	my $obj = $inst->new_object("ObjType",$objdata);

	$do->something
		or $inst->bail("Somethign Failed");

	# object calls
	$inst->auth;
	$inst->messages;
	$inst->core;
	$inst->RequestURI;
	$inst->ap_request;
	$inst->mode;
	$inst->objects;
	$inst->cache;
	$inst->gholders;
	$inst->queryopts;
	$inst->container;
	$inst->look;
	$inst->template;

	# determine routines
	my $mode = $inst->determine_mode;
	my $container = $inst->determine_container;
	my $look = $inst->determine_look;
	my $template = $inst->determine_template;

	# cache routines
	my $looks = $inst->cache_looks;
	my $gh = $inst->cache_glomule_headers;
	my $gd = $inst->cache_glomule_data;
	my $containers = $inst->cache_containers;

=head1 DESCRIPTION

=over 4

=item new

	my $inst = $core->new_object("Instance",$r);

Returns a new Instance object.  B<$r> must be the Apache request object.  On 
a call to new Instance loads 

	* Objects object
	* Cache object
	* determine_mode() to get a Mode object
	* determine_container() to get a Container object
	* determine_look() to get a Look object
	* determine_template() to get a Template object

new should always be called through $core->new_object so that it has a 
reference back to $core.

=item new_object 

	my $obj = $inst->new_object("ObjType",$objdata);

Returns a new object of type ObjType (which is prefixed with 
eThreads::Object).  The object is passed the Instance object as its first 
argument in order to allow it to connect to other objects.  Any objdata given 
in the new_object call is appended after that.

=back

=item bail 

	$inst->bail("my error message");

Prints a failure message including the given error message and then exits.

=head1 Object Calls

The object calls all return the objects stored in the Instance.  The available 
objects are:

	* auth
	* messages
	* core
	* RequestURI
	* ap_request (the ApacheReq $r passed into Instance)
	* mode
	* objects
	* cache
	* gholders
	* queryopts
	* container
	* look
	* template

=head1 Cache Routines

=over 4

=item cache_looks

	my $looks = $inst->cache_looks;

Caches and returns a hash containing the contents of the looks table.

=item cache_glomule_headers

	my $h = $inst->cache_glomule_headers;

Caches and returns a hash containing the contents of the glomule_headers 
table.

=item cache_glomule_data 

	my $d = $inst->cache_glomule_data($id);

Caches and returns a hash containing the contents of the glomule_data 
table for the given glomule id.

=item cache_containers

	my $c = $inst->cache_containers;

Caches and returns a hash containing the contents of the containers table.

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2004 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.

=cut

1;
