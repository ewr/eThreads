package eThreads::Object::Glomule;

use strict;
use vars qw();

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

sub new {
	my $class = shift;
	my $data = shift;

	$class = bless ( {
		_		=> $data,
	} , $class ); 

	return $class;
}

#----------

sub load {
	my $class = shift;
	my %a = @_;
	
	# -- make sure type is valid -- #

	my $controller = $class->{_}->controller->get( $a{type} )
		or $class->{_}->bail->("Invalid glomule type: $a{type}");

	my $g = $class->{_}->new_object(
		"Glomule::Data",
		name		=> $a{name},
		type		=> $a{type},
		controller	=> $controller,
	)->activate;

	return $g;
}

#----------

sub typeobj {
	my $class = shift;
	my $type = shift;

	if (my $obj = $class->{_}->cache->objects->get('glomuletype',$type)) {
		return $obj;
	} else {
		my $c = $class->{_}->controller->get($type)
			or return undef;
	
		my $obj = $class->{_}->new_object(
			"Glomule::Type::" . $c->object
		);

		$class->{_}->cache->objects->set('glomuletype',$type,$obj);

		return $obj;
	}
	
}

#----------

sub name2id {
	my $class = shift;
	my $name = shift;
	my $container = shift || $class->{_}->container->id;

	my $gh = $class->load_headers;

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

sub load_headers {
	my $class = shift;

	my $gh = $class->{_}->cache->get(
		tbl		=> "glomule_headers",
	);

	if (!$gh) {
		$gh = $class->cache_headers();
	}

	return $gh;
}

#----------

sub cache_headers {
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

	$class->{_}->cache->set(
		tbl		=> "glomule_headers",
		ref		=> $gh,
	);

	return $gh;
}

#----------

sub cache_data {
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

1;
