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

