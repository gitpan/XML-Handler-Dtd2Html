
use strict;
use GD;

my $img = new GD::Image(32, 32);
my $white = $img->colorAllocate(255,255,255);
my $blue = $img->colorAllocate(0,0,255);

$img->transparent($white);

my $poly = new GD::Polygon;
$poly->addPt(10,4);
$poly->addPt(10,28);
$poly->addPt(22,16);

$img->filledPolygon($poly, $blue);

my $filename = "next.png";
open OUT, "> $filename"
		or die "can't open $filename ($!).\n";
binmode OUT, ":raw";
print OUT $img->png();
close OUT;

$img = new GD::Image(32, 32);
$white = $img->colorAllocate(255,255,255);
$blue = $img->colorAllocate(0,0,255);

$img->transparent($white);

$poly = new GD::Polygon;
$poly->addPt(22,4);
$poly->addPt(22,28);
$poly->addPt(10,16);

$img->filledPolygon($poly, $blue);

$filename = "prev.png";
open OUT, "> $filename"
		or die "can't open $filename ($!).\n";
binmode OUT, ":raw";
print OUT $img->png();
close OUT;

$img = new GD::Image(32, 32);
$white = $img->colorAllocate(255,255,255);
$blue = $img->colorAllocate(0,0,255);

$img->transparent($white);

$poly = new GD::Polygon;
$poly->addPt(4,22);
$poly->addPt(28,22);
$poly->addPt(16,10);

$img->filledPolygon($poly, $blue);

$filename = "up.png";
open OUT, "> $filename"
		or die "can't open $filename ($!).\n";
binmode OUT, ":raw";
print OUT $img->png();
close OUT;

$img = new GD::Image(32, 32);
$white = $img->colorAllocate(255,255,255);
$blue = $img->colorAllocate(0,0,255);
my $red = $img->colorAllocate(255,0,0);

$img->transparent($white);

$img->line(16, 4,28,16,$blue);
$img->line(16, 4, 4,16,$blue);
$img->line( 6,28,26,28,$blue);
$img->line( 6,28, 6,16,$blue);
$img->line(26,28,26,16,$blue);

$filename = "home.png";
open OUT, "> $filename"
		or die "can't open $filename ($!).\n";
binmode OUT, ":raw";
print OUT $img->png();
close OUT;


