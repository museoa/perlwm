#
# $Id$
# 

package PerlWM::X::Window;

############################################################################

use strict;
use warnings;

use PerlWM::X::Property;

############################################################################

sub new {

  my($proto, %args) = @_;
  my $class = ref($proto) || $proto || __PACKAGE__;
  my $self = { %args };
  bless $self, $class;

  die "no x" unless $self->{x};
  die "invalid x" unless $self->{x}->isa('PerlWM::X');

  $self->attach() if $self->{id};

  return $self;
}

############################################################################

sub attach {
  my($self) = @_;
  $self->{x}->window_attach($self);
  unless ($self->{no_props}) {
    tie my %prop, 'PerlWM::X::Property', $self;
    $self->{prop} = \%prop;
  }
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

  $args[0] = $args[0]->{id} if ref $args[0];

  $args{bit_gravity} ||= 'Static'; 

  $self->{id} = $self->{x}->new_rsrc();
  $self->CreateWindow(@args, %args);
  $self->attach();
}

############################################################################

sub event_add {

  my($self, $event, $handler) = @_;
  $self->{x}->event_add_window($self, $event, $handler);
}

############################################################################

sub EVENT {
  return ();
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
  die "uh-oh ($self->$method())\n" unless ref $self;
  die "no id ($method)\n" unless $self->{id};
  $self->{x}->$method($self->{id}, @args);
}

############################################################################

1;
