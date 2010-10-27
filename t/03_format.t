#!perl -w
use strict;
use Test::More;

use HTTP::Response;
use HTTP::Headers;
use HTTP::Response::Parser qw(parse_http_response);
use Data::Dumper;

my $hrp = HTTP::Response::Parser->new();

my %formats = (
    HTTP::Response::Parser::FORMAT_NONE()      => "NONE",
    HTTP::Response::Parser::FORMAT_HASHREF()   => "HASH",
    HTTP::Response::Parser::FORMAT_ARRAYREF()  => "ARRAY",
);

my $tests = <<'__HEADERS';
HTTP/1.0 200 OK

----------
{ ret => [17,"0","200","OK"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {}, HEADER_AS_ARRAY => [] }
----------
HTTP/1.0 200 OK
Content-Type: text/html

hogehoge
----------
{ ret => [41,"0","200","OK"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {"content-type" => "text/html"}, HEADER_AS_ARRAY => ["content-type","text/html"] }
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
X-Test: 2

hogehoge
----------
{ ret => [61,"0","200","OK"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {"content-type" => "text/html","x-test" => ["1","2"]}, HEADER_AS_ARRAY => ["content-type","text/html","x-test","1","x-test","2"] }
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
 X-Test: 2

hogehoge
----------
{ ret => [62,"0","200","OK"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {"content-type" => "text/html","x-test" => "1\n X-Test: 2"}, HEADER_AS_ARRAY => ["content-type","text/html","x-test","1\n X-Test: 2"] }
----------
HTTP/1.0 200 OK
Content-Type: text/html

----------
{ ret => [41,"0","200","OK"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {"content-type" => "text/html"}, HEADER_AS_ARRAY => ["content-type","text/html"] }
----------
HTTP/1.1 200 OK
Content-Type: text/html

----------
{ ret => [41,"1","200","OK"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {"content-type" => "text/html"}, HEADER_AS_ARRAY => ["content-type","text/html"] }
----------
HTTP/1.1 404 Not Found
Content-Type: text/html

----------
{ ret => [48,"1","404","Not Found"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {"content-type" => "text/html"}, HEADER_AS_ARRAY => ["content-type","text/html"] }
----------
HTTP/1.1 200 OK
Content-Type: text/html
FOO_BAR: BAZ

----------
{ ret => [54,"1","200","OK"], HEADER_AS_NONE => undef, HEADER_AS_HASH => {"content-type" => "text/html","foo-bar" => "BAZ"}, HEADER_AS_ARRAY => ["content-type","text/html","foo-bar","BAZ"] }
__HEADERS

my @tests = split '-'x10, $tests;
my $i = 0;

while (@tests) {
    $i++;
    my $header = shift @tests;
    my $expect = shift @tests;
    $header =~ s/^\n//;
    last unless $expect;

    my $r   = eval($expect);

    for my $format (0..2) {
        my @a = parse_http_response($header, $format);
        my $headers = pop @a;

        is_deeply( \@a, $r->{ret}, 'test-' . $i) or diag(explain(\@a));
        is_deeply(
            $headers,
            $r->{ "HEADER_AS_". $formats{$format} }, 
            'test-format'.$i
        ) or diag(explain($headers))
    }

}

done_testing;
