#
# $Id$
# 

package PerlWM::Icon;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::X::Window);

use PerlWM::Widget::Label;

############################################################################

sub new {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%args);

  my %geom;
  if ($self->{client}->{frame}) {
    %geom = $self->{client}->{frame}->GetGeometry();
  }
  else {
    %geom = $self->{client}->GetGeometry();
  }

  $self->create(x => $geom{x},
		y => $geom{y},
		width => 4 + 50,
		height => 4 + 18,
		background_pixel => $self->{x}->{white_pixel});

  $self->{label} = PerlWM::Widget::Label->new(x => $self->{x},
					      padding => 2,
					      value => $self->{client}->{prop}->{WM_NAME});
  $self->{label}->create(parent => $self,
			 x => 2, y => 2,
			 width => 50, height => 18);
  $self->{label}->MapWindow();

  $self->{client}->{icon} = $self;

  return $self;
}

############################################################################

1;
