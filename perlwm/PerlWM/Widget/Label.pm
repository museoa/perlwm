#
# $Id$
# 

package PerlWM::Widget::Label;

############################################################################

use strict;
use warnings;

use base qw(PerlWM::Widget);

use PerlWM::Widget::Tie;

############################################################################

sub EVENT {
  (__PACKAGE__->SUPER::EVENT(),
   'Expose' => 'onExpose');
}

############################################################################

sub new {
  my($proto, @args) = @_;
  my $class = ref $proto || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(@args);

  tie($self->{value}, 'PerlWM::Widget::Tie::Scalar', 
      $self->{value}, \&onValueChange, $self);

  $self->{gc} = $self->{x}->gc_get('widget');
  $self->{ascent} = $self->{x}->font_info('widget_font')->{font_ascent};
  $self->{font} = $self->{x}->font_get('widget_font');

  return $self;
}

############################################################################

sub onValueChange {
  my($self, $value) = @_;
  if ($self->{frozen}) {
    $self->{frozen}++;
  }
  else {
    $self->ClearArea(0, 0, 0, 0);
    $self->draw($value);
  }
}

############################################################################

sub draw {
  my($self, $value) = @_;
  $self->PolyText8($self->{gc},
		   $self->{padding}, $self->{padding} + $self->{ascent},
		   $self->{font}, [0, $value]);
}

############################################################################

sub onExpose { 
  my($self, $event) = @_;
  $self->draw($self->{value});
}

############################################################################

sub create {
  my($self, %args) = @_;
  $args{background_pixel} ||= $self->{x}->color_get('widget_background');
  return $self->SUPER::create(%args);
}

############################################################################

1;
