package eThreads::Object::Functions::Glomule;

@ISA = qw( eThreads::Object::Functions );

use strict;

#----------

sub knows {
    my $class = shift;
    my $func = shift;
    
    if (my $ref = $class->SUPER::knows($func)) {
        if ( 
			$class->{_}->mode->IS_ADMIN 
			|| $ref->mode( $class->{_}->mode->mode ) 
		) {
            return $ref;
        } else {
            return undef;
        }
    } else {
        return undef;
    }   
}   

#----------

sub register {
    my $class = shift;

    foreach my $f (@_) {
        my $func = $class->{_}->instance->new_object(
            "Glomule::Function",
            $class->{_}->glomule,
            $f
        );
        $class->{f}{ $f->{name} } = $func;
    }

    return 1;
}

=head1 NAME

eThreads::Object::Functions::Glomule

=head1 SYNOPSIS

	# See eThreads::Object::Functions

=head1 DESCRIPTION

This object is a superset of the Functions object.  It provides the same 
external interface, but creates a Glomule::Function item for each function 
passed in.  knows() also checks to see that the function is not only defined, 
but valid in the current mode.

=head1 AUTHOR

Eric Richardson <e@ericrichardson.com>

=head1 COPYRIGHT

Copyright (c) 1999-2005 Eric Richardson.   All rights reserved.  eThreads 
is licensed under the terms of the GNU General Public License, which you 
should have received in your distribution.
	
=cut

1;
