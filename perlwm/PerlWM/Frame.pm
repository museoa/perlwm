#
# $Id$
#

package PerlWM::Frame;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::X::Window);

use PerlWM::Action;
use PerlWM::Widget::Label;

############################################################################

my($FOCUS, $BLUR) = ([255, 0, 0], [255, 255, 255]);
my($BLEND_STEP, $BLEND_DELAY, @BLEND) = (10, 10);

############################################################################

sub new {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%args);

  unless (@BLEND) {
    my @delta = map { ($FOCUS->[$_] - $BLUR->[$_]) / $BLEND_STEP } 0..2;
    my @color = @{$BLUR};
    foreach (0..$BLEND_STEP) {
      my $rgb = sprintf("#%02x%02x%02x", @color);
      push @BLEND, $self->{x}->object_get('color', $rgb, $rgb);
      $color[$_] += $delta[$_] for 0..2;
      @color = @{$FOCUS} if $_ == $BLEND_STEP;
    }
  }

  $self->{client} = PerlWM::Client->new(x => $self->{x}, 
					id => $self->{client_id},
					attr => $self->{client_attr},
					frame => $self);

  $self->{x}->ChangeSaveSet('Insert', $self->{client_id});

  my %geom = $self->{client}->GetGeometry();

  my($mask, @grab) = $self->event_mask();

  $mask |= $self->{x}->pack_event_mask('SubstructureNotify',
				       'SubstructureRedirect');

  $self->create(x => $geom{x} - 2,
		y => $geom{y} - 20,
		width => $geom{width} + 4,
		height => $geom{height} + 4 + 20,
		background_pixel => $BLEND[0],
		event_mask => $mask);

  # grab things (but not things without modifiers)
  $self->event_grab(grep $_->{mods}, @grab);

  $self->{blend} = [0, 0];

  $self->{label} = PerlWM::Widget::Label->new(x => $self->{x},
					      padding => 2,
					      value => $self->{client}->{prop}->{WM_NAME});
  $self->{label}->create(parent => $self,
			 x => 2, y => 2,
			 width => $geom{width}, height => 18);
  $self->{label}->MapWindow();

  $self->{client}->ConfigureWindow(border_width => 0);
  $self->{client}->ReparentWindow($self->{id}, 2, 2 + 20);

  $self->{client}->MapWindow() if $args{map_request};

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
    $arg{position} = [$position->[0] - 2, $position->[1] - 22];
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

sub configure_request {

  my($self, $event) = @_;
  my $xe = $event->{xevent};
  $self->{x}->ConfigureWindow($xe->{window},
			      map { exists $xe->{$_}?($_=>$xe->{$_}):()
				  } qw(x y width height 
				       border_width sibling stack_mode));
  if (defined($xe->{width}) && defined($xe->{height})) {
    $self->ConfigureWindow(width => $xe->{width} + 4,
			   height => $xe->{height} + 4 + 20);
  }
}

############################################################################

sub blend {
  my($self, $start) = @_;
  my $blend = $self->{blend};
  if (defined($start) && (!ref($start))) {
    if ((($start == -1) && ($blend->[0] == 0) ||
	 ($start == 1) && ($blend->[0] == $#BLEND))) {
      # already there
      return;
    }
    $blend->[1] = $start;
  }
  $blend->[0] += $blend->[1];
  $self->ChangeWindowAttributes(background_pixel => $BLEND[$blend->[0]]);
  $self->ClearArea();
  if ((($blend->[1] == -1) && ($blend->[0] == 0) ||
       ($blend->[1] == 1) && ($blend->[0] == $#BLEND))) {
    # made it
    $blend->[1] = 0;
  }
  elsif ($blend->[1]) {
    # not there yet, keep going
    $self->timer_set($BLEND_DELAY, 'Blend');
  }
}

############################################################################

sub enter {

  my($self, $event) = @_;
  return unless my $client = $self->{client};
  return if $event->{detail} eq 'Inferior';
  return if $event->{mode} eq 'Grab';
  return if $self->{perlwm}->{focus} == $self;

  $client->SetInputFocus('None', 'CurrentTime');
  $self->{perlwm}->{focus} = $self;
  $self->blend(1);

  $self->timer_set(10000, 'Raise');
}

############################################################################

sub leave {

  my($self, $event) = @_;
  return unless my $client = $self->{client};
  return if $event->{detail} eq 'Inferior';
  return unless $event->{mode} eq 'Normal';
  return unless $self->{perlwm}->{focus} == $self;

  $self->{x}->SetInputFocus('None', 'None', 'CurrentTime');
  $self->{perlwm}->{focus} = $self->{perlwm};
  $self->blend(-1);
  $self->timer_set(0, 'Raise');
}

############################################################################

sub auto_raise {

  my($self, $event) = @_;
  return unless $self->{perlwm}->{focus} == $self;
  $self->ConfigureWindow(stack_mode => 'Above');
}

############################################################################

sub destroy_notify {

  my($self, $event) = @_;
  $self->{client}->detach(destroyed => 1);
  $self->{client} = undef;
  $self->destroy();
}

############################################################################

sub map_notify {

  my($self, $event) = @_;
  $self->MapWindow();
}

############################################################################

sub unmap_notify {

  my($self, $event) = @_;
  return if $self->{client}->{iconified};
  $self->UnmapWindow();
}

############################################################################

sub prop_wm_name {

  my($self, $event) = @_;
  return unless my $client = $self->{client};
  if ($client->{icon}) {
    $client->{icon}->{label}->{value} = $client->{prop}->{WM_NAME};
  }
  $self->{label}->{value} = $client->{prop}->{WM_NAME};
}

############################################################################

action_register('keyboard_move', 'PerlWM::Action::Move');

sub EVENT { ( __PACKAGE__->SUPER::EVENT,

	      # TODO: load these bindings via some config stuff
	     'Drag(Button1)' => action('move_opaque'),
	     'Drag(Mod1 Button1)' => action('move_opaque'),

	     'Click(Button1)' => action('raise_window'),
	     'Click(Mod1 Button1)' => action('raise_window'),

	     'Click(Button3)' => action('iconify_window'),
	     'Click(Mod1 Button3)' => action('iconify_window'),

	     'Drag(Button2)' => action('resize_opaque'),
	     'Drag(Mod1 Button2)' => action('resize_opaque'),

	     'Key(Mod4 m)' => action('keyboard_move'),

	     # TODO: config for focus policy
	     'Enter' => \&enter,
	     'Leave' => \&leave,
	     'Timer(Raise)' => \&auto_raise,
	     'Timer(Blend)' => \&blend,

	     'ConfigureRequest' => \&configure_request,
	     'DestroyNotify' => \&destroy_notify,
	     'MapNotify' => \&map_notify,
	     'UnmapNotify' => \&unmap_notify ) }

############################################################################

1;
