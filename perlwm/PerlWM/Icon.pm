#
# $Id$
#

package PerlWM::Icon;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::X::Window);

use PerlWM::Action;
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
					      resize => 'auto',
					      value => $self->{client}->{prop}->{WM_NAME});
  $self->{label}->create(parent => $self,
			 x => 2, y => 2,
			 width => 'auto', height => 'auto');
  $self->{label}->MapWindow();

  %geom = $self->{label}->GetGeometry();
  $self->ConfigureWindow(width => $geom{width} + 4, height => $geom{height} + 4);

  $self->{client}->{icon} = $self;

  return $self;
}

############################################################################

sub EVENT {

  return ('Drag(Button1)' => action('move_icon_opaque'),
	  'Drag(Mod1 Button1)' => action('move_icon_opaque'),
	  'Click(Button1)', action('deiconify_window'),
	  'Click(Double Button1)', action('deiconify_window'));
}

############################################################################

1;
