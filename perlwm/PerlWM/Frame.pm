#
# $Id$
# 

package PerlWM::Frame;

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

  my %geom = $self->{client}->GetGeometry();

  $self->{extra_event_mask} = $self->{x}->pack_event_mask('SubstructureRedirect', 
							  'SubstructureNotify',
							  'StructureNotify');

  $self->create(x => $geom{x} - 2,
		y => $geom{y} - 20,
		width => $geom{width} + 4,
		height => $geom{height} + 4 + 20,
		background_pixel => $self->{x}->{white_pixel});


  $self->{label} = PerlWM::Widget::Label->new(x => $self->{x},
					      padding => 2,
					      value => $self->{client}->{prop}->{WM_NAME});
  $self->{label}->create(parent => $self,
			 x => 2, y => 2,
			 width => $geom{width}, height => 18);
  $self->{label}->MapWindow();

  $self->{client}->ConfigureWindow(border_width => 0);
  $self->{client}->ReparentWindow($self->{id}, 2, 2 + 20);
  $self->{client}->{frame} = $self;

  $self->MapWindow();

  return $self;
}

############################################################################

sub configure {

  my($self, %client) = @_;

  my %arg;

  if (my $size = $client{size}) {
    $arg{size} = [$size->[0] + 4, $size->[1] + 4 + 20];
  }
  if (my $position = $client{position}) {
    $arg{position} = [$position->[0] - 2, $position->[1] - 20];
  }

  if (my $size = delete $arg{size}) {
    $arg{width} = $size->[0];
    $arg{height} = $size->[1];
  }
  if (my $position = delete $arg{position}) {
    $arg{x} = $position->[0];
    $arg{y} = $position->[1];
  }
  
  $arg{stack_mode} = $client{stack_mode} if $client{stack_mode};

  if (%arg) {
    $self->ConfigureWindow(%arg);
    if ($arg{width}) {
      $self->{label}->ConfigureWindow(width => $arg{width} - 4);
    }
  }
}

############################################################################

1;
