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

1;
