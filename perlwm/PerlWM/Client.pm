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

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%args);

  $self->{frame} = PerlWM::Frame->new(x => $self->{x}, client => $self);

  return $self;
}

############################################################################

1;
