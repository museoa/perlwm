#
# $Id$
# 

package PerlWM;

############################################################################

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(perlwm);

use strict;

use Data::Dumper; $Data::Dumper::Indent = 1;

use PerlWM::X;
use PerlWM::Icon;
use PerlWM::Frame;
use PerlWM::Client;
use PerlWM::Widget;

############################################################################

sub perlwm {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = { %args };
  bless $self, $class;

  $self->{x} = PerlWM::X->new(display => $ENV{DISPLAY},
			      debug => $ENV{PERLWM_DEBUG});

  PerlWM::Widget->init($self->{x});

  # TODO: move all these into Client/Frame

  $self->{x}->event_add_hook
    ('PerlWM::Frame', 'Enter', 
     sub { 
       my($frame, $event) = @_;
       return unless $frame->{client};
       return if $event->{detail} eq 'Inferior';
       $frame->{client}->SetInputFocus('None', 'CurrentTime');
       $frame->ConfigureWindow(stack_mode => 'Above');
     });

  $self->{x}->event_add_hook('PerlWM::Frame', 'Drag(Button1)', \&move_opaque);
  $self->{x}->event_add_hook('PerlWM::Frame', 'Drag(Mod1 Button1)', \&move_opaque);
  $self->{x}->event_add_hook('PerlWM::Client', 'Drag(Mod1 Button1)', \&move_opaque);

  $self->{x}->event_add_hook('PerlWM::Frame', 'Click(Button3)', \&iconify_window);
  $self->{x}->event_add_hook('PerlWM::Frame', 'Click(Mod1 Button3)', \&iconify_window);
  $self->{x}->event_add_hook('PerlWM::Client', 'Click(Mod1 Button3)', \&iconify_window);

  $self->{x}->event_add_hook('PerlWM::Icon', 'Drag(Button1)', \&move_icon_opaque);
  $self->{x}->event_add_hook('PerlWM::Icon', 'Drag(Mod1 Button1)', \&move_icon_opaque);
  $self->{x}->event_add_hook('PerlWM::Icon', 'Click(Button1)', \&deiconify_window);
  $self->{x}->event_add_hook('PerlWM::Icon', 'Click(Double Button1)', \&deiconify_window);

  $self->{x}->event_add_hook('PerlWM::Frame', 'Drag(Button2)', \&resize_opaque);
  $self->{x}->event_add_hook('PerlWM::Frame', 'Drag(Mod1 Button2)', \&resize_opaque);
  $self->{x}->event_add_hook('PerlWM::Client', 'Drag(Mod1 Button2)', \&resize_opaque);

  $self->{x}->event_add_hook('PerlWM::Frame', 'DestroyNotify', \&destroy_notify);
  $self->{x}->event_add_hook('PerlWM::Frame', 'MapNotify', \&map_notify);
  $self->{x}->event_add_hook('PerlWM::Frame', 'UnmapNotify', \&unmap_notify);

  $self->{x}->event_add_hook('PerlWM::Client', 'ConfigureRequest', sub {
			       my($client, $event) = @_;
			       print "client configure request\n";
			       # TODO: actually need to do lots more
			       my $xe = $event->{xevent};
			       $self->{x}->ConfigureWindow($xe->{window},
							   map { exists $xe->{$_}?($_=>$xe->{$_}):() 
							       } qw(x y width height 
								    border_width sibling stack_mode));
			       if (defined($xe->{width}) && defined($xe->{height}) && 
				   defined($client->{frame})) {
				     $client->{frame}->ConfigureWindow(width => $xe->{width} + 4,
								       height => $xe->{height} + 4 + 20);
			       }
#			       $client->{x}->dumper($event);
			     });

  $self->{x}->event_add_hook('PerlWM::Client', 'Property(WM_NAME)', sub {
			       my($client) = @_;
			       $client->{frame}->{label}->{value} = $client->{prop}->{WM_NAME};
			     });

  $self->{x}->event_add_global('MapRequest', 
			       { sub => sub {
				   my($window, $event, $self) = @_;
				   $self->manage_window($window, 1);
				 },
				 arg => [ $self ] });

  # TODO: class for root window
  $self->{root} = PerlWM::X::Window->new(x => $self->{x}, id => $self->{x}->{root});
  # let through any configure requests for new windows (before they are mapped)
  $self->{root}->event_add('ConfigureRequest',
			   sub {
			     my($root, $event) = @_;
			     my $xe = $event->{xevent};
			     $self->{x}->ConfigureWindow($xe->{window},
							 map { exists $xe->{$_}?($_=>$xe->{$_}):() 
							     } qw(x y width height 
								  border_width sibling stack_mode));
			   });

  $self->init_wm();

  $self->{x}->event_loop() unless $self->{no_event_loop};

  return $self;
}

############################################################################

sub init_wm {

  my($self) = @_;

  my(@clients);  
  {
    local $self->{x}->{error_handler} = sub { 
      die "Window Manager already running\n"; 
    };
    my $em = $self->{x}->pack_event_mask('SubstructureRedirect');
    $self->{x}->ChangeWindowAttributes($self->{x}->root, 'event_mask' => $em);
    (undef, undef, @clients) = $self->{x}->QueryTree($self->{x}->{root});
  }

  $self->manage_window($_) for @clients;
}

############################################################################

sub manage_window {

  my($self, $id, $map_request) = @_;

  my(%attr) = $self->{x}->GetWindowAttributes($id);

  return if $attr{override_redirect};
  return if ((!$map_request) && ($attr{map_state} ne 'Viewable'));

  my $client = PerlWM::Client->new(x => $self->{x}, 
				   id => $id, 
				   map_request => 1,
				   attr => \%attr);

  $self->{x}->ChangeSaveSet('Insert', $id);

  return $client;
}

############################################################################

sub move_opaque {

  my($window, $event) = @_;
  my($frame, $client);
  if ($window->isa('PerlWM::Frame')) {
    $frame = $window;
    $client = $frame->{client};
  }
  elsif ($window->isa('PerlWM::Client')) {
    $client = $window;
    $frame = $client->{frame};
  }
  my $state = $event->{state};
  if ($event->{drag} eq 'start') {
    $state->{orig_position} = $client->position();
  }
  if ($event->{delta}->[0] && $event->{delta}->[1]) {
    $client->configure(position => [$state->{orig_position}->[0] + $event->{delta}->[0],
				    $state->{orig_position}->[1] + $event->{delta}->[1]])
  }
  return 1;
}

############################################################################

sub resize_opaque {

  my($window, $event) = @_;
  my($frame, $client);
  if ($window->isa('PerlWM::Frame')) {
    $frame = $window;
    $client = $frame->{client};
  }
  elsif ($window->isa('PerlWM::Client')) {
    $client = $window;
    $frame = $client->{frame};
  }
  my $state = $event->{state};
  if ($event->{drag} eq 'start') {
    $state->{orig_position} = $client->position();
    $state->{orig_size} = $client->size();
    my $click = [$event->{press}->{root_x}, $event->{press}->{root_y}];
    my $middle = [$state->{orig_position}->[0] + ($state->{orig_size}->[0] / 2),
		  $state->{orig_position}->[1] + ($state->{orig_size}->[1] / 2)];
    $state->{direction} = [$click->[0] < $middle->[0] ? -1 : 1,
			   $click->[1] < $middle->[1] ? -1 : 1];
  }
  if ($event->{delta}->[0] && $event->{delta}->[1]) {
    my $position = [@{$state->{orig_position}}];
    my $size = [@{$state->{orig_size}}];
    foreach (0,1) {
      if ($state->{direction}->[$_] < 0) {
	$position->[$_] += $event->{delta}->[$_];
	$size->[$_] -= $event->{delta}->[$_];
      }
      else {
	$size->[$_] += $event->{delta}->[$_];
      }
    }    
    $client->configure(position => $position, size => $size);
  }
  return 1;
}

############################################################################

sub lower_window {

  my($window, $event) = @_;
  my($frame, $client);
  if ($window->isa('PerlWM::Frame')) {
    $frame = $window;
    $client = $frame->{client};
  }
  elsif ($window->isa('PerlWM::Client')) {
    $client = $window;
    $frame = $client->{frame};
  }
  $frame->ConfigureWindow(stack_mode => 'Below');
  return 1;
}

############################################################################

sub iconify_window {

  my($window, $event) = @_;
  my($frame, $client);
  if ($window->isa('PerlWM::Frame')) {
    $frame = $window;
    $client = $frame->{client};
  }
  elsif ($window->isa('PerlWM::Client')) {
    $client = $window;
    $frame = $client->{frame};
  }
  $client->iconify();
}

############################################################################

sub deiconify_window {

  my($window, $event) = @_;
  return unless my $client = $window->{client};
  $client->deiconify();
}

############################################################################

sub move_icon_opaque {

  my($window, $event) = @_;
  my $state = $event->{state};
  if ($event->{drag} eq 'start') {
    $state->{orig_position} = $window->position();
  }
  if ($event->{delta}->[0] && $event->{delta}->[1]) {
    $window->ConfigureWindow(x => $state->{orig_position}->[0] + $event->{delta}->[0],
			     y => $state->{orig_position}->[1] + $event->{delta}->[1]);
  }
}

############################################################################

sub destroy_notify {
  my($frame, $event) = @_;
  return unless $frame->isa('PerlWM::Frame');
  $frame->{client}->detach(destroyed => 1);
  $frame->{client} = undef;
  $frame->destroy();
}

############################################################################

sub map_notify {

  my($window, $event) = @_;
  return unless ref $window;
  $window->MapWindow();
}

############################################################################

sub unmap_notify {

  my($window, $event) = @_;
  return unless ref $window;
  if ($window->isa('PerlWM::Frame')) {
    return if $window->{client}->{iconified};
  }
  $window->UnmapWindow();
}

############################################################################

1;
