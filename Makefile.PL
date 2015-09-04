use inc::Module::Install;
use Module::Install::XSUtil 0.45;
name 'HTTP-Response-Parser';
all_from 'lib/HTTP/Response/Parser.pm';

cc_warnings;
use_xshelper;

test_requires 'Test::More' => 0.96;
test_requires 'HTTP::Response';

makemaker_args(
    clean => {
        FILES => q{
            *.stackdump
            *.gcov *.gcda *.gcno
            *.out
            nytprof
            cover_db
        },
    },
);

tests 't/*.t';
# author_tests 'xt';

repository 'git://github.com/mala/HTTP-Response-Parser.git';

WriteAll;
