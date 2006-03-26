use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Text::CSV::Separator',
    VERSION_FROM      => 'lib/Text/CSV/Separator.pm',
    PREREQ_PM         => {},
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'lib/Text/CSV/Separator.pm', 
       AUTHOR         => 'Enrique Nell <enell@cpan.org>') : ()),
);
