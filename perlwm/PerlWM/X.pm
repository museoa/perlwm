#
# $Id$
#

package PerlWM::X;

############################################################################

=pod

Notes
=====

 obj => a x server object like - color (pixel), font, gc, or image. 

 name => a re-usable name for a object - like 'title'
         (the same name can be used for multiple types of resource
          so 'title' could refer to a font, a color and a gc)

 spec => the specification of the object - like 'red' or 'lucida'

 id   => the x resource id

 info => information about object - like font metrics, or image sizes

=cut

############################################################################

use strict;
use warnings;
use base qw(X11::Protocol
	    PerlWM::X::Event
	    PerlWM::X::Object
	    PerlWM::X::Color 
	    PerlWM::X::Image 
	    PerlWM::X::Font 
	    PerlWM::X::GC);

use PerlWM::X::Window;

############################################################################

sub new {

  my($proto, @args) = @_;
  my $class = ref $proto || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(@args);

  $self->{error_handler} = \&error_handler;

  $self->object_init();
  $self->event_init();


  return $self;
}

############################################################################

sub pack_mods {

  my($self, @mods) = @_;
  if (!$#mods) {
    if ($mods[0] eq 'None') {
      return 0;
    }
    elsif ($mods[0] eq 'Any') {
      return 0x8000;
    }
  }
  my($result) = 0;
  foreach my $m (@mods) {
    $result |= 1 << $self->num('KeyMask', $m);
  }
  return $result;
}

############################################################################

sub unpack_mods {

  my($self, $value) = @_;
  my(@result);
  my($bit) = 0;
  while ($value) {
    if ($value & 1) {
      push @result, $self->interp('KeyMask', $bit);
    }
    $value >>= 1;
    $bit++;
  }
  return @result;
}

############################################################################

sub error_handler { 

  my($self, $data) = @_;
  my($type, $seq, $info, $minor_op, $major_op) = unpack("xCSLSCxxxxxxxxxxxxxxxxxxxxx", $data);
  my($t);
  $t = join("", "Protocol error: $type (",
	    $self->do_interp('Error', $type), "); ",
	    "Sequence Number $seq\n",
	    " Opcode ($major_op, $minor_op) = ",
	    ($self->do_interp('Request', $major_op)
	     or $self->{'ext_request'}{$major_op}[$minor_op][0]), "\n");
  if ($type == 2) {
    $t .= " Bad value $info (" . X11::Protocol::hexi($info) . ")\n";
  }
  elsif ($self->{'error_type'}[$type] & 1) {
    $t .= " Bad resource $info (" . X11::Protocol::hexi($info) . ")\n";
  }
  print STDERR $t;

}

############################################################################

sub window_attach {

  my($self, $window) = @_;

  $self->{window}->{$window->{id}} = $window;
  $self->event_window_hook($window);
}

############################################################################

sub alien {

  my($self, $id) = @_;
  $id &= (-1 ^ $self->{resource_id_mask});
  return ($id != $self->{resource_id_base});
}

############################################################################

sub dumper {

  my($self, @args) = @_;
  require Data::Dumper;
  my $dd = Data::Dumper->new([@args]);
  $dd->Indent(1);
  $dd->Seen({x => $self});
  print $dd->Dump();
}

############################################################################

1;
