#
# $Id$
# 

package PerlWM::X::Font;

############################################################################

use strict;
use warnings;

############################################################################

sub font_init {
  
  my($self) = @_;

  return { create => \&font_create, info => \&font_info };
}

############################################################################

sub font_create {

  my($self, $spec) = @_;
  
  my $id = $self->new_rsrc();
  $self->OpenFont($id, $spec);
  return $id;
}

############################################################################

sub font_info {
  
  my($self, $id) = @_;
  my %info = $self->QueryFont($id);
  return \%info;
}

############################################################################

1;

