use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		    => 'Finance::Bank::Cahoot',
    'VERSION_FROM'	=> 'Cahoot.pm', # finds $VERSION
    'AUTHOR'        => 'Andy Kelk <andy@mopoke.co.uk>', 
    'PREREQ_PM'		=> { WWW::Mechanize => 0 }
);
