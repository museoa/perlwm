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

  $self->{client} = PerlWM::Client->new(x => $self->{x}, 
					id => $self->{client_id},
					attr => $self->{client_attr},
					frame => $self);

  $self->{x}->ChangeSaveSet('Insert', $self->{client_id});

  my %geom = $self->{client}->GetGeometry();

  my($mask, @grab) = $self->{client}->event_mask();
  
  $mask |= $self->{x}->pack_event_mask('SubstructureNotify',
				       'SubstructureRedirect');

  $self->create(x => $geom{x} - 2,
		y => $geom{y} - 20,
		width => $geom{width} + 4,
		height => $geom{height} + 4 + 20,
		background_pixel => $self->{x}->{white_pixel},
		event_mask => $self->event_mask($mask));
  
  foreach (@grab) {
    # set up grabs from the client
    $self->{x}->GrabButton($_->[0], $_->[1], $self->{id}, 0, $_->[2],
			   'Asynchronous', 'Asynchronous', 'None', 'None');
    
  }

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

sub enter {

  my($self, $event) = @_;
  return unless my $client = $self->{client};
  return if $event->{detail} eq 'Inferior';
  $client->SetInputFocus('None', 'CurrentTime');
  # TODO: raise after delay?
  # $frame->ConfigureWindow(stack_mode => 'Above');
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

use PerlWM::Action;

sub EVENT {
  return (
	  # TODO: load these bindings via some config stuff
	  'Drag(Button1)' => \&PerlWM::Action::move_opaque,
	  'Drag(Mod1 Button1)' => \&PerlWM::Action::move_opaque,

	  'Click(Button1)' => \&PerlWM::Action::raise_window,
	  'Click(Mod1 Button1)' => \&PerlWM::Action::raise_window,

	  'Click(Button3)' => \&PerlWM::Action::iconify_window,
	  'Click(Mod1 Button3)' => \&PerlWM::Action::iconify_window,

	  'Drag(Button2)' => \&PerlWM::Action::resize_opaque,
	  'Drag(Mod1 Button2)' => \&PerlWM::Action::resize_opaque,

	  # TODO: config for focus policy
	  'Enter' => \&enter,
	  'ConfigureRequest' => \&configure_request,
	  'DestroyNotify' => \&destroy_notify,
	  'MapNotify' => \&map_notify,
	  'UnmapNotify' => \&unmap_notify,

	  __PACKAGE__->SUPER::EVENT);
}

############################################################################

1;
