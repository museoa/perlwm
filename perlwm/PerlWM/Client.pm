#
# $Id$
# 

package PerlWM::Client;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::X::Window);

use PerlWM::Frame;

############################################################################

sub new {

  my($proto, %arg) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%arg);

  $self->{frame} = PerlWM::Frame->new(x => $self->{x}, client => $self);

  $self->MapWindow() if $arg{map_request};

  return $self;
}

############################################################################

1;
