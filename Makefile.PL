use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'XML::Handler::Dtd2Html',
    'VERSION_FROM'  => 'Dtd2Html.pm', # finds $VERSION
    'ABSTRACT'      => 'HTML documentation generator from a DTD',
    'PREREQ_PM'     => {
                        'XML::Parser'           => 0,
                        'XML::SAX::Expat'       => 0.36
    },
    'PM'            => {
                        'Dtd2Html.pm'   => '$(INST_LIBDIR)/Dtd2Html.pm',
    },
    'EXE_FILES'     => ['dtd2html.pl'],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);
