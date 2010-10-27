package HTTP::Response::Parser::PP;

use strict;
use warnings;
use Hash::MultiValue;

{
    no warnings 'once', 'redefine';
    *HTTP::Response::Parser::parse               = \&parse;
    *HTTP::Response::Parser::parse_http_response = \&parse_http_response;
}

my %PARSER_FUNC = (
    HTTP::Response::Parser::FORMAT_NONE       => \&_parse_as_special,
    HTTP::Response::Parser::FORMAT_HASHREF    => \&_parse_as_hashref,
    HTTP::Response::Parser::FORMAT_ARRAYREF   => \&_parse_as_arrayref,
    HTTP::Response::Parser::FORMAT_MULTIVALUE => \&_parse_as_multivalue,
);

# create HTTP::Response
sub parse {
    my ($self, $header, $content) = @_;

    my $res = {};
    my $header_format = $self->{header_raw_format};
    my ($ret, $minor, $rc, $msg, $header_obj) = parse_http_response($header, $header_format);

    if ($ret < 0) {
        $self->{errcode} = $ret;
        $self->{errstr} = ($ret == -1) ? "Invalid HTTP Response" : "Insufficient HTTP response";
        return;
    }
    
    # create HTTP::Response compatible hash
    $res->{'_protocol'} = 'HTTP/1.' . $minor;
    $res->{'_rc'} = $rc;
    $res->{'_msg'} = $msg;
    $res->{'_header'} = $header_obj;

    if (defined $content) {
        $res->{_content} = $content;
    } else {
        $res->{_content} = substr($header, $ret) || "";
    }

    bless $res->{_headers}, $self->{header_class};
    bless $res, $self->{response_class};

    return $res;
}

sub parse_http_response($$;$) {
    my ($str, $header_format, $special_headers) = @_;
    return -2 unless $str;

    my $len = length $str;
    
    my ($sl, $remain) = split /\r?\n/, $_[0], 2;
    my ($proto, $rc, $msg) = split(' ', $sl, 3);
    return -1 unless $proto =~m{^HTTP/1.(\d)};
    my $minor_version = $1;
    return -1 unless $rc =~m/^\d+$/;

    my ($header_str, $content) = split /\r?\n\r?\n/, $remain, 2;

    my $parser_func = $PARSER_FUNC{$header_format};
    die 'unknown header format: '. $header_format unless $parser_func;

    my $header = $parser_func->($header_str, $special_headers);

    return -2 unless ($remain =~/\r?\n\r?\n/ || $content);
    my $parsed = $len - (defined $content ? length $content : 0);

    return (
        $parsed, $minor_version, $rc, $msg,
        $header, $special_headers
    );
}

# return special headers only
sub _parse_as_none {
    my ($str, $special) = @_;
    return unless defined $str;
    return unless defined $special;

    my ($field, $value, $f);
    for ( split /\r?\n/, $str ) {
        if ( defined $field ) {
            if ( ord == 9 || ord == 32 ) {
                $value .= "\n$_";
                next;
            }
            $f = lc($field); $f =~ tr/_/-/;
            exists $special->{$f} and $special->{$f} = $value;
        }
        ( $field, $value ) = split /[ \t]*: ?/, $_, 2;
    }
    if ( defined $field ) {
        $f = lc($field); $f =~ tr/_/-/;
        exists $special->{$f} and $special->{$f} = $value;
    }
}

# return headers as arrayref
sub _parse_as_array {
    my ($str, $special) = @_;
    return [] unless defined $str;

    my (@headers, $field, $value, $f );
    for ( split /\r?\n/, $str ) {
        if ( defined $field ) {
            if ( ord == 9 || ord == 32 ) {
                $value .= "\n$_";
                next;
            }
            $f = lc($field); $f =~ tr/_/-/;
            push @headers, $f, $value;
            exists $special->{$f} and $special->{$f} = $value;
        }
        ( $field, $value ) = split /[ \t]*: ?/, $_, 2;
    }
    if ( defined $field ) {
        $f = lc($field); $f =~ tr/_/-/;
        push @headers, $f, $value; 
        exists $special->{$f} and $special->{$f} = $value;
    }
    return \@headers;
}

# return headers as HTTP::Header compatible HashRef
sub _parse_as_hashref {
    my ($str, $special) = @_;
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
    \%self;
}

# return multivalue
sub _parse_as_multivalue {
    my ($str, $special) = @_;
    my $mv = Hash::MultiValue->new;
    return $mv unless defined $str;

    my ($field, $value, $f );
    for ( split /\r?\n/, $str ) {
        if ( defined $field ) {
            if ( ord == 9 || ord == 32 ) {
                $value .= "\n$_";
                next;
            }
            $f = lc($field); $f =~ tr/_/-/;
            $mv->add($f, $value);
            exists $special->{$f} and $special->{$f} = $value;
        }
        ( $field, $value ) = split /[ \t]*: ?/, $_, 2;
    }
    if ( defined $field ) {
        $f = lc($field); $f =~ tr/_/-/;
        $mv->add($f, $value);
        exists $special->{$f} and $special->{$f} = $value;
    }
    return $mv;
}


# TODO: incr_parser
# $parser = $self->incr_parser($res);
# my $parsed = $parser->($str); # n bytes of HTTP::Response
sub incr_parser {
    my ($self, $res) = @_;
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
