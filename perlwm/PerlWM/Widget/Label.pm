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

  my($proto, %arg) = @_;
  my $class = ref $proto || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%arg);

  $self->{padding} ||= 0;
  $self->{value} ||= '';

  tie($self->{value}, 'PerlWM::Widget::Tie::Scalar', 
      $self->{value}, \&onValueChange, $self);

  $self->{gc} = $self->{x}->gc_get('widget');
  $self->{ascent} = $self->{x}->font_info('widget_font')->{font_ascent};
  $self->{descent} = $self->{x}->font_info('widget_font')->{font_descent};
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
    $self->resize() if $self->{resize};
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
  if ($args{width} eq 'auto') {
    $args{width} = $self->{x}->font_text_width('widget_font', $self->{value});
    $args{width} += (2 * $self->{padding}) if $self->{padding};
  }
  if ($args{height} eq 'auto') {
    $args{height} = $self->{ascent} + $self->{descent};
    $args{height} += (2 * $self->{padding}) if $self->{padding};
  }
  $args{background_pixel} ||= $self->{x}->color_get('widget_background');
  return $self->SUPER::create(%args);
}

############################################################################

sub resize {

  my($self) = @_;
  my $width = $self->{x}->font_text_width('widget_font', $self->{value});
  $self->ConfigureWindow(width => $width + ($self->{padding} * 2));
}

############################################################################

1;
