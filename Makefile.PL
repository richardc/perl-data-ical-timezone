use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'         => 'Data::ICal::TimeZone',
    'VERSION_FROM' => 'lib/File/Find/Rule.pm',
    'PREREQ_PM' => {
        'Class::Accessor'    => 0,
        'Class::Singleton'   => 0,
        'Data::ICal'         => 0,
        'UNIVERSAL::require' => 0,

    },
);

