use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'WWW::Wassr',
    'VERSION_FROM' => 'lib/WWW/Wassr.pm', # finds $VERSION
    'PREREQ_PM' => {
        LWP::Simple => 0,
        Test::More => 0.32,
        Web::Scraper => 0.36,
        WWW::Mechanize => 1.72,
    },
);
