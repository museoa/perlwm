#
# $Id$
# 

package PerlWM::Client;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::X::Window);

use PerlWM::Icon;
use PerlWM::Frame;

############################################################################

sub new {

  my($proto, %arg) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%arg);

  $self->{frame} = PerlWM::Frame->new(x => $self->{x}, client => $self);

  $self->MapWindow() if $arg{map_request};

  return $self;
}

############################################################################

sub check_size {

  my($self, $size) = @_;

  return unless my $hints = $self->{prop}->{WM_NORMAL_HINTS};

  foreach (0,1) {
    if (my $min = $hints->{PMinSize}) {
      $size->[$_] = $min->[$_] if $size->[$_] < $min->[$_];
    }
    if (my $inc = $hints->{PResizeInc}) {
      my $base = $hints->{PBaseSize};
      $size->[$_] -= $base->[$_] if $base;
      $size->[$_] = $inc->[$_] * (int($size->[$_] / $inc->[$_]));
      $size->[$_] += $base->[$_] if $base;
    }
  }
}

############################################################################

sub position {

  my($self) = @_;
  my %geom = $self->GetGeometry();
  if ($self->{frame}) {
    my %fgeom = $self->{frame}->GetGeometry();
    $geom{x} += $fgeom{x};
    $geom{y} += $fgeom{y};
  }
  return [$geom{x}, $geom{y}];
}

############################################################################

sub size {

  my($self) = @_;
  my %geom = $self->GetGeometry();
  return [$geom{width}, $geom{height}];
}

############################################################################

sub configure {

  my($self, %arg) = @_;

  $self->check_size($arg{size}) if $arg{size};

  if ($self->{frame}) {
    $self->{frame}->configure(%arg);
    delete $arg{position};
    delete $arg{stack_mode};
  }
  if (my $size = delete $arg{size}) {
    $arg{width} = $size->[0];
    $arg{height} = $size->[1];
  }
  if (my $position = delete $arg{position}) {
    $arg{x} = $position->[0];
    $arg{y} = $position->[1];
  }
  if (%arg) {
    $self->ConfigureWindow(%arg);
  }
}

############################################################################

sub iconify {

  my($self) = @_;
  unless ($self->{icon}) {
    $self->{icon} = PerlWM::Icon->new(x => $self->{x}, client => $self);
  }
  $self->{icon}->MapWindow();
  if ($self->{frame}) {
    $self->{frame}->UnmapWindow();
  }
  else {
    $self->{frame}->UnmapWindow();
  }
}

############################################################################

sub deiconify {

  my($self) = @_;
  if ($self->{frame}) {
    $self->{frame}->MapWindow();
  }
  else {
    $self->{frame}->MapWindow();
  }
  $self->{icon}->UnmapWindow();
}

############################################################################

1;
