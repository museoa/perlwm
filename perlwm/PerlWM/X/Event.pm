#
# $Id$
# 

package PerlWM::X::Event;

############################################################################

use strict;
use warnings;

############################################################################

=pod

Notes
=====

meta => kind of event hook - window, class, global

value => what the meta-value was - windowid, classid, undef

event => type of event (click, drag, propchange)
 
arg => argument of event (buttons, propname)

=cut

############################################################################

my $X_MOUSE_EVENT = qr/^(?:ButtonPress|ButtonRelease|MotionNotify)$/;
my $MOUSE_EVENT = qr/^(?:Click|Drag)$/;

my $MOD_MASK = 0x000ff;
my $BUT_MASK = 0x01f00;
my $NUM_MASK = 0x3e000;

my %MOD_BITS = (Shift => 0x01, Lock => 0x02, Control => 0x04, 
		map {("Mod$_" => (0x04 << $_))} (1..5));
my %BUT_BITS = map {("Button$_" => (0x80 << $_))} (1..5);
my %NUM_BITS = (Single => 0x2000, Double => 0x4000, Triple => 0x8000,
		Quad => 0x10000, Pent => 0x20000);

my %ALL_BITS = (%MOD_BITS, %BUT_BITS, %NUM_BITS);
my %RALL_BITS = reverse %ALL_BITS;

my %EVENT_TO_XMASK = (Enter => 'EnterWindow',
		      Leave => 'LeaveWindow');

my %XEVENT_TO_EVENT = (EnterNotify => 'Enter',
		       LeaveNotify => 'Leave');

############################################################################

# TODO: move these into object
my $DRAG_THRESHOLD = 2;
my $MULTI_CLICK_TIME = 250;

############################################################################

sub event_init {

  my($self) = @_;

  $self->{event} = { window => {}, class => {}, global => {} };

  $self->{timer} = [];

  $self->{mouse} = { clicks => 0, click_count => 0, drag => 0 };
}

############################################################################

sub event_button_pack {

  my($self, @bits) = @_;
  return 0 unless @bits;
  my $result = 0;
  $result |= $ALL_BITS{$_} for @bits;
  $result |= $NUM_BITS{Single} unless $result & $NUM_MASK;
  return $result;
}

############################################################################

sub event_button_unpack {

  my($self, $value) = @_;
  for (my $button = 1; $button <= 5; $button++) {
    return ($value & 0xff, $button) if ($value & (0x80 << $button));
  }
  return (0, 0);
}

############################################################################

sub event_timer {

  my($self, $timeout, $data) = @_;
  
  # delete timer
  @{$self->{timer}} = grep { $_->[1] ne $data } @{$self->{timer}};

  if ($timeout) {
    # add timer
    @{$self->{timer}} = sort { $a->[0] <=> $b->[0] 
			     } @{$self->{timer}}, [$timeout, $data];
  }
}

############################################################################

sub event_add {

  my($self, $meta, $value, $event, $arg, $handler) = @_;

  $handler = { sub => $handler } if ref $handler eq 'CODE';
  $handler->{arg} ||= [];

  my $hash = $self->{event}->{$meta};
  $hash = ($hash->{$value} ||= {}) if $meta ne 'global';

  if (defined($arg)) {
    $arg = $self->event_button_pack(split / /, $arg) if $event =~ $MOUSE_EVENT;
    $hash->{$event}->{$arg} = $handler;
  }
  else {
    $hash->{$event} = $handler;
  }
}

############################################################################

sub event_add_window {

  my($self, $window, $event, $arg, $handler) = @_;
  
  die "not a window\n" unless $window->isa('PerlWM::X::Window');
  $self->event_add('window', $window->{id}, $event, $arg, $handler);
  $self->event_window_hook($window);
}

############################################################################

sub event_add_class {

  my($self, $class, $event, $arg, $handler) = @_;

  $self->event_add('class', $class, $event, $arg, $handler);
}

############################################################################

sub event_add_global {

  my($self, $event, $arg, $handler) = @_;

  $self->event_add('global', undef, $event, $arg, $handler);
}

############################################################################

sub event_window_hook {

  my($self, $window, $grab) = @_;

  die "not a window\n" unless $window->isa('PerlWM::X::Window');

  return unless $self->{event_loop_started};

  $grab ||= $self->alien($window->{id});

  my $mask = $window->{extra_event_mask} || 0;

  foreach my $event ($self->{event}->{window}->{$window->{id}},
		     $self->{event}->{class}->{ref $window},
		     $self->{event}->{global}) {
    while (my($k, $v) = each %{$event}) {
      if ($k =~ $MOUSE_EVENT) {
	$mask |= $self->pack_event_mask(qw(ButtonPress ButtonRelease));
	if ($k eq 'Drag') {
	  foreach (keys %{$v}) {
	    if (my $button = $RALL_BITS{$_ & $BUT_MASK}) {
	      $mask |= $self->pack_event_mask("${button}Motion");
	    }
	  }
	}
	if ($grab) {
	  foreach (keys %{$v}) {
	    if (my $button = $RALL_BITS{$_ & $BUT_MASK}) {
	      $self->GrabButton($_ & $MOD_MASK, $button, 
				$window->{id}, 1, $mask,
				'Asynchronous', 'Asynchronous', 
				'None', 'None')
	    }
	  }
	}
      }
      else {
	$mask |= $self->pack_event_mask($EVENT_TO_XMASK{$k} || $k);
      }
    }
  }

  $self->ChangeWindowAttributes($window->{id}, event_mask => $mask)
    unless $grab;
}

############################################################################

sub event_hook_all {

  my($self) = @_;
  foreach my $window (values %{$self->{window}}) {
    $self->event_window_hook($window);
  }
}

############################################################################

sub event_loop {

  # TODO: currently, two single clicks will only fire a single single
  # because the timing code doesn't know that nobody is listening for
  # the double click - might need to kludge round that somehow.

  my($self) = @_;

  my $hires = eval { require Time::HiRes; \&Time::HiRes::time; };
  my $stime = $hires ? &{$hires}() : time();

  $self->{event_loop_started} = 1;
  $self->event_hook_all();

  $self->event_handler('queue');
  my($bits, $time, $adjust, %event) = ('');
  vec($bits, fileno($self->{connection}->fh()), 1) = 1;
 event:
  while (1) {
    if (my $timer = $self->{timer}->[0]) {
      if ($timer->[0] <= 0) {
	# timer has already expired
	shift @{$self->{timer}};
	# fake an event
	%event = ( name => 'Timer', data => $timer->[1] );
	# no adjustment
	$adjust = 0;
      }
      else {
	# wait for something to happen
	$time = &{$hires}() if $hires;
	my $x = select(my $ignore = $bits, undef, undef, $timer->[0] / 1000);
	$adjust = &{$hires}() - $time if $hires;
	if ($x) {
	  # something arrived before timeout
	  $self->handle_input();
	  # is there an event ready now?
	  if (%event = $self->dequeue_event()) {
	    # use server time if we don't have time::hires
	    $adjust = $event{time} - $time unless $hires;
	  }
	} 
	else {
	  # timeout - drop the timer
	  shift @{$self->{timer}};
	  # fake an event
	  %event = ( name => 'Timer', data => $timer->[1] );
	  # adjust by timer value if we don't have have time::hires
	  $adjust = $timer->[0];
	}
	# adjust other timers 
	$_->[0] -= $adjust for @{$self->{timer}};
      }
    }
    else {
      # just wait for the next event
      %event = $self->next_event();
    }
    if (%event) {
      # remember the server time if we need it
      $time = $event{time} if $event{time} && !$hires;
      # deal with mouse events
      if (($event{name} =~ $X_MOUSE_EVENT) || 
	  (($event{name} eq 'Timer') && ($event{data} eq $self->{mouse}))) {
	my %fire;
#	printf("%8.4f $event{name} $event{data}\n", 
#	       ($hires ? &{$hires}() : time()) - $stime);
	if ($event{name} eq 'ButtonRelease') {
	  if ($self->{mouse}->{drag} > $DRAG_THRESHOLD) {
	    %fire = (%event, 
		     name => 'Drag', 
		     state => $self->{mouse}->{drag_state},
		     event => $self->{mouse}->{target},
		     press => $self->{mouse}->{press},
		     xevent => {%event},
		     arg => $self->{mouse}->{bits},
		     drag => 'stop');
	  }
	  else {
	    %fire = (%event, 
		     name => 'Click',
		     event => $self->{mouse}->{target},
		     xevent => {%event},
		     arg => $self->{mouse}->{bits});
	  }
	} 
	elsif ($event{name} eq 'ButtonPress') {
	  $self->{mouse}->{bits} = 
	    (($event{state} & $MOD_MASK) |
	     ($BUT_BITS{Button1} << ($event{detail} - 1)) |
	     ($NUM_BITS{Single} << ($self->{mouse}->{click_count})));
	  $self->{mouse}->{target} = $event{event};
	  $self->{mouse}->{click_count}++;
	  $self->{mouse}->{drag} = 0;
	  $self->{mouse}->{press} = \%event;
	  $self->event_timer($MULTI_CLICK_TIME, $self->{mouse});
	}
	elsif ($event{name} eq 'MotionNotify') {
	  $self->{mouse}->{drag}++;
	  if ($self->{mouse}->{drag} == $DRAG_THRESHOLD) {
	    $self->{mouse}->{drag_state} = { };
	    %fire = (%event, 
		     name => 'Drag', 
		     state => $self->{mouse}->{drag_state},
		     event => $self->{mouse}->{target},
		     press => $self->{mouse}->{press},
		     xevent => {%event},
		     arg => $self->{mouse}->{bits},
		     drag => 'start');
	  }
	  elsif ($self->{mouse}->{drag} > $DRAG_THRESHOLD) {
	    %fire = (%event, 
		     name => 'Drag', 
		     state => $self->{mouse}->{drag_state},
		     event => $self->{mouse}->{target},
		     press => $self->{mouse}->{press},
		     xevent => {%event},
		     arg => $self->{mouse}->{bits},
		     drag => 'move');
	  }
	}
	elsif ($event{name} eq 'Timer') {
	  $self->{mouse}->{click_count} = 0;
	}
	next unless %fire;
	%event = %fire;
      }
      else {
	# other event - map the name
	$event{name} = $XEVENT_TO_EVENT{$event{name}} || $event{name};
      }
      # dispatch the event
      my($id, $window, $value, $target);
      my($name, $arg) = ($event{name}, $event{arg});
      # find the most specific event binding
      foreach my $meta (qw(window class global)) {
	# use various event window fields
	foreach my $field (qw(event child window)) {
	  next unless $id = $event{$field};
	  if ($meta eq 'global') {
	    next unless $target = $self->{event}->{global}->{$name};
	    ($window, $value) = ($id, 'global');
	  }
	  else {
	    $window = $self->{window}->{$id};
	    next unless $value = ($meta eq 'window') ? $id : ref $window;
	    next unless $target = $self->{event}->{$meta}->{$value}->{$name};
	  }
	  next unless (!defined($arg)) || ($target = $target->{$arg});
	  @event{qw(meta value window x)} = ($meta, $value, $window, $self);
	  next event if &{$target->{sub}}(@{$target->{arg}}, \%event);
	}
      }
    }
  }
}

############################################################################

sub event_dump {

  my($self) = @_;

  require Data::Dumper;
  my @fields = qw(event);
  my $dd = Data::Dumper->new([@{$self}{@fields}], \@fields)->Indent(1);
  print STDERR $dd->Dump();
}

############################################################################

1;

