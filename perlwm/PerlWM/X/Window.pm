#
# $Id$
# 

package PerlWM::X::Window;

############################################################################

use strict;
use warnings;

############################################################################

sub new {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = { %args };
  bless $self, $class;

  die "no x" unless $self->{x};
  die "invalid x" unless $self->{x}->isa('PerlWM::X');

  $self->{x}->window_attach($self) if $self->{id};

  return $self;
}

############################################################################

sub create {

  my($self, %args) = @_;

  # allow naming of args, and supply defaults
  my @args = (delete $args{parent} || $self->{x}->{root},
	      delete $args{class} || 'InputOutput',
	      delete $args{depth} || 'CopyFromParent',
	      delete $args{visual} || 'CopyFromParent',
	      delete $args{x} || 0 ,
	      delete $args{y} || 0 ,
	      delete $args{width} || 100 ,
	      delete $args{height} || 100,
	      delete $args{border_width} || 0);

  $self->{id} = $self->{x}->new_rsrc();
  $self->CreateWindow(@args, %args);
  $self->{x}->window_attach($self);
}

############################################################################

sub event_add {

  my($self, $event, $arg, $handler) = @_;
  $self->{x}->event_add_window($self, $event, $arg, $handler);
}

############################################################################

sub get_unpack_property {

  my($self, $name) = @_;
  my($value, $type, $format, $bytes_after) = 
    $self->GetProperty($name, 'AnyPropertyType', 0, -1, 0);

  if ($self->{x}->atom_name($type) eq 'STRING') {
    return [split(/\x00/, $value)];
  }
  elsif ($self->{x}->atom_name($type) eq 'WINDOW') {
    return unpack('L', $value);
  }
  elsif ($self->{x}->atom_name($type) eq 'ATOM') {
    return [map $self->{x}->atom_name($_), unpack('L*', $value)];
  }
  elsif ($self->{x}->atom_name($type) eq 'WM_STATE') {
    return [unpack('L*', $value)];
  }
  elsif ($self->{x}->atom_name($type) eq 'WM_HINTS') {
    my($flags, @fields) = unpack('L*', $value);
    my(@names) = qw(input state 
		    icon_pixmap icon_window icon_x icon_y icon_mask
		    group);
    my($result) = {'_type' => 'WM_HINTS'};
    foreach my $n (@names) {
      if ($flags & 1) {
	$result->{$n} = shift @fields;
      }
      $flags >>= 1;
    }
    return $result;
  }
  elsif ($self->{x}->atom_name($type) eq 'WM_SIZE_HINTS') {
    my($flags, @fields) = unpack('L*', $value);
    my(@names) = qw(x y width height 
		    min_width min_height max_width min_width
		    width_inc height_inc 
		    min_spect_x min_spect_y
		    max_spect_x max_spect_y
		    base_width base_height
		    win_gravity);
    my($result) = {'_type' => 'WM_SIZE_HINTS'};
    foreach my $n (@names) {
      if ($flags & 1) {
	$result->{$n} = shift @fields;
      }
      $flags >>= 1;
    }
    return $result;
  }
  else {
    return sprintf("%s (%d bytes)\n", $self->{x}->atom_name($type), length($value));
  }
}

############################################################################

sub AUTOLOAD {
  # this is just lazy really
  no strict 'vars';
  my($self, @args) = @_;
  my $method = $AUTOLOAD;
  my $class = ref $self;
  $method =~ s/\Q$class\E:://;
  return if $method =~ /^DESTROY/;
  die "no id\n" unless $self->{id};
  $self->{x}->$method($self->{id}, @args);
}

############################################################################

1;
