#
# $Id$
# 

package PerlWM::Client;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::X::Window);

############################################################################

sub new {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%args);

  foreach my $atom ($self->ListProperties()) {
    $self->{prop}->{$self->{x}->atom_name($atom)} = 
      $self->get_unpack_property($atom);
  }

  # TODO: need to attach the events with a grab?
  # perhaps we can work this out - because the resource id of
  # the window won't be one of ours

  return $self;
}

############################################################################

1;
