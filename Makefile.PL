use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'XML::Handler::Dtd2Html',
    'VERSION_FROM'  => 'Dtd2Html.pm', # finds $VERSION
    'ABSTRACT'      => 'HTML documentation generator from a DTD',
    'PREREQ_PM'     => {
                        'XML::Parser'           => 0,
                        'XML::Parser::PerlSAX'  => 0.07
    },
    'PM'            => {
                        'Dtd2Html.pm'   => '$(INST_LIBDIR)/Dtd2Html.pm',
    },
    'EXE_FILES'     => ['dtd2html'],
    'AUTHOR'        => "Francois PERRAD (perrad\@besancon.sema.slb.com)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);
