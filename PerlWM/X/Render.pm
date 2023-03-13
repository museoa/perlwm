#
# $Id$
#

package PerlWM::X::Render;

############################################################################

use strict;
use warnings;

############################################################################

my %STANDARD_FORMAT = 
  ( ARGB32 => 
    { depth => 32,
      direct => { red => 16, 
		  red_mask => 0xff, 
		  green => 8, 
		  green_mask => 0xff, 
		  blue => 0, 
		  blue_mask => 0xff, 
		  alpha => 24, 
		  alpha_mask => 0xff } },
    RGB24 =>
    { depth => 24,
      direct => { red => 16, 
		  red_mask => 0xff, 
		  green => 8, 
		  green_mask => 0xff, 
		  blue => 0, 
		  blue_mask => 0xff, 
		  alpha => 0, 
		  alpha_mask => 0x00 } },
    A8 => 
    { depth => 8,
      direct => { red_mask => 0x00, 
		  green_mask => 0x00, 
		  blue_mask => 0x00, 
		  alpha => 0, 
		  alpha_mask => 0xff } },
    A4 =>
    { depth => 4,
      direct => { red_mask => 0x00, 
		  green_mask => 0x00, 
		  blue_mask => 0x00, 
		  alpha => 0, 
		  alpha_mask => 0x0f } },
    A1 =>
    { depth => 1,
      direct => { red_mask => 0x00, 
		  green_mask => 0x00, 
		  blue_mask => 0x00, 
		  alpha => 0, 
		  alpha_mask => 0x01 } }
  );

############################################################################

sub RenderFindStandardFormat {

  my($self, $format) = @_;
  my $ext = $self->{ext}->{RENDER}->[3];
  my $cache = $ext->{standard_format}->{$format};
  return $cache if defined $cache; 
  die "unknown format '$format'" unless my $data = $STANDARD_FORMAT{$format};
  die "failed to query formats" 
    unless $ext->{picture_format} || $self->RenderQueryPictFormats();
  my @possible = grep { (($_->{type} eq 'Direct') &&
			 ($_->{depth} == $data->{depth}))
		      } @{$ext->{picture_format}};
 outer:
  foreach (@possible) {
    foreach my $attr (keys %{$data->{direct}}) {
      next outer unless $_->{direct}->{$attr} == $data->{direct}->{$attr};
    }
    $ext->{standard_format}->{$format} = $_->{id};
    return $_->{id};
  }
  warn "failed to find standard format '$format'\n";
  return;
}

############################################################################

sub RenderFindVisualFormat {
  my($self, $visual) = @_;
  my $ext = $self->{ext}->{RENDER}->[3];
  my $cache = $ext->{visual_format}->{$visual};
  return $cache if defined $cache; 
  die "failed to query formats" 
    unless $ext->{screens} || $self->RenderQueryPictFormats();
  foreach (@{$ext->{screens}}) {
    foreach (@{$_->{depth}}) {
      foreach (@{$_->{visuals}}) {
	if ($_->{visual} == $visual) {
	  $ext->{visual_format}->{$visual} = $_->{format};
	  return $_->{format};
	}
      }
    }
  }
  warn "failed to find visual format '$visual'\n";
  return;
}

############################################################################

package X11::Protocol::Ext::RENDER;

use X11::Protocol qw(make_num_hash);

my($MAJOR, $MINOR) = (0, 8);

my($Byte_Order, $Int8, $Card8, $Int16, $Card16);

if (pack("L", 1) eq "\0\0\0\1") {
  $Byte_Order = 'B';
  $Int8 = "xxxc";
  $Card8 = "xxxC";
  $Int16 = "xxs";
  $Card16 = "xxS";
}
elsif (pack("L", 1) eq "\1\0\0\0") {
  $Byte_Order = 'l';
  $Int8 = "cxxx";
  $Card8 = "Cxxx";
  $Int16 = "sxx";
  $Card16 = "Sxx";
}
else {
  die "Can't determine byte order!\n";
}

sub pack_bool {
  my($self, $value) = @_;
  $value = 0 unless defined($value);
  $value = 0 if $value eq 'False';
  $value = 1 if $value;
  return pack('L', $value);
}

sub pack_id_or_none {
  my($self, $value) = @_;
  $value = 0 unless defined($value);
  $value = 0 if $value eq 'None';
  return pack('L', $value);
}

sub pack_type {
  my($self, $value, $type) = @_;
  $value = 0 unless defined($value);
  return pack($type, $value);
}

sub pack_enum {
  my($self, $value, $type) = @_;
  $value = $self->num($type, $value);
  return pack($Card8, $value);
}

my(@CreatePictureValueMask) =
    (['repeat', \&pack_bool],
     ['fill_nearest', \&pack_bool],
     ['alpha_map', \&pack_id_or_none],
     ['alpha_x_origin', sub { pack_type($_[0], $_[1], $Int16) }],
     ['alpha_y_origin', sub { pack_type($_[0], $_[1], $Int16) }],
     ['clip_x_origin',  sub { pack_type($_[0], $_[1], $Int16) }],
     ['clip_y_origin',  sub { pack_type($_[0], $_[1], $Int16) }],
     ['clip_mask', \&pack_id_or_none],
     ['graphics_exposures', \&pack_bool],
     ['subwindow_mode', sub { pack_enum($_[0], $_[1], 'GCSubwindowMode') }],
     ['poly_edge', sub { pack_type($_[0], $_[1], 'PolyEdge') }],
     ['poly_mode', sub { pack_type($_[0], $_[1], 'PolyMode') }],
     ['dither', \&pack_id_or_none],
     ['component_alpha', \&pack_bool]);

sub new {

  my($pkg, $x, $request_num, $event_num, $error_num) = @_;
  my($self) = {};

  # constants
  foreach ([PictType => [qw(Indexed Direct)]],
	   [PictOp => [qw(Clear Src Dst Over OverReverse In InReverse
			  Out OutReverse Atop AtopReverse Xor Add Saturate
			  DisjointClear DisjointSrc DisjointDst DisjointOver
			  DisjointOverReverse DisjointIn DisjointInReverse
			  DisjointOut DisjointOutReverse DisjointAtop
			  DisjointAtopReverse DisjointXor
			  ConjointClear ConjointSrc ConjointDst ConjointOver
			  ConjointOverReverse ConjointIn ConjointInReverse
			  ConjointOut ConjointOutReverse ConjointAtop
			  ConjointAtopReverse ConjointXor)]],
	   [SubPixel => [qw(Unknown HorizontalRGB HorizontalBGR
			    VerticalRGB VerticalBGR None)]],
	   [PolyEdge => [qw(Sharp Smooth)]],
	   [PolyMode => [qw(Precise Imprecise)]]) {
    my($type, $values) = @{$_};
    $x->{ext_const}->{$type} = $values;
    $x->{ext_const_num}->{$type} = { make_num_hash($values) };
  }
  
  # requests
  $x->{ext_request}{$request_num} = 
    [
     ["RenderQueryVersion",
      sub {
	return pack("LL", $MAJOR, $MINOR);
      }, 
      sub {
	my($self, $data) = @_;
	return unpack("xxxxxxxxLL", $data);
      }
     ],
     ["RenderQueryPictFormats", 
      sub {
	return "";
      },
      sub {
	my($self, $data) = @_;
	my($numFormats, $numScreens, $totalDepths, $totalVisuals, $subPixel)
	  = unpack("xxxxxxxxLLLLL", substr($data, 0, 32));
	my $ext = $self->{ext}->{RENDER}->[3];
	$subPixel = 0 if $ext->{version} lt 'v0.6';
	$data = substr($data, 32);
	my(@format, @screen);
	for (0..$numFormats - 1) {
	  my $format = { direct => {} };
	  (@{$format}{qw(id type depth)},
	   @{$format->{direct}}{qw(red red_mask 
				   green green_mask
				   blue blue_mask
				   alpha alpha_mask)},
	   $format->{colormap}) = unpack('LCCxxSSSSSSSSL', 
					 substr($data, $_ * 28, 28));
	  $format->{type} = $self->interp('PictType', $format->{type});
	  delete $format->{direct} unless $format->{type} eq 'Direct';
	  push @format, $format;
	}
	$data = substr($data, 28 * $numFormats);
	for (0..$numScreens - 1) {
	  my $screen = { };
	  my($numDepths, $fallback) = unpack('LL', substr($data, 0, 8));
	  $screen->{fallback} = $fallback;
	  push @screen, $screen;
	  $data = substr($data, 8);
	  for (0..$numDepths - 1) {
	    my($depth, $numVisuals) = unpack('CxSxxxx', substr($data, 0, 8));
	    my(@list) = unpack('L*', substr($data, 8, $numVisuals * 8));
	    my @visual;
	    for (my $i = 0; $i < @list; $i += 2) {
	      push @visual, { visual => $list[$i], format => $list[$i + 1] };
	    }
	    push @{$screen->{depth}}, { depth => $depth, 
					visuals => \@visual };
	    $data = substr($data, 8 + ($numVisuals * 8));
	  }
	}
	if ($subPixel) {
	  warn "subPixel != numScreens" unless $subPixel == $numScreens;
	  foreach (0..$subPixel - 1) {
	    $screen[$_]->{sub_pixel} = 
	      $self->interp('SubPixel', unpack('L', substr($data, 4 * $_)));
	  }
	}
	$ext->{picture_format} = \@format;
	$ext->{screens} = \@screen;
	return (\@format, \@screen);
      }
     ],
     ["RenderQueryPictIndexValues",
      sub {
	my($self, $pictFormat) = @_;
	return pack('L', $pictFormat);
      },
      sub {
	my($self, $data) = @_;
	my($count) = unpack("xxxxxxxxS", substr($data, 0, 32));
	my(@result);
	for (0..$count - 1) {
	  @{$result[$_]}{qw(pixel red green blue alpha)}
	    = unpack('LSSSS', substr($data, 32 + ($_ * 12), 12));
	}
	return @result;
      }
     ],
     ["RenderQueryDithers"],	
     ["RenderCreatePicture",
      sub {
	my($self, $pid, $drawable, $format, %values) = @_;
	$format = $self->RenderFindStandardFormat($format) 
	  if $format !~ /^\d+$/;
	my $mask = 0;
	my $cp = \@CreatePictureValueMask;
	my $payload = '';
	for (0 .. $#{$cp}) {
	  if (exists($values{$cp->[$_]->[0]})) {
	    $mask |= (1 << $_);
	    $payload .= $cp->[$_]->[1]->($self, $values{$cp->[$_]->[0]});
	    delete $values{$cp->[$_]->[0]};
	  }
	}
	warn "Invalid arguments: ", join(",", keys %values), "\n" if %values;
	return pack('LLLL', $pid, $drawable, $format, $mask).$payload;
      },
     ],
     ["RenderChangePicture", sub { die "TODO" }],
     ["RenderSetPictureClipRectangles", 
      sub {  
	my($self, $picture, $cx, $cy, @rects) = @_;
	my $result = pack('Lss', $picture, $cx, $cy);
	$result .= pack('ssss', @{$_}) for @rects;
	return $result;
      }
     ],
     ["RenderFreePicture", sub { die "TODO" }],
     ["RenderComposite", 
      sub { 
	my($self, $op, $src, $mask, $dst, 
	   $sx, $sy, $mx, $my, $dx, $dy, $w, $h) = @_;
	$mask = 0 if $mask eq 'None';
	return pack_enum($self, $op, 'PictOp').
	  pack("LLLssssssSS", $src, $mask, $dst, 
	       $sx, $sy, $mx, $my, $dx, $dy, $w, $h);
      }
     ],
     ["RenderScale", sub { die "TODO" }],
     ["RenderTrapezoids", sub { die "TODO" }],
     ["RenderTriangles", sub { die "TODO" }],
     ["RenderTriStrip", sub { die "TODO" }],
     ["RenderTriFan", sub { die "TODO" }],
     ["RenderColorTrapezoids", sub { die "TODO" }],
     ["RenderColorTriangles", sub { die "TODO" }],
     ["RenderTransform", sub { die "TODO" }], 
     ["RenderCreateGlyphSet", sub { die "TODO" }],
     ["RenderReferenceGlyphSet", sub { die "TODO" }],
     ["RenderFreeGlyphSet", sub { die "TODO" }],
     ["RenderAddGlyphs", sub { die "TODO" }],
     ["RenderAddGlyphsFromPicture", sub { die "TODO" }],
     ["RenderFreeGlyphs", sub { die "TODO" }],
     ["RenderCompositeGlyphs", sub { die "TODO" }],
     ["RenderCompositeGlyphs", sub { die "TODO" }],
     ["RenderCompositeGlyphs", sub { die "TODO" }],
     ["RenderFillRectangles", sub { die "TODO" }],
     ["RenderCreateCursor", sub { die "TODO" }],
     ["RenderSetPictureTransform", 
      sub { 
	my($self, $picture, $transform) = @_;
	my $result = pack('L', $picture);
	for my $row (0..2) {
	  for my $col (0..2) {
	    $result .= pack('l', int($transform->[$row]->[$col] * 65536));
	  }
	}
	return $result;
      }
     ],
     ["RenderQueryFilters", 
      sub {
	warn "@_\n";
	my($self, $drawable) = @_;
	return pack('L', $drawable);
      },
      sub {
	my($self, $data) = @_;
	my($numAliases, $numFilters) = 
	  unpack('xxxxxxxxLL', substr($data, 0, 32));
	my @alias = unpack('s*', substr($data, 32, 2 * $numAliases));
	$data = substr($data, (32 + (2 * $numAliases) + 
			       (($numAliases % 2) * 2)));
	my @filters;
	for (0..$numFilters - 1) {
	  my $len = unpack('C', $data);
	  push @filters, substr($data, 1, $len);
	  $data = substr($data, $len + 1);
	}
	return (\@alias, \@filters);
      }
     ],
     ["RenderSetPictureFilter", 
      sub { 
	my($self, $picture, $filter, @values) = @_;
	my $result = pack('LSxx', $picture, length($filter));
	$result .= $filter;
	$result .= pack('l*', map $_ * 65536, @values);
	return $result;
      }
     ],
     ["RenderCreateAnimCursor", sub { die "TODO" }],
    ];
    
  for my $i (0..$#{$x->{ext_request}->{$request_num}}) {
    $x->{ext_request_num}->{$x->{ext_request}->{$request_num}->[$i]->[0]} =
      [$request_num, $i];
  }
  @{$self}{qw(major minor)} = $x->req('RenderQueryVersion');
  $self->{version} = "v$self->{major}.$self->{minor}";
     
  die "Wrong RENDER version ($self->{major} != $MAJOR)\n" 
    unless $self->{major} == $MAJOR;
  return bless $self, $pkg;
}

############################################################################

1;
