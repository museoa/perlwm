#
# $Id$
# 

package PerlWM::X::Image;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::X::Image::XPM);

############################################################################

sub image_init {
  
  my($self) = @_;

  return { create => \&image_create };
}

############################################################################

sub image_create {

  my($self, $spec) = @_;

  if ($spec =~ /\.xpm$/) {
    return $self->image_xpm_load($spec);
  }
  die "unable to create image from $spec\n";
}

############################################################################

1;
