use Test::More;
use HTTP::Response;
use HTTP::Response::Parser::PP ();
use HTTP::Response::Parser qw(parse);

use Data::Dumper;
my @tests = split '-'x10, <<'__END__';
HTTP/1.0 200 OK

----------
{
 '_content' => '',
 '_protocol' => 'HTTP/1.0',
 '_headers' => {},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html

hogehoge
----------
{
 '_content' => "hogehoge\n",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html"},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
X-Test: 2

hogehoge
----------
{
 '_content' => "hogehoge\n",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html", "x-test" => [1,2]},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
 X-Test: 2

hogehoge
----------
{
 '_content' => "hogehoge\n",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html", "x-test" => "1\n X-Test: 2"},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html
----------
{
 '_content' => "",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html"},
 '_rc' => 200,
 '_msg' => 'OK'
}



__END__

while (@tests) {
    my $header = shift @tests;
    my $expect = shift @tests;
    $header =~s/^\n//;
    last unless $expect;
    my $res = parse($header);
    my $r = eval($expect);
    is_deeply($res, $r);
    isa_ok($res, 'HTTP::Response');
    isa_ok($res->{_headers}, 'HTTP::Headers');
}

done_testing;
