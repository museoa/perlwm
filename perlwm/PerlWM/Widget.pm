#
# $Id$
# 

package PerlWM::Widget;

############################################################################

use strict;
use warnings;

use base qw(PerlWM::X::Window);

############################################################################

sub init {
  my($class, $x) = @_;

#  $x->color_add('widget_background', 'white');
#  $x->color_add('widget_foreground', 'black');
  $x->color_add('widget_background', 'black');
  $x->color_add('widget_foreground', 'white');
  $x->font_add('widget_font', '-b&h-lucida-medium-r-normal-*-*-100-*-*-p-*-iso8859-15');
  $x->gc_add('widget', { foreground => 'widget_foreground',
			 background => 'widget_background',
			 font => 'widget_font' });
}

############################################################################

sub new {
  my($proto, @args) = @_;
  my $class = ref $proto || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(@args);
  $self->{frozen} = 0;
  return $self;
}

############################################################################

sub freeze {
  my($self) = @_;
  $self->{frozen} = 1;
}

############################################################################

sub unfreeze {
  my($self) = @_;
  if ($self->{frozen} > 1) {
    $self->redraw();
  }
  $self->{frozen} = 0;
}

############################################################################

sub redraw {
  my($self) = @_;
  $self->ClearArea(0, 0, 0, 0, 1);
}

############################################################################

1;
