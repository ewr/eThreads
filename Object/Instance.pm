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

	$swb->register('core',$core);
	$swb->register('settings',$core->settings);

	# register ourself with switchboard
	$swb->register('instance',$class);
	$swb->register('ap_request',$class->{ap_request});

	# register objects with switchboard
	$swb->register('objects',$class->{objects});

	# load up the utils object
	$swb->register('utils',sub {
		$class->new_object('Utils');
	});

	# create cache object
	$class->{cache} 	= $class->new_object(
		$class->{_}->settings->{cache_obj}
	);
	$swb->register('cache',$class->{cache});

	$swb->register('messages',sub {
		$class->new_object('Messages');
	});

	# register our bail object
	$swb->register('bail',sub {
		sub { $class->{_}->messages->bail(@_); }
	});

	# -- register some accessors lazily -- #

	$swb->register('RequestURI', $class->new_object('RequestURI') );

	$swb->register('auth',sub {
		$class->new_object($class->{_}->settings->{auth_obj});
	});

	$swb->register('raw_queryopts',sub {
		$class->new_object('QueryOpts::Raw');
	});

	$swb->register('queryopts',sub {
		$class->new_object('QueryOpts');
	});

	$swb->register("gholders", $class->new_object("GHolders") );

	$swb->register("last_modified",sub {
		$class->new_object("LastModifiedTime");
	});

	$swb->register("plugins",sub {
		$class->new_object("Plugin");
	});

	# -- continue with initialization -- #

	# set our root...  this will set $class->{root} to be a Container 
	# object for the root
	$class->{domain} = $class->determine_domain();
	$swb->register("domain",$class->{domain});

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

	return $class->{_}->mode->go;
}

#----------

sub DESTROY {
	my $class = shift;

	$class->{objects}->DESTROY;
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

sub check_rights_for_glomule {
	my $class = shift;
	my $glomule = shift;

	if (1) {
		return 1;
	} else {
		$class->{_}->bail->(
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

#----------

sub load_domains {
	my $class = shift;

	my $d = $class->{_}->cache->get(tbl=>"domains");

	if (!$d) {
		$d = $class->cache_domains();
	}

	return $d;
}

#----------

sub load_containers {
	my $class = shift;
	my $id = shift || $class->{_}->domain->id;

	my $c = $class->{_}->cache->get(
		tbl		=> "containers",
		first	=> $id,
	);

	if (!$c) {
		$c = $class->{_}->instance->cache_containers($id);
	}

	return $c;
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

sub determine_domain {
	my $class = shift;

	my $db = $class->{_}->core->get_dbh;

	if (!$class->{_}->settings->{virtual_root}) {
		my $root = $class->new_object("Domain",
			%{$class->{_}->core->get_default_domain}
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

	my $d = $class->load_domains;

	my $croot;
	if ( my $dref = $d->{d}{ $domain } ) {
		$croot = $class->new_object("Domain",%$dref);
	} else {
		$croot = $class->new_object("Domain",
			%{$class->{_}->core->get_default_domain}
		);
	}

	return $croot;
}

#------------------#
# caching routines #
#------------------#

sub cache_user_headers {
	my $class = shift;

	my $db = $class->{_}->core->get_dbh;
	my $get = $db->prepare("
		select 
			id,user,password 
		from 
			" . $class->{_}->core->tbl_name("user_headers") . " 
	");

	$get->execute();

	my ($id,$u,$p);
	$get->bind_columns( \($id,$u,$p) );

	my $headers = { u => {} , id => {} };
	while ($get->fetch) {
		my $user = {
			id			=> $id,
			username	=> $u,
			password	=> $p,
		};

		$headers->{u}{ $u } = $headers->{id}{ $id } = $user;
	}

	$class->{_}->cache->set(
		tbl		=> "user_headers",
		ref		=> $headers,
	);

	return $headers;
}

#----------

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

	$class->{_}->bail->("cache_looks failure: ".$db->errstr) 
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
		$l->{$c}{id}{$id} = $ref;
		$l->{$c}{name}{$n} = $ref;
		$l->{$c}{DEFAULT} = $ref if ($d);
	}

	$class->{_}->cache->set(
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
		or $class->{_}->bail->(
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

	$class->{_}->cache->set(
		tbl		=> "glomule_headers",
		ref		=> $gh,
	);

	return $gh;
}

#----------

sub cache_glomule_data {
	my $class = shift;
	my $id = shift;

	my $data = $class->{_}->utils->g_load_tbl(
		tbl		=> $class->{_}->core->tbl_name("glomule_data"),
		ident	=> "id",
		ids		=> [$id],
		flat	=> 1,
	);

	$class->{_}->cache->set(
		tbl		=> "glomule_data",
		first	=> $id,
		ref		=> $data,
	);

	return $data;
}

#----------

sub cache_domains {
	my $class = shift;

	my $get = $class->{_}->core->get_dbh->prepare("
		select 
			id,
			domain,
			path
		from 
			" . $class->{_}->core->tbl_name("domains") . "
		
	");

	$get->execute 
		or $class->{_}->bail->("cache_domains error: ".$get->errstr);

	my ($id,$d,$p);
	$get->bind_columns( \($id,$d,$p) );

	my $domains = { id => {} , d => {} };
	while ($get->fetch) {
		my $h = {
			id		=> $id,
			domain	=> $d,
			path	=> $p,
		};

		$domains->{id}{$id} = $domains->{d}{$d} = $h;
	}

	# now get aliases

	{
		my $get_a = $class->{_}->core->get_dbh->prepare("
			select 
				domain,
				alias
			from 
				" . $class->{_}->core->tbl_name("domain_aliases") . "
	
		");

		$get_a->execute() 
			or $class->{_}->bail->("get domain aliases failure: ".$get_a->errstr);
		
		my ($d,$a);
		$get_a->bind_columns( \($d,$a) );

		while ($get_a->fetch) {
			next if ($domains->{d}{ $a });
			$domains->{d}{ $a } = $domains->{id}{ $d };
		}

	}

	$class->{_}->cache->set(
		tbl		=> "domains",
		ref		=> $domains,
	);

	return $domains;
}

#----------

sub cache_containers {
	my $class = shift;
	my $domain = shift;

	my $db = $class->{_}->core->get_dbh;

	my $get_glomules = $db->prepare("
		select 
			id,name 
		from 
			" . $class->{_}->core->tbl_name("containers") . " 
		where 
			domain = ?
	");

	$class->{_}->bail("cache_glomule_hash error: ".$db->errstr) 
		unless ($get_glomules->execute( $domain ));

	my ($id,$name);
	$get_glomules->bind_columns(\$id,\$name);

	my $g = {};
	while ($get_glomules->fetch) {
		$g->{$name} = $id;
	}

	$class->{_}->cache->set(
		tbl		=> "containers",
		first	=> $domain,
		ref		=> $g,
	);

	return $g;
}

#----------

=head1 NAME

eThreads::Object::Instance

=head1 SYNOPSIS

	my $inst = $core->new_object("Instance",$r);

	my $obj = $inst->new_object("ObjType",$objdata);

	my $status = $inst->go();

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
	* A Switchboard object
	* determine_root() to get a Container object for the root
	* determine_mode() to get a Mode object

The following Switchboard items are registered:

	* core
	* settings
	* instance
	* ap_request
	* objects
	* utils (lazy)
	* cache (lazy)
	* messages (lazy)
	* bail (lazy)
	* RequestURI 
	* auth (lazy)
	* gholders
	* last_modified (lazy)
	* root
	* mode

new should always be called through $core->new_object so that it has a 
reference back to $core.

=item new_object 

	my $obj = $inst->new_object("ObjType",$objdata);

Returns a new object of type ObjType (which is prefixed with 
eThreads::Object).  The object is passed the Instance object as its first 
argument in order to allow it to connect to other objects.  Any objdata given 
in the new_object call is appended after that.

=item go

	my $status = $inst->go();

Calls the mode's go() routine.  Returns an Apache status code.

=item check_rights_for_glomule

	if ($inst->check_rights_for_glomule($id)) {
		# we're cool in this container
	}

Intended to check and make sure container has proper rights for glomule.  
Currently just returns true.

=item load_containers

Returns a reference to the containers table.

=item determine_root

Used internally to determine the root container.  This is where domain 
rooting support lives.

=item determine_mode

Used internally.  Parses RequestURI to see if it recognizes a mode.  Inits 
mode object and returns it.  Returns a Mode::Normal object if no mode 
recognized.

=back

=head1 Cache Routines

=over 4

=item cache_user_headers 

Caches user_headers table and returns a hash containing {u}{ (username) } 
and {id}{ (user id) } for all users.

=item cache_looks

	my $looks = $inst->cache_looks;

Caches and returns a hash containing the contents of the looks table.  Hash 
contents are { (container) }{ (look id) } and { (container) }{DEFAULT}.

=item cache_glomule_headers

	my $h = $inst->cache_glomule_headers;

Caches and returns a hash containing the contents of the glomule_headers 
table. Contains lookups for id, container (c/id), and name (c/name).

=item cache_glomule_data 

	my $d = $inst->cache_glomule_data($id);

Caches and returns a hash containing the contents of the glomule_data 
table for the given glomule id. { (key) }

=item cache_containers

	my $c = $inst->cache_containers;

Caches and returns a hash containing the contents of the containers table. 
{ (path) } = (id).

=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.

=cut

1;
