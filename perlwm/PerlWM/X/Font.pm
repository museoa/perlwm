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

  # TODO: come up with a better (generic) error handling strategy
  my($id, %info) = $self->new_rsrc();
  local $self->{die_on_error} = 1;
  foreach ($spec, 'fixed') {
    eval { 
      $self->OpenFont($id, $_); 
      %info = $self->QueryFont($id);
    };
    if ($@ && ($@ =~ /^OpenFont/)) {
      eval { $self->handle_input(); };
      die unless $@ && $@ =~ /^QueryFont/;
    }
    last unless $@;
  }
  return ($id, \%info);
}

############################################################################

sub font_info {
  
  my($self, $id) = @_;
  my %info = $self->QueryFont($id);
  return \%info;
}

############################################################################

1;

