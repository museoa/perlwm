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

  my $name = ($self->{frame}->{client}->{prop}->{WM_ICON_NAME} ||
	      $self->{frame}->{client}->{prop}->{WM_NAME});

  my %geom = $self->{frame}->GetGeometry();

  $self->create(x => $geom{x},
		y => $geom{y},
		width => 4 + 50,
		height => 4 + 18,
		background_pixel => $self->{x}->{white_pixel});

  $self->{label} = PerlWM::Widget::Label->new(x => $self->{x},
					      padding => 2,
					      resize => 'auto',
					      value => $name);

  $self->{label}->create(parent => $self,
			 x => 2, y => 2,
			 width => 'auto', height => 'auto');
  $self->{label}->MapWindow();

  $self->{frame}->{client}->event_overlay_add($self);

  %geom = $self->{label}->GetGeometry();
  $self->ConfigureWindow(width => $geom{width} + 4, 
			 height => $geom{height} + 4);

  return $self;
}

############################################################################

sub name {

  my($self, $name) = @_;
  $self->{label}->{value} = $name;
  $self->{label}->resize();
  my %geom = $self->{label}->GetGeometry();
  $self->ConfigureWindow(width => $geom{width} + 4, 
			 height => $geom{height} + 4);
}

############################################################################

sub prop_wm_icon_name {

  my($self, $event) = @_;
  $self->name($self->{frame}->{client}->{prop}->{WM_ICON_NAME});
}

############################################################################

sub EVENT { ('Drag(Button1)' => action('move_icon_opaque'),
	     'Drag(Mod1 Button1)' => action('move_icon_opaque'),
	     'Click(Button1)', action('deiconify_window'),
	     'Click(Double Button1)', action('deiconify_window') ) }

sub OVERLAY { ( 'Property(WM_ICON_NAME)' => \&prop_wm_icon_name ) }

############################################################################

1;
