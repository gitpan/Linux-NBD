use ExtUtils::MakeMaker;

use 5.006;

WriteMakefile(
    dist	=> {
	            PREOP	=> 'pod2text Client.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
	            COMPRESS	=> 'gzip -9v',
	            SUFFIX	=> '.gz',
	           },
    EXE_FILES => [qw(bin/attach-bincue)],
    NAME => "Linux::NBD",
    VERSION_FROM => "lib/Linux/NBD.pm",
);

