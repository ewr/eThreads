package eThreads::Object::Instance;

use Spiffy -Base;
no warnings;

field '_' => -ro;

sub new {
	# this is going to be core's switchboard accessors
	my $data = shift;

	# request handler
	my $r = shift;

	# -- create our self object -- #

	$self = bless { _ => undef } , $self;

	# create instance objects object
	$self->{objects} = eThreads::Object::Objects->new($self);

	# create custom switchboard object
	my $swb = $data->switchboard->custom;
	$swb->reroute_calls_for($self);
	$self->{objects}->register($swb);

	# register ourself with switchboard
	$swb->register('instance',$self);
	$swb->register('ap_request',$r);

	# register objects with switchboard
	$swb->register('objects',$self->{objects});

	# load up the utils object
	$swb->register('utils',sub {
		$self->_->new_object('Utils');
	});

	# create cache object
	$swb->register('cache',$self->_->new_object(
		$self->_->settings->{cache_obj}
	));

	$swb->register('messages',sub {
		$self->_->new_object('Messages');
	});

	# register our bail object
	$swb->register('bail',sub {
		sub { $self->_->messages->bail(@_); }
	});

	# -- register some accessors lazily -- #

	$swb->register('RequestURI', $self->_->new_object('RequestURI') );

	$swb->register('auth',sub {
		$self->_->new_object($self->_->settings->{auth_obj});
	});

	$swb->register('raw_queryopts',sub {
		$self->_->new_object('QueryOpts::Raw');
	});

	$swb->register('queryopts',sub {
		$self->_->new_object('QueryOpts');
	});

	$swb->register("gholders", $self->_->new_object("GHolders") );

	$swb->register('glomule', $self->_->new_object('Glomule'));

	$swb->register("last_modified",sub {
		$self->_->new_object("LastModifiedTime");
	});

	$swb->register("plugins",sub {
		$self->_->new_object("Plugin");
	});

	# create system object
	$swb->register('system',sub {
		$self->_->new_object('System');
	});

	# create users object
	$swb->register('users',sub {
		$self->_->new_object('Users');
	});

	# -- continue with initialization -- #

	# set our root...  this will set $self->{root} to be a Container 
	# object for the root
	$swb->register("domain",$self->determine_domain());

	# what we do here is a sort of tree shaped lookup to see what 
	# all is going on.  We determine the mode, the mode determines the 
	# container, the container determines the look, and finally the 
	# look determines the template

	# figure out our mode
	$swb->register("mode",$self->determine_mode());

	# -- now return -- #

	return $self;
}

#----------

sub go {
	$self->_->mode->go;
}

#----------

sub DESTROY {
	$self->{objects}->DESTROY;
	undef $self->{objects};
}

#----------

sub new_object {
	my @caller = caller;
	$self->_->bail->("new_object called on instance: @caller");
}

#----------

sub check_rights_for_glomule {
	my $glomule = shift;

	if (1) {
		return 1;
	} else {
		$self->_->bail->(
			"Cannot instantiate this glomule here.  Insufficient rights."
		);
	}
}

#--------------#
# object calls #
#--------------#

sub ap_request {
	return $self->{ap_request};
}

#----------

sub load_domains {
	my $d = $self->_->cache->get(tbl=>"domains");

	if (!$d) {
		$d = $self->cache_domains();
	}

	return $d;
}

#----------

sub load_containers {
	my $id = shift || $self->_->domain->id;

	my $c = $self->_->cache->get(
		tbl		=> "containers",
		first	=> $id,
	);

	if (!$c) {
		$c = $self->_->instance->cache_containers($id);
	}

	return $c;
}

#--------------------#
# determine routines #
#--------------------#

sub determine_mode {
	my $u = $self->_->RequestURI->unclaimed;

	my $obj;
	while ( my ($m,$s) = each %{ $self->_->settings->{modes} }) {
		if ($u =~ m!^(/?$s)!) {
			$self->_->RequestURI->claim($1);
			$obj =  $self->_->new_object("Mode::$m",$s);
			last;
		} else {
			# do nothing
		}
	}

	# reset the counter for each
	keys %{ $self->_->settings->{modes} };

	if ($obj) {
		return $obj;
	} else {
		# if we've found nothing, our mode is Normal 
		return $self->_->new_object("Mode::Normal");
	}
}

#----------

sub determine_domain {
	my $db = $self->_->core->get_dbh;

	if (!$self->_->settings->{virtual_root}) {
		my $root = $self->_->new_object("Domain",
			%{$self->_->core->get_default_domain}
		);

		return $root;
	}

	# TODO: ok, so in 2.0 you could root off a domain/path combo, 
	# but I'm havign a lot of trouble figuring out how to work that in 
	# combination with the ability to have no script name and no path.  
	# so for now i'm just reducing domain roots to the domain.  That 
	# means one root per domain for now, but it's a change that would 
	# be confined here should someone want to add it in the future

	my $domain = $ENV{HTTP_X_FORWARDED_HOST} || $ENV{SERVER_NAME};

	my $d = $self->load_domains;

	my $croot;
	if ( my $dref = $d->{d}{ $domain } ) {
		$croot = $self->_->new_object("Domain",%$dref);
	} else {
		$croot = $self->_->new_object("Domain",
			%{$self->_->core->get_default_domain}
		);
	}

	return $croot;
}

#------------------#
# caching routines #
#------------------#

sub cache_domains {
	my $get = $self->_->core->get_dbh->prepare("
		select 
			id,
			domain,
			path
		from 
			" . $self->_->core->tbl_name("domains") . "
		
	");

	$get->execute 
		or $self->_->bail->("cache_domains error: ".$get->errstr);

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
		my $get_a = $self->_->core->get_dbh->prepare("
			select 
				domain,
				alias
			from 
				" . $self->_->core->tbl_name("domain_aliases") . "
	
		");

		$get_a->execute() 
			or $self->_->bail->("get domain aliases failure: ".$get_a->errstr);
		
		my ($d,$a);
		$get_a->bind_columns( \($d,$a) );

		while ($get_a->fetch) {
			next if ($domains->{d}{ $a });
			$domains->{d}{ $a } = $domains->{id}{ $d };
		}

	}

	$self->_->cache->set(
		tbl		=> "domains",
		ref		=> $domains,
	);

	return $domains;
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
