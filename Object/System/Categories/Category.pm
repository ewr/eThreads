package eThreads::Object::System::Categories::Category;

use Spiffy -Base;
no warnings;

use Scalar::Util;

use eThreads::Object::System::Categories::Category::Posts;
use eThreads::Object::System::Categories::Category::Writable;

#----------

field '_' => -ro;

field 'id' => -ro;
field 'name' => -ro;

field 'data' => 
	-init=>q! 
		$self->load_data 
			or $self->cache_data
	!, -ro;

field 'glomule' => -ro;
field 'catobj' => -ro;

stub 'write';
stub 'write_data';
stub 'delete';
field 'writable'	=> 
	-init=>q!
		bless 
			{ %$self },
			'eThreads::Object::System::Categories::Category::Writable';
	!, -ro;

field 'posts'		=> 
	-init=>q!
		$self->_->new_object('System::Categories::Category::Posts',$self->id);
	!, -ro;

#----------

sub new {
	my $data = shift;

	$self = bless ( {
		_		=> $data,
		name	=> undef,
		id		=> undef,
		glomule	=> undef,
		catobj	=> undef,
		@_,
	} , $self ); 

	if (!$self->{catobj}) {
		$self->_->bail->('Category init requires glomule.');
	}

	Scalar::Util::weaken( $self->{catobj} );

	$self->{glomule} = $self->catobj->glomule->id
		or $self->_->bail->('Unable to find glomule id.');

	return $self;
}

#----------

sub registerable {
	return {
		id		=> $self->{id},
		name	=> $self->{name},
		%{$self->{data}}
	};
}

#----------

sub sql {

}

#----------

sub load_data {
	$self->_->cache->get(
		tbl		=> "cat_data",
		first	=> $self->glomule,
		second	=> $self->id
	);
}

#----------

sub cache_data {
	my $get = $self->_->core->get_dbh->prepare("
		select
			ident,
			value
		from 
			" . $self->_->core->tbl_name('cat_data') . " 
		where 
			id = ?
	");

	$get->execute( $self->id ) 
		or $self->_->bail->('category cache_data failure: ' . $get->errstr);

	my ($ident,$value);
	$get->bind_columns( \($ident,$value) );

	my $data = {};
	while ( $get->fetch ) {
		$data->{ $ident } = $value;
	}

	$self->_->cache->set(
		tbl		=> 'cat_data',
		first	=> $self->glomule,
		second	=> $self->id,
		ref		=> $data,
	);

	$data;
}

#----------

=head1 NAME

eThreads::Object::System::Categories::Category

=head1 SYNOPSIS

=head1 DESCRIPTION


=over 4


=back

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
