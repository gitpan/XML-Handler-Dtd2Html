#!/usr/bin/perl -w

use strict;

use Getopt::Std;
use IO::File;
use XML::SAX::Expat;
use XML::Handler::Dtd2Html;

my %opts;
getopts('bCfHMs:t:o:x:Z', \%opts);

my $handler = new XML::Handler::Dtd2Html();
my $parser = new XML::SAX::Expat(Handler => $handler, ParseParamEnt => 1);

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

my @examples = ();
@examples = split /\s+/, $opts{x}
		if (exists $opts{x});

if      ($opts{b}) {
	bless($doc, "XML::Handler::Dtd2Html::DocumentBook");
} elsif ($opts{f}) {
	bless($doc, "XML::Handler::Dtd2Html::DocumentFrame");
}

$doc->generateHTML($outfile, $opts{t}, $opts{s}, \@examples, !exists($opts{C}), exists($opts{H}), exists($opts{M}), exists($opts{Z}));

__END__

=head1 NAME

dtd2html - Generate a HTML documentation from a DTD

=head1 SYNOPSYS

dtd2html [B<-b> | B<-f>] [B<-C> | B<-M>] [B<-HZ>] [B<-o> I<filename>] [B<-s> I<style>] [B<-t> I<title>] [B<-x> 'I<example1.xml> I<example2.xml> ...'] I<file.xml>

=head1 OPTIONS

=over 8

=item -b

Enable the book mode generation.

=item -C

Suppress all comments.

=item -f

Enable the frame mode generation.

=item -H

Disable generation of href's in comments.

=item -M

Suppress multi comments, preserve the last.

=item -o

Specify the HTML filename to create.

=item -s

Generate an external I<style>.css file.

=item -t

Specify the title of the HTML files.

=item -x

Include a list of XML files as examples.

=item -Z

Delete zombi element (e.g. without parent).

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

This tool needs XML::SAX::Base, XML::SAX::Exception, XML::SAX::Expat and XML::Parser modules.

=head2 Comments

XML files (and DTD) can include comments. The XML syntax is :

 <!-- comments -->

All comments before a declaration are captured (except with -M option).
Each comment generates its own paragraph E<lt>pE<gt>.

=head2 Standard HTML

You can embed standard HTML tags within a comment. However, don't use tags
heading tags like E<lt>h1E<gt> or E<lt>hrE<gt>. B<dtd2html> creates an entire
structured document and these structural tags interfere with formatting of
the generated document.

So you must use entities &lt; &gt; &amp; within a comment.

=head2 dtd2html Tags

B<dtd2html> parses tags that are recognized when they are embedded
within an XML comment. These doc tags enable you to autogenerate a
complete, well-formatted document from your XML source. The tags start with
an @.

Tags must start at the beginning of a line.

The special tag @BRIEF puts doc in 'Name' section (in book mode).

The special tag @INCLUDE allows inclusion of the content of an external file.

 <!--
   comments
   @Version : 1.0
   @INCLUDE : description.txt
   @See Also : REC-xml
 -->

=head1 SEE ALSO

XML::SAX::Base , XML::SAX , XML::SAX::Expat , XML::Parser

XML::Handler::Dtd2Html

Extensible Markup Language (XML), E<lt>http://www.w3c.org/TR/REC-xmlE<gt>

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=head1 COPYRIGHT

(c) 2002 Francois PERRAD, France. All rights reserved.

This program is distributed under the Artistic License.

=cut
