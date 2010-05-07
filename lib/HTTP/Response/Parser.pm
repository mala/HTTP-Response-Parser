package HTTP::Response::Parser;
use strict;
use warnings;
our $VERSION = '0.01';

use Carp;
use base qw(Exporter);
our %EXPORT_TAGS = (
    'all' => [ qw/parse parse_http_response/ ],
);
our @EXPORT_OK = @{$EXPORT_TAGS{all}};
our @EXPORT = ();

our $HEADER_CLASS = 'HTTP::Headers';
our $RESPONSE_CLASS = 'HTTP::Response';

if ($ENV{PERL_HTTP_RESPONSE_PARSER_PP}) {
    eval 'use HTTP::Response::Parser::PP;';
} else {
    eval 'use HTTP::Response::Parser::XS;';
    if ($@) {
        warn $@;
        eval 'use HTTP::Response::Parser::PP;'
    }
}

# parse($header_and_content);
# parse($header, $content);
sub parse {
    my $res = {};
    my $parsed = parse_http_response( $_[0], $res );
    if ($parsed == -1) {
        carp "invalid response";
        return;
    }
    if ($parsed == -2) {
        carp "warning: successfully parsed. but HTTP header is maybe incomplete.";
    } 
    
    if ( defined $_[1] ) {
        $res->{_content} = $_[1];
    }
    elsif($parsed > 0) {
        $res->{_content} = substr( $_[0], $parsed ) || "";
    } else { # -2
        $res->{_content} = "";
    }

    bless $res->{_headers}, $HEADER_CLASS;
    bless $res, $RESPONSE_CLASS;
    return $res;
}


1;

__END__

=head1 NAME

HTTP::Response::Parser - create HTTP::Response fast way

=head1 SYNOPSIS

  use HTTP::Response::Parser;

=head1 DESCRIPTION

HTTP::Response::Parser is

=head1 AUTHOR

mala E<lt>cpan@ma.laE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
