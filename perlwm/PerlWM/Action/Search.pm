#
# $Id$
#

package PerlWM::Action::Search;

############################################################################

use strict;
use warnings;
use base qw(PerlWM::Action);

############################################################################

sub start {

  my($target, $event) = @_;
  my $self = __PACKAGE__->SUPER::new(target => $target,
				     event => $event,
				     grab => 'keyboard');

  $self->{text} = '';
  $self->{select} = 0;
  $self->{case_insensitive} = 1;
  $self->{frames} = $target->{perlwm}->{frames};
  $self->{match} = [@{$self->{frames}}];

  $self->{popup} = PerlWM::Action::Search::Popup->new(x => $target->{x});

  $self->{popup}->clear();
  $self->{popup}->MapWindow();
  return $self;
}

############################################################################

sub finish {

  my($self) = @_;
  $self->{popup}->UnmapWindow();
  $self->{popup}->DestroyWindow();
  $self->SUPER::finish();
}

############################################################################

sub show {

  my($self) = @_;
  # TODO: display this information in the popup
  return;
  print "search: $self->{text}\n";
  print "error: $self->{error}\n" if $self->{error};
  for (my $index = 0; $index <= $#{$self->{match}}; $index++) { 
    if ($index == $self->{select}) {
      print ">> $self->{match}->[$index]->{name} <<\n";
    }
    else {
      print "   $self->{match}->[$index]->{name}\n";
    }
  }
}

############################################################################

sub search {

  my($self) = @_;
  my $regexp = ($self->{case_insensitive} 
		? eval { qr/$self->{text}/i }
		: eval { qr/$self->{text}/ });
  unless ($self->{error} = $@) {
    $self->{match} = [ grep $_->{name} =~ $regexp, @{$self->{frames}} ];
    my $max = $#{$self->{match}};
    $self->{select} = $max if $self->{select} > $max;
    $self->{select} = 0 if $max == -1;
  }
  $self->show();
}

############################################################################

sub key {

  my($self, $event) = @_;
  my $string = $event->{string};
  # ignore special keys
  return unless $string && (length($string) eq 1);
  $self->{text} .= $event->{string};
  $self->search();
}

############################################################################

sub backspace {

  my($self, $event) = @_;
  return unless length($self->{text});
  $self->{text} = substr($self->{text}, 0, length($self->{text}) - 1);
  $self->search();
}

############################################################################

sub up_down {

  my($self, $event) = @_;
  if ($event->{string} eq 'Up') {
    $self->{select}--;
  }
  elsif ($event->{string} eq 'Down') {
    $self->{select}++;
  }
  my $max = $#{$self->{match}};
  $self->{select} = $max if $self->{select} < 0;
  $self->{select} = 0 if $self->{select} > $max;
  $self->show();
}

############################################################################

sub toggle_case {

  my($self) = @_;
  $self->{case_insensitive} = !$self->{case_insensitive};
  $self->search();
}

############################################################################

sub enter {

  my($self) = @_;
  if (my $select = $self->{match}->[$self->{select}]) {
    $select->ConfigureWindow(stack_mode => 'Above');
    $select->warp_to([-10, 10]);
  }
  $self->finish();
}

############################################################################

sub OVERLAY { ( __PACKAGE__->SUPER::OVERLAY,
		
		'Key(Any)' => 'key',
		'Key(Backspace)' => 'backspace',
		'Key(Up)' => 'up_down',
		'Key(Down)' => 'up_down',
		'Key(Control i)' => 'toggle_case',
		'Key(Enter)' => 'enter') }

############################################################################

package PerlWM::Action::Search::Popup;

use strict;
use warnings;
use base qw(PerlWM::X::Window);

############################################################################

sub new {

  my($proto, %arg) = @_;
  my $class = ref $proto || $proto || __PACKAGE__;
  my $self = $class->SUPER::new(%arg);

  $self->create(x => 2, y => 2,
		width => 25, height => 10,
		border_width => 2,
		background_pixel => $self->{x}->{black_pixel},
		border_pixel => $self->{x}->object_get('color',
						       '#00ff00',
						       '#00ff00'));

  $self->{gc} = $self->{x}->gc_get('widget');
  $self->{ascent} = $self->{x}->font_info('widget_font')->{font_ascent};
  $self->{descent} = $self->{x}->font_info('widget_font')->{font_descent};
  $self->{font} = $self->{x}->font_get('widget_font');


  return $self;
}

############################################################################

sub clear {

}

############################################################################

sub expose {

  

}

############################################################################

sub EVENT { (__PACKAGE__->SUPER::EVENT,
	     'Expose' => 'expose') }

############################################################################

1;
