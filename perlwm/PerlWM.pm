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

############################################################################

sub perlwm {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = { %args };
  bless $self, $class;

  $self->{x} = PerlWM::X->new($ENV{DISPLAY});

  $self->{x}->event_add_class
    ('PerlWM::Frame', 'Enter', undef,
     sub { 
       my($event) = @_;
       my $frame = $event->{window};
       $frame->{client}->SetInputFocus('None', 'CurrentTime');
       $frame->ConfigureWindow(stack_mode => 'Above');
     });

  $self->{x}->event_add_class('PerlWM::Frame', 'Drag', 'Button1', \&move_opaque);
  $self->{x}->event_add_class('PerlWM::Client', 'Drag', 'Mod1 Button1', \&move_opaque);
  
  $self->{x}->event_add_class('PerlWM::Frame', 'Click', 'Button2', \&lower_window);
  $self->{x}->event_add_class('PerlWM::Client', 'Click', 'Mod1 Button2', \&lower_window);

  $self->{x}->event_add_class('PerlWM::Frame', 'Drag', 'Button3', \&size_drag);
  $self->{x}->event_add_class('PerlWM::Client', 'Drag', 'Mod1 Button3', \&size_drag);

  $self->{x}->event_add_class('PerlWM::Frame', 'DestroyNotify', undef, \&destroy_notify);
  $self->{x}->event_add_class('PerlWM::Frame', 'MapNotify', undef, \&map_notify);
  $self->{x}->event_add_class('PerlWM::Frame', 'UnmapNotify', undef, \&unmap_notify);

  $self->{x}->event_add_global('MapRequest', undef, 
			       { sub => sub {
				   my($self, $event) = @_;
				   $self->manage_window($event->{window}, 1);
				 },
				 arg => [ $self ] });

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

  $self->{x}->MapWindow($id) if $map_request;

  my $client = PerlWM::Client->new(x => $self->{x}, id => $id, attr => \%attr);

  $self->{x}->ChangeSaveSet('Insert', $id);

  $client->{frame} = PerlWM::Frame->new(x => $self->{x}, client => $client);

  return $client;
}

############################################################################

sub move_opaque {

  my($event) = @_;
  my($frame, $client);
  if ($event->{window}->isa('PerlWM::Frame')) {
    $frame = $event->{window};
    $client = $frame->{client};
  }
  elsif ($event->{window}->isa('PerlWM::Client')) {
    $client = $event->{window};
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
  my($event) = @_;
  my($frame, $client);
  if ($event->{window}->isa('PerlWM::Frame')) {
    $frame = $event->{window};
    $client = $frame->{client};
  }
  elsif ($event->{window}->isa('PerlWM::Client')) {
    $client = $event->{window};
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

  my($event) = @_;
  my($frame, $client);
  #------------------------------------------
  if ($event->{window}->isa('PerlWM::Frame')) {
    $frame = $event->{window};
    $client = $frame->{client};
  }
  elsif ($event->{window}->isa('PerlWM::Client')) {
    $client = $event->{window};
    $frame = $client->{frame};
  }
  #------------------------------------------
  $frame->ConfigureWindow(stack_mode => 'Below');
  return 1;
}

############################################################################

sub destroy_notify {

  my($event) = @_;
  return unless ref $event->{window};
  $event->{window}->DestroyWindow();
}

############################################################################

sub map_notify {

  my($event) = @_;
  return unless ref $event->{window};
  $event->{window}->MapWindow();
}

############################################################################

sub unmap_notify {

  my($event) = @_;
  return unless ref $event->{window};
  $event->{window}->UnmapWindow();
}

############################################################################
1;
