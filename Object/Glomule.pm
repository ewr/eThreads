package eThreads::Object::Glomule;

use Spiffy -Base;

use eThreads::Object::Glomule::Data;
use eThreads::Object::Glomule::Data::Posts;

use eThreads::Object::Glomule::Function;
use eThreads::Object::Glomule::Pref;

use eThreads::Object::Glomule::Type;

use eThreads::Object::Glomule::Type::Admin;
use eThreads::Object::Glomule::Type::Blog;
use eThreads::Object::Glomule::Type::Comments;
use eThreads::Object::Glomule::Type::NCManagement;

#----------

field '_' => -ro;

field 'headers'	=> 
	-ro,
	-init=>q!
		$self->_->cache->get(tbl=>'glomule_headers') 
			or $self->cache_headers()
	!;

#----------

sub new {
	my $data = shift;

	$self = bless ( {
		_		=> $data,
	} , $self ); 

	return $self;
}

#----------

sub load {
	my %a = @_;
	
	# -- make sure type is valid -- #

	my $controller = $self->{_}->controller->get( $a{type} )
		or $self->{_}->bail->("Invalid glomule type: $a{type}");

	my $g = $self->{_}->new_object(
		"Glomule::Data",
		name		=> $a{name},
		type		=> $a{type},
		controller	=> $controller,
	)->activate;

	return $g;
}

#----------

sub typeobj {
	my $type = shift;

	if (my $obj = $self->{_}->cache->objects->get('glomuletype',$type)) {
		return $obj;
	} else {
		my $c = $self->{_}->controller->get($type)
			or return undef;
	
		my $obj = $self->{_}->new_object(
			"Glomule::Type::" . $c->object
		);

		$self->{_}->cache->objects->set('glomuletype',$type,$obj);

		return $obj;
	}
	
}

#----------

sub name2id {
	my $name = shift;
	my $container = shift || $self->{_}->container->id;

	my $gh = $self->headers;

	if (
		my $r = 
			$gh
				->{name}
				->{ $container }
				->{ $name }
	) {
		return wantarray ? ($r->{id},$r) : $r->{id};
	} else {
		return undef;
	}
}

#----------

sub cache_headers {
	my $db = $self->{_}->core->get_dbh;

	my $get_h = $db->prepare("
		select 
			id,
			name,
			container,
			natural_type
		from
			" . $self->{_}->core->tbl_name("glomule_headers") . "
	");

	$get_h->execute() 
		or $self->{_}->bail->(
			"glomule cache_headers failure: ".$db->errstr
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

	$self->{_}->cache->set(
		tbl		=> "glomule_headers",
		ref		=> $gh,
	);

	return $gh;
}

#----------

sub cache_data {
	my $id = shift;

	my $data = $self->{_}->utils->g_load_tbl(
		tbl		=> $self->{_}->core->tbl_name("glomule_data"),
		ident	=> "id",
		ids		=> [$id],
		flat	=> 1,
	);

	$self->{_}->cache->set(
		tbl		=> "glomule_data",
		first	=> $id,
		ref		=> $data,
	);

	return $data;
}

#----------

1;
