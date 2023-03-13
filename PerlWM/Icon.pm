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

BEGIN {
  my $config = PerlWM::Config->new('default/icon');
  $config->set('background' => '#000000',
	       'foreground' => '#ffffff',
	       'border_color' => '#ffffff',
	       'hover_border' => '#ff0000',
	       'border_width' => 2,
	       'font' => '-b&h-lucida-medium-r-normal-*-*-100-*-*-p-*-iso8859-1');
};

############################################################################

sub new {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%args);

  my $name = ($self->{frame}->{client}->{prop}->{WM_ICON_NAME} ||
	      $self->{frame}->{client}->{prop}->{WM_NAME});

  $self->{border_width} = PerlWM::Config->get('icon/border_width');

  my($x, $y);
  # where should we put this icon?
  if (my $previous = $self->{frame}->{client}->{prop}->{PERLWM_ICON_POSITION}) {
    # put it where it was (if it has been placed before)
    ($x, $y) = @{$previous};
  }
  elsif (my $last = $self->{frame}->{perlwm}->{prop}->{PERLWM_ICON_POSITION}) {
    # where did the last icon go?
    ($x, $y) = @{$last};
  }
  else {
    # put it in the corner
    ($x, $y) = (2, 2);
  }	

  $self->create(x => $x, 
		y => $y,
		width => ($self->{border_width} * 2) + 50,
		height => ($self->{border_width} * 2) + 18,
		background_pixel => $self->{x}->color_get('icon/border_color'));

  $self->{label} = PerlWM::Widget::Label->new
    (x => $self->{x},
     padding => 2,
     resize => 'auto',
     foreground => 'icon/foreground',
     background => 'icon/background',
     font => 'icon/font',
     value => $name);

  $self->{label}->create(parent => $self,
			 x => $self->{border_width}, 
			 y => $self->{border_width},
			 width => 'auto', 
			 height => 'auto');
  $self->{label}->MapWindow();

  $self->{frame}->{client}->event_overlay_add($self);

  my %geom = $self->{label}->GetGeometry();
  $self->ConfigureWindow(width => $geom{width} + ($self->{border_width} * 2), 
			 height => $geom{height} + ($self->{border_width} * 2));

  $self->remember_icon_position();

  return $self;
}

############################################################################

sub name {

  my($self, $name) = @_;
  $self->{label}->{value} = $name;
  $self->{label}->resize();
  my %geom = $self->{label}->GetGeometry();
  $self->ConfigureWindow(width => $geom{width} + ($self->{border_width} * 2), 
			 height => $geom{height} + ($self->{border_width} * 2));
}

############################################################################

sub remember_icon_position {

  my($self) = @_;
  my %geom = $self->GetGeometry();
  $self->{frame}->{client}->{prop}->{PERLWM_ICON_POSITION} = [$geom{x}, $geom{y}];
  my($next_x, $next_y) = ($geom{x} + $geom{width} + 1, $geom{y});
  if ($next_x + ($geom{width} + 10) > $self->{x}->{width_in_pixels}) {
    $next_x = 2;
    $next_y += 18;
  }
  $self->{frame}->{perlwm}->{prop}->{PERLWM_ICON_POSITION} = [$next_x, $next_y];
}

############################################################################

sub prop_wm_icon_name {

  my($self, $event) = @_;
  $self->name($self->{frame}->{client}->{prop}->{WM_ICON_NAME});
}

############################################################################

sub enter {

  my($self, $event) = @_;
  if ($event) {
    return if $event->{detail} eq 'Inferior';
    return if $event->{mode} eq 'Grab';
  }
  $self->ChangeWindowAttributes(background_pixel => 
				$self->{x}->color_get('icon/hover_border'));
  $self->ClearArea();
}

############################################################################

sub leave {

  my($self, $event) = @_;
  if ($event) {
    return if $event->{detail} && ($event->{detail} eq 'Inferior');
    return unless $event->{mode} eq 'Normal';
  }
  $self->ChangeWindowAttributes(background_pixel => 
				$self->{x}->color_get('icon/border_color'));
  $self->ClearArea();
}

############################################################################

sub EVENT { ('Drag(Button1)' => action('move_icon_opaque'),
	     'Drag(Mod1 Button1)' => action('move_icon_opaque'),
	     'Click(Button1)', action('deiconify_window'),
	     'Click(Double Button1)', action('deiconify_window'),
	     'Enter' => \&enter,
	     'Leave' => \&leave) }

sub OVERLAY { ( 'Property(WM_ICON_NAME)' => \&prop_wm_icon_name ) }

############################################################################

1;
