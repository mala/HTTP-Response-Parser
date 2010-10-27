package HTTP::Response::Parser;
use 5.008;
use strict;
use warnings;
our $VERSION = '0.01';

use base qw(Exporter);

our %EXPORT_TAGS = (
    'all' => [ qw/parse_http_response/ ],
);
our @EXPORT_OK = @{$EXPORT_TAGS{all}};
our @EXPORT = ();

our $HEADER_CLASS   = 'HTTP::Headers';
our $RESPONSE_CLASS = 'HTTP::Response';

our $BACKEND;
if (not exists $INC{"HTTP/Response/Parser/PP.pm"}) {
    $BACKEND = $ENV{PERL_HTTP_RESPONSE_PARSER} || ($ENV{PERL_ONLY} ? 'pp' : '');
    if ($BACKEND !~ /\b pp \b/xms) {
        eval {
            require XSLoader;
            XSLoader::load(__PACKAGE__, $VERSION);
            $BACKEND = 'xs';
        };
        die $@ if $@ && $BACKEND =~ /\bxs\b/;
    }
    if (not __PACKAGE__->can('parse_http_response')) {
        require HTTP::Response::Parser::PP;
    }
}

sub new {
    my $class = shift;
    my %args  = @_ == 1 ? %{$_[0]} : @_;
    $args{header_class}   ||= $HEADER_CLASS;
    $args{response_class} ||= $RESPONSE_CLASS;
    return bless \%args, $class;
}

sub errstr  { $_[0]->{errstr}  }
sub errocde { $_[0]->{errcode} }

1;

__END__

=head1 NAME

HTTP::Response::Parser - create HTTP::Response object fast way

=head1 SYNOPSIS

  use HTTP::Response::Parser qw(parse parse_http_response);
  
  $res = HTTP::Response::Parser::parse("HTTP/1.1 200 OK\r\n\r\n", "Content body");
   or
  $res = HTTP::Response::Parser::parse("HTTP/1.1 200 OK\r\n\r\nContent Body");
  if ($res) {
      $res->isa('HTTP::Response'); # true
      $res->{_headers}->isa('HTTP::Headers'); # true
  } else {
      # something wrong
  }
  
  # parse header only, return parsed bytes length.
  $res = {};
  $parsed = parse_http_response("HTTP/1.1 200 OK\r\n\r\nContent", $res); # return n bytes

  if ($parsed == -1) {
      # invalid response, maybe this is not HTTP Response
  } elsif ($parsed == -2) {
      # parsed correctly, but incomplete response. 
  } else {
      $parsed; # length of "HTTP/1.1 200 OK\r\n\r\n"
      $res->{_rc}; # 200
      $res->{_protocol}; # HTTP/1.1
      $res->{_msg}; # OK
      $res->{_headers}; # just a HASH
      $res->isa('HTTP::Response'); # false
  }


=head1 DESCRIPTION

This is a fast HTTP response parser. Create L<HTTP::Response> object same as HTTP::Response->parse.

XS parser is 10x faster than HTTP::Response, so that's useful for high performance crawler or HTTP-based RPC.

If you want incremental parser, you can use L<HTTP::Parser>. And see also L<HTTP::Parser::XS>, if you want faster request parser.

This module is using picohttpparser(http://github.com/kazuho/picohttpparser) by kazuho oku.

=head1 GLOBAL VARIABLES

=over 4

=item $HTTP::Response::Parser::RESPONSE_CLASS

The class of response object. (Default is 'HTTP::Response')

If set empty string then parse() function return a HASH that not blessed.

=item $HTTP::Response::Parser::HEADER_CLASS

The class of $res->{_headers}. (Default is 'HTTP::Headers')

=head1 BENCHMARK

Compare with HTTP::Response->parse.

 parse small_header
 Benchmark: timing 20000 iterations of parse, xs...
 parse: 11 wallclock secs ( 5.05 usr +  0.01 sys =  5.06 CPU) @ 3952.57/s (n=20000)
 xs:  2 wallclock secs ( 0.63 usr +  0.00 sys =  0.63 CPU) @ 31746.03/s (n=20000)

 parse large_header
 Benchmark: timing 20000 iterations of parse, xs...
 parse: 26 wallclock secs (15.33 usr +  0.10 sys = 15.43 CPU) @ 1296.18/s (n=20000)
 xs:  2 wallclock secs ( 1.22 usr +  0.00 sys =  1.22 CPU) @ 16393.44/s (n=20000)


=head1 EXPORTS

Nothing by default. You can import "parse", "parse_http_response", and ":all".

=head1 AUTHOR

mala E<lt>cpan@ma.laE<gt>

=head1 THANKS TO

kazuho oku, tokuhirom

=head1 SEE ALSO

L<HTTP::Response>, L<HTTP::Parser>, L<HTTP::Parser::XS>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
