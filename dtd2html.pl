#!/usr/bin/perl -w

use strict;

use Getopt::Std;
use IO::File;
use XML::Parser::PerlSAX;
use XML::Handler::Dtd2Html;

my %opts;
getopts('bCfMt:o:Z', \%opts);

my $handler = new XML::Handler::Dtd2Html();
my $parser = new XML::Parser::PerlSAX(Handler => $handler, ParseParamEnt => 1);

my $file = $ARGV[0];
die "No input file\n"
		unless (defined $file);
warn "Don't use directly a DTD file (see the embedded pod or the readme).\n"
		if ($file =~ /\.dtd$/i);
my $io = new IO::File($file,"r");
die "Can't open $file ($!)\n"
		unless (defined $io);

my $doc = $parser->parse(Source => {ByteStream => $io});

my $outfile;
if (exists $opts{o}) {
	$outfile = $opts{o};
} else {
	my $root = $doc->{root_name};
	$root =~ s/[:\.\-]/_/g;
	$outfile = "dtd_" . $root;
}

if      ($opts{b}) {
	bless($doc, "XML::Handler::Dtd2Html::DocumentBook");
} elsif ($opts{f}) {
	bless($doc, "XML::Handler::Dtd2Html::DocumentFrame");
}

$doc->generateHTML($outfile, $opts{t}, !exists($opts{C}), exists($opts{M}), exists($opts{Z}));

__END__

=head1 NAME

dtd2html - Generate a HTML documentation from a DTD

=head1 SYNOPSYS

dtd2html [B<-b> | B<-f>] [B<-C> | B<-M>] [B<-Z>] [B<-o> I<filename>] [B<-t> I<title>] I<xml_file>

=head1 OPTIONS

=over 8

=item -b

Enable the book mode generation.

=item -C

Suppress all comments.

=item -f

Enable the frame mode generation.

=item -M

Suppress multi comments, preserve the last.

=item -o

Specify the HTML filename to create.

=item -t

Specify the title of the resulting HTML file.

=item -Z

Delete zombi element (without parent).

=back

=head1 DESCRIPTION

B<dtd2html> is a front-end for XML::Handler::Dtd2Html and its subclasses. It uses them
to generate HTML documentation from DTD source.

Because it uses XML::Parser and an external DTD is not a valid XML document, the input
source must be an XML document with an internal DTD or an XML document that refers to
an external DTD.

The goal of this tool is to increase the level of documentation in DTD and to supply
a more readable format for DTD.

I<It is a tool for DTD users, not for writer.>

All comments before a declaration are captured.

All entity references inside attribute values are expanded.

This tool needs XML::Parser::PerlSAX (libxml-perl) and XML::Parser modules.

XML::Parser::PerlSAX v0.07 needs to be patched (PerlSAX.patch).

=head1 BUGS & PROBLEMS

XML names are case sensitive, when the file system isn't, there are trouble and confusion
in book mode (an example is HTML entities on Windows).

=head1 SEE ALSO

PerlSAX.pod(3), XML::Handler::Dtd2Html

 Extensible Markup Language (XML) <http://www.w3c.org/TR/REC-xml>

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=head1 COPYRIGHT

This program is distributed under the Artistic License.

=cut
