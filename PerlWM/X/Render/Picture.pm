#
# $Id$
#

package PerlWM::X::Render::Picture;

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

  return $self;
}

############################################################################

sub create {

  my($self, $drawable, %args) = @_;

  die "no drawable" unless $drawable;

  my $format = (delete $args{format} || 
		$self->{x}->RenderFindVisualFormat($self->{x}->{root_visual}));

  $self->{id} = $self->{x}->new_rsrc();
  $self->{x}->RenderCreatePicture($self->{id}, $drawable, $format, %args);
}

############################################################################

sub AUTOLOAD {

  my($self, @args) = @_;
  no strict 'vars';
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
