#
# $Id$
#

package PerlWM::Action::Builtin;

############################################################################

use strict;
use warnings;

use PerlWM::Action;

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
    if ($frame) {
      $frame->ConfigureWindow(stack_mode => 'Above');
    }
    $state->{orig_position} = $frame->position();
  }
  if ($event->{delta}->[0] && $event->{delta}->[1]) {
    $frame->configure(position => [$state->{orig_position}->[0] + $event->{delta}->[0],
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
    if ($frame) {
      $frame->ConfigureWindow(stack_mode => 'Above');
    }
    $state->{orig_position} = $frame->position();
    $state->{orig_size} = $frame->size();
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
    $frame->configure(position => $position, size => $size);
  }
  return 1;
}

############################################################################

sub lower_window {

  my($window, $event) = @_;
  $window->ConfigureWindow(stack_mode => 'Below');
}

############################################################################

sub raise_window {

  my($window, $event) = @_;
  $window->ConfigureWindow(stack_mode => 'Above');
}


############################################################################

sub iconify_window {

  my($window, $event) = @_;
  $window->iconify();
}

############################################################################

sub deiconify_window {

  my($window, $event) = @_;
  $window->{frame}->deiconify();
}

############################################################################

sub move_icon_opaque {

  my($window, $event) = @_;
  my $state = $event->{state};
  if ($event->{drag} eq 'start') {
    $state->{orig_position} = $window->position();
    $window->ConfigureWindow(stack_mode => 'Above');
  }
  if ($event->{delta}->[0] && $event->{delta}->[1]) {
    $window->ConfigureWindow(x => $state->{orig_position}->[0] + $event->{delta}->[0],
			     y => $state->{orig_position}->[1] + $event->{delta}->[1]);
  }
}

############################################################################

1;
