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

  $self->{x}->event_add_class
    ('PerlWM::Frame', 'Leave', undef,
     sub { 
       my($event) = @_;
       my $frame = $event->{window};
       return if $event->{detail} eq 'Inferior';
       $frame->ConfigureWindow(stack_mode => 'Below');
    });

  $self->{x}->event_add_class('PerlWM::Frame', 'Drag', 'Button1', \&move_opaque);
  $self->{x}->event_add_class('PerlWM::Client', 'Drag', 'Mod1 Button1', \&move_opaque);
  
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

  my($self, $id) = @_;

  my(%attr) = $self->{x}->GetWindowAttributes($id);

  return if (($attr{override_redirect}) || ($attr{map_state} ne 'Viewable'));

  my $client = PerlWM::Client->new(x => $self->{x}, id => $id, attr => \%attr);

  $self->{x}->ChangeSaveSet('Insert', $id);

  $client->{frame} = PerlWM::Frame->new(x => $self->{x}, client => $client);
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

1;
