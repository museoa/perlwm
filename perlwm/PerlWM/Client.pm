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

  # we want some events, but never any input ones - we also
  # set the do not propogate mask for simple clients
  my $mask = $self->event_mask();
  my $input = $self->{x}->pack_event_mask(qw(KeyPress KeyRelease
					     ButtonPress ButtonRelease),
					  map "Button${_}Motion", (1..5));
  $self->{event_mask} = ($mask & (~$input));
  $self->ChangeWindowAttributes(id => $self->{id},
				do_not_propogate_mask => $input,
				event_mask => $self->{event_mask});

  return $self;
}

############################################################################


sub EVENT { ( # TODO: can we do this with an overlay?
	     'Property(WM_NAME)' => sub { $_[0]->{frame}->prop_wm_name($_[1]) },
	     'Property(WM_ICON_NAME)' => sub { $_[0]->{frame}->prop_wm_icon_name($_[1]) },
	     ) }


############################################################################

1;
