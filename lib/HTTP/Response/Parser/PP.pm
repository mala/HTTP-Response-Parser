package HTTP::Response::Parser::PP;

use strict;
use warnings;

{
    no warnings 'once', 'redefine';
    *HTTP::Response::Parser::parse               = \&parse;
    *HTTP::Response::Parser::parse_http_response = \&parse_http_response;
}

sub parse {
    my($self, $header, $content) = @_;
    die 'TODO';
}

sub parse_http_response {
    my ($str, $last_len, $res, $option) = @_;
    return -2 unless $str;

    my $len = length $str;
    
    my ($sl, $remain) = split /\r?\n/, $_[0], 2;
    my ($proto, $rc, $msg) = split(' ', $sl, 3);
    return -1 unless $proto =~m{^HTTP/1.(\d)};
    my $minor_version = $1;
    return -1 unless $rc =~m/^\d+$/;
    
    ($res->{'_protocol'}, $res->{'_rc'}, $res->{'_msg'}) = ($proto, $rc, $msg);

    my ($headers, $content) = split /\r?\n\r?\n/, $remain, 2;
    $res->{_headers} = _parse_header_field($headers);

    return -2 unless ($remain =~/\r?\n\r?\n/ || $content);
    my $parsed = $len - (defined $content ? length $content : 0);

    return $option ? ($parsed, $minor_version, $rc, $msg) : $parsed;
}

# parse "Field: value\r\n"
sub _parse_header_field {
    my($str) = @_;
    return +{} unless defined $str;
    
    my ( %self, $field, $value, $f );
    for ( split /\r?\n/, $str ) {
        if ( defined $field ) {
            if ( ord == 9 || ord == 32 ) {
                $value .= "\n$_";
                next;
            }
            $f = lc($field); $f =~ tr/_/-/;
            if ( defined $self{$f} ) {
                my $h = $self{$f};
                ref($h) eq 'ARRAY'
                  ? push( @$h, $value )
                  : ( $self{$f} = [ $h, $value ] );
            }
            else { $self{$f} = $value }
        }
        ( $field, $value ) = split /[ \t]*: ?/, $_, 2;
    }
    if ( defined $field ) {
        $f = lc($field); $f =~ tr/_/-/;
        if ( defined $self{$f} ) {
            my $h = $self{$f};
            ref($h) eq 'ARRAY'
              ? push( @$h, $value )
              : ( $self{$f} = [ $h, $value ] );
        }
        else { $self{$f} = $value }
    }
    bless \%self;
}

# header parser
sub incr_parser {
    my $res = shift;
    $res->{_content} = "";
    my %head;
    my $status_line;
    my $last_line = "";

    return sub {
        my $str = $_[0];
        my $l   = length $str;
        $str =~ s/\r?\n$//;
        unless ($status_line) {
            $status_line = 1;
            ( $res->{_protocol}, $res->{_rc}, $res->{_msg} ) = split ' ', $str;
            return $l;
        }
        if ( ord($str) == 9 || ord($str) == 32 ) {
            $last_line .= $str;
            return $l;
        }
        my ( $field, $value ) = split /[ \t]*: ?/, $last_line, 2;
        if ( defined $field ) {
            my $f = lc $field;
            if ( defined $head{$f} ) {
                my $h = $head{$f};
                ref($h) eq 'ARRAY'
                  ? push( @$h, $value )
                  : ( $head{$f} = [ $h, $value ] );
            }
            else { $head{$f} = $value }
        }
        # warn $last_line;
        $last_line = $str;
        if ( $str eq "" ) {
            $res->{_headers} = bless \%head, 'HTTP::Headers';
            bless $res, 'HTTP::Response';
        }
        $l;
    }
}

1;
