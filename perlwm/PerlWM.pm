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
  
  $self->{x}->event_add_hook('PerlWM::Frame', 'Click(Button3)', \&lower_window);
  $self->{x}->event_add_hook('PerlWM::Client', 'Click(Mod1 Button3)', \&lower_window);

  $self->{x}->event_add_hook('PerlWM::Frame', 'Drag(Button2)', \&size_drag);
  $self->{x}->event_add_hook('PerlWM::Frame', 'Drag(Mod1 Button2)', \&size_drag);
  $self->{x}->event_add_hook('PerlWM::Client', 'Drag(Mod1 Button2)', \&size_drag);

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
    my %geom = $frame->GetGeometry($frame);
    $state->{orig_geom} = \%geom;
    $state->{offset_x} = $geom{x} - $event->{root_x};
    $state->{offset_y} = $geom{y} - $event->{root_y};
  }
  $frame->ConfigureWindow(x => $state->{offset_x} + $event->{root_x}, 
			  y => $state->{offset_y} + $event->{root_y});
  return 1;
}

############################################################################

sub size_drag {

  #-------------------------------------------------------------
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
  #-------------------------------------------------------------
  if ($event->{drag} eq 'start') {
    my %geom = $frame->GetGeometry($frame);
    $state->{frame_orig_geom} = \%geom;
    my %geom = $client->GetGeometry($client);
    $state->{client_orig_geom} = \%geom;
    $state->{start_x} =  - $event->{root_x};
    $state->{start_y} =  - $event->{root_y};
  }
  #-------------------------------------------------------------
  if ( ( ( $state->{start_x} + $event->{root_x} ) != 0 )  ||
       ( ( $state->{start_y} + $event->{root_y} ) != 0 ) ) {
    #------------------------------------------
    my $inc_x=$event->{root_x} +  $state->{start_x} ;
    my $inc_y=$event->{root_y} +  $state->{start_y} ;
    #------------------------
    $frame->ConfigureWindow(
			    width => $state->{frame_orig_geom}->{width}  + $inc_x ,
			    height => $state->{frame_orig_geom}->{height}  + $inc_y ) ;
    #------------------------
    $client->ConfigureWindow(
			     width => $state->{client_orig_geom}->{width}  + $inc_x ,
			     height => $state->{client_orig_geom}->{height}  + $inc_y ) ;
    #------------------------------------------
  }
  return 1;
  #-------------------------------------------------------------
}

############################################################################

sub lower_window {

  my($window, $event) = @_;
  my($frame, $client);
  #------------------------------------------
  if ($window->isa('PerlWM::Frame')) {
    $frame = $window;
    $client = $frame->{client};
  }
  elsif ($window->isa('PerlWM::Client')) {
    $client = $window;
    $frame = $client->{frame};
  }
  #------------------------------------------
  $frame->ConfigureWindow(stack_mode => 'Below');
  return 1;
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
  $window->UnmapWindow();
}

############################################################################
1;
