#
# $Id$
#

package PerlWM;

############################################################################

use strict;
use warnings;

use base qw(PerlWM::X::Window);

use PerlWM::X;
use PerlWM::Icon;
use PerlWM::Frame;
use PerlWM::Client;
use PerlWM::Widget;
use PerlWM::Action;

############################################################################

sub new {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $x = PerlWM::X->new(display => $ENV{DISPLAY},
			 debug => $ENV{PERLWM_DEBUG});
  my $self = $class->SUPER::new(x => $x, id => $x->{root});

  PerlWM::Widget->init($x);

  my(@clients);
  eval {
    local $self->{x}->{error_handler} = sub {
      die "Window Manager already running\n";
    };
    my $ssr = $self->{x}->pack_event_mask('SubstructureRedirect');
    $self->ChangeWindowAttributes(id => $self->{id},
				  event_mask => $self->event_mask($ssr));
    (undef, undef, @clients) = $self->{x}->QueryTree($self->{x}->{root});
    $self->manage_window($_) for @clients;
    $self->{focus} = $self;
  };
  if ($@) {
    warn $@;
    return undef;
  }
  else {
    $self->{x}->event_loop();
    # won't actually get here
    return $self;
  }
}

############################################################################

sub manage_window {

  my($self, $id, $map_request) = @_;

  my(%attr) = $self->{x}->GetWindowAttributes($id);

  return if $attr{override_redirect};
  return if ((!$map_request) && ($attr{map_state} ne 'Viewable'));

  return PerlWM::Frame->new(x => $self->{x},
			    perlwm => $self,
			    client_id => $id, 
			    client_attr => \%attr,
			    map_request => $map_request);
}

############################################################################

sub map_request {

  my($self, $event) = @_;
  $self->manage_window($event->{xevent}->{window}, 1);
}

############################################################################

sub configure_request {

  my($self, $event) = @_;
  my $xe = $event->{xevent};
  $self->{x}->ConfigureWindow($xe->{window},
			      map { exists $xe->{$_}?($_=>$xe->{$_}):() 
				  } qw(x y width height 
				       border_width sibling stack_mode));
}

############################################################################

sub EVENT {
  return ( MapRequest => \&map_request,
	   ConfigureRequest => \&configure_request );
}

############################################################################

1;
