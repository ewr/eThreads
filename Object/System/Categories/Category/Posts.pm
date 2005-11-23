package eThreads::Object::System::Categories::Category::Posts;

use Spiffy -Base;

field '_' => -ro;
field 'id' => -ro;

field 'posts' => 
	-init=>q!
		$self->load_posts
	!, -ro;

field 'hash' => 
	-init=>q!
		my %hash;
		%hash = map { $_ => 1 } @{ $self->posts };
		\%hash;
	!, -ro;

sub new {
	my $data = shift;
	my $id = shift;
	
	$self = bless { _ => $data , id => $id } , $self;

	if (!$self->{id}) {
		$self->_->bail->('Unable to load category posts without id.');
	}

	return $self;
}

#----------

sub load_posts {
	my $get = $self->_->core->get_dbh->prepare("
		select 
			post 
		from 
			" . $self->_->core->tbl_name('cat_bindings') . " 
		where 
			cat = ?
	");

	$get->execute( $self->id );

	my ($id);
	$get->bind_columns(\$id);

	my $posts = [];
	while ($get->fetch) {
		push @$posts, $id;
	}

	$posts;
}

#----------

sub add {
	my $id = shift;

	if ( $self->hash->{ $id } ) {
		return undef;
	}

	my $ins = $self->_->core->get_dbh->prepare("
		insert into " . $self->_->core->tbl_name('cat_bindings') . " 
			(cat,post)
		values(?,?)
	");

	$ins->execute($self->id,$id)
		or $self->_->bail->('Unable to add post to category: ' . $ins->errstr);

	# TODO: There's a more efficient way to do this
	undef $self->{posts};
	undef $self->{hash};
	
	return 1;
}

#----------

sub remove {
	my $id = shift;

	if ( !$self->hash->{ $id } ) {
		return undef;
	}

}
