use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'WWW::Wassr',
    'VERSION_FROM' => 'lib/WWW/Wassr.pm', # finds $VERSION
    'PREREQ_PM' => {
	Test::More => 0.32,
    },
);
