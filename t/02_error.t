use strict;
use Test::More;

use HTTP::Response;
use HTTP::Response::Parser qw(parse_http_response);
use Data::Dumper;

my $tests = <<'__HEADERS';
HOGE

----------
-1
----------
HTTP/1.0 200 OK
----------
-2
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
X-Test: 2

hogehoge
----------
61
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
 X-Test: 2

hogehoge
----------
62
----------
HTTP/1.0 200 OK
Content-Type: text/html
----------
-2
__HEADERS



my @tests = split '-'x10, $tests;
my $i = 0;
while (@tests) {
    $i++;
    my $header = shift @tests;
    my $expect = shift @tests;
    $header =~ s/^\n//;
    last unless $expect;
    my $res  = [];
    my($ret) = parse_http_response($header, 0, $res);
    my $r    = eval($expect);
    is( $ret, $r, "test-$i");
}

done_testing;
