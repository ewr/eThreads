package eThreads::Object::Utils;

use strict;

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

sub set_value {
	my $class = shift;
	my %args = @_;

	$args{value_field} = "value" if (!$args{value_field});
	$args{value} = '0' if (!$args{value} && $args{set_zero_val});

	# set up our conditions
	my @cargs;
	my @cond;

	my $db = $class->{_}->core->get_dbh;

	foreach my $key (keys %{$args{keys}}) {
		push @cond, "$key = ?";
		push @cargs, $args{keys}{$key};
	};

	my $cond = "where " . join(" and ",@cond);

	# select to determine if there is a current value set
	my $select = $db->prepare("
		select 1 from $args{tbl} $cond
	");

	$class->{_}->bail->(0,"set_value select failure: ".$db->errstr) unless (
		$select->execute(@cargs)
	);

	if ($select->rows && ($args{value} || $args{set_zero_val})) {
		# if an entry exists, and there was a value input or we're 
		# setting zero values, then update existing entry

		my $update = $db->prepare("
			update $args{tbl} set $args{value_field} = ? $cond
		");

		$class->{_}->bail->(0,"set_value update failure: ".$db->errstr) unless (
			$update->execute($args{value},@cargs)
		);
	} elsif ($select->rows) {
		# if there is an entry, there's no input value, and zero values are 
		# illegal, delete the entry

		my $delete = $db->prepare("
			delete from $args{tbl} $cond
		");
		$class->{_}->bail->(0,"set_value delete failure: ".$db->errstr) unless (
			$delete->execute(@cargs)
		);
	} elsif ($args{value} || $args{set_zero_val}) {
		# if there was no match, and there's an input value or we're allowing 
		# zero values, create a new entry

		my $keys = join(",",keys %{$args{keys}});

		my $create = $db->prepare("
			insert into $args{tbl}(
				$keys,$args{value_field}
			) values (" . "?,"x(@cargs) . "?)
		");
		$class->{_}->bail->(0,"set_value create failure: ".$db->errstr) unless (
			$create->execute(@cargs,$args{value})
		);
	} else {
		# do nothing
	}
}
#----------

sub g_load_tbl {
	my $class = shift;
	my %args = @_;

	my $tmp = {};

	my $db = $class->{_}->core->get_dbh;

	my $where;
	my @values;
	if ($args{get_all}) {
		# $where stays null
	} elsif ( @{ $args{ids} } == 0 ) {
		return undef;
	} elsif ( @{ $args{ids} } == 1 ) {
		$where = 
			"where $args{ident} = ?";
			push @values, $args{ids}->[0];
	} else {
		$where = 
			"where $args{ident} in (". 
			join( "," , map { "?" } @{ $args{ids} } ) . 
			")";
		push @values, @{ $args{ids} };
	}

	my $get_tbl = $db->prepare("
		select $args{ident},ident,value from $args{tbl} 
		$where
		$args{extra}
	");

	$class->{_}->bail->("g_load_tbl: ".$db->errstr) unless (
		$get_tbl->execute(@values)
	);

	my ($id,$ident,$value);
	$get_tbl->bind_columns(\$id,\$ident,\$value);
	
	if ($args{flat}) {
		while ($get_tbl->fetch) {
			$tmp->{$ident} = $value;
		}
	} else {
		while ($get_tbl->fetch) {
			$tmp->{$id}{$ident} = $value;
		}
	}

	return $tmp;
}

#----------

sub g_rec_populate {
	my ($class,$uh,$t) = @_;
	my $h = {};
 
	foreach my $id (@$t) {
		while ( my ($k,$v) = each %{ $uh->{ $id } }) {
			$h->{ $k } = $v if (!defined($h->{ $k }));
		}
	}   
        
	return $h;
}   

#----------

sub get_unused_tbl_name {
	my $class = shift;
	my $prefix = shift || "generic";

	my $check = $class->{_}->core->get_dbh->prepare("
		show tables like ?
	");

	my $tbl;
	do {
		$tbl = $prefix . "_" . $class->random(6);
		$check->execute($tbl);
	} until (!$check->rows); 

	return $tbl;
}

#----------

sub create_table {
	my $class = shift;
	my $name = shift;
	my $schema = shift;

	my $sql;
	my $keys;

	if (my $k = $schema->[0]{KEYS}) {
		$keys = $k;
	} 

	foreach my $f (@$schema) {
		next if ($f->{KEYS});
		$sql .= "$f->{name} $f->{def},\n";
	}
    
	if ($sql) {
		my $c = $class->{_}->core->get_dbh->prepare("
			create table $name (
				$sql " . join(',',@$keys) . "
			)
		");

		$class->{_}->bail->(
			"create table failure: ".$c->errstr
		) unless ($c->execute);
	}

	return $name;
}

#----------

sub random {
	my ($class,$x) = @_;
	my @a = (48..57,65..90,97..122);

	my @r;
	for (my $i=0;$i<=$x;$i++) {
		push @r, $a[rand(62)];
	}

	return pack("C$x",@r);
}

#----------

#----------

1;
