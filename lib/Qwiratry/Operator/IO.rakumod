=begin pod

I/O query operators as immutable AST nodes.

Source (C<⮳>), parse (C<↱>), render (C<↴>), and destination (C<⮷>) read,
parse, render, and write external data.

=end pod
unit module Qwiratry::Operator::IO;

use Qwiratry::Operator::Capability;
use Qwiratry::Exception::Operator;

role IOOperatorNode does IOOperator does OperatorBase {
    has Mu $.subject;

    submethod TWEAK(:$subject) {
        $!subject = $subject if $subject.defined;
    }

    method io-describe(Str $detail --> Str) {
        my $sub = $!subject.defined ?? " subject={$!subject.^name}" !! '';
        "{self.^name}($detail$sub)"
    }
}

sub validate-location(Str $location --> Str) is export {
    return $location if $location.starts-with(any('http://', 'https://', 'file://'));
    return $location if $location.starts-with('/') || $location.starts-with('./')
        || ($location !~~ /^\w+:\/\// && $location.contains('.'));
    return $location if $location ~~ /^[\w\.\-\/]+$/;
    X::Qwiratry::IO::LocationError.new(
        :message("Invalid I/O location: $location"),
        :location($location),
        :reason('Invalid location format'),
        :operator-type('IOOperator'),
    ).throw;
}

sub normalize-format-name(Str $format --> Str) is export {
    my $name = $format.subst(/\.rakumod$/, '');
    $name = $name.split('::').[*-1] if $name.contains('::');
    $name.uc
}

sub parse-format-module-name(Str $format --> Str) is export {
    "Qwiratry::IO::Parse::{normalize-format-name($format)}"
}

sub render-format-module-name(Str $format --> Str) is export {
    "Qwiratry::IO::Render::{normalize-format-name($format)}"
}

our sub discover-parse-formats(--> List) is export {
    state @formats;
    unless @formats {
        @formats = gather {
            for <JSON XML CSV> -> $name {
                my $module = parse-format-module-name($name);
                ensure-format-module($module);
                take $name if format-module-available($module);
            }
        }
    }
    @formats
}

our sub discover-render-formats(--> List) is export {
    state @formats;
    unless @formats {
        @formats = gather {
            for <JSON XML CSV> -> $name {
                my $module = render-format-module-name($name);
                ensure-format-module($module);
                take $name if format-module-available($module);
            }
        }
    }
    @formats
}

sub format-export-name(Str $module --> Str) {
    $module.contains('::Parse::') ?? '&parse' !! '&render'
}

sub load-format-module(Str $module) {
    try {
        my $loaded = ::($module);
        my $export = format-export-name($module);
        return $loaded if $loaded.WHO{$export}.defined;
        CATCH { }
    }
    (require ::($module))
}

sub format-module-available(Str $module --> Bool) {
    try {
        my $loaded = load-format-module($module);
        return $loaded.WHO{format-export-name($module)}.defined;
        CATCH { default { False } }
    }
}

sub ensure-format-module(Str $module) is export {
    try {
        load-format-module($module);
        CATCH { default { Nil } }
    }
}

sub ensure-parse-format(Str $format) is export {
    my $module = parse-format-module-name($format);
    ensure-format-module($module);
    unless format-module-available($module) {
        X::Qwiratry::IO::FormatNotFound.new(
            :message("Parse format module not found for $format"),
            :format(normalize-format-name($format)),
            :parse-or-render('Parse'),
            :operator-type('ParseOperator'),
        ).throw;
    }
    $module
}

sub ensure-render-format(Str $format) is export {
    my $module = render-format-module-name($format);
    ensure-format-module($module);
    unless format-module-available($module) {
        X::Qwiratry::IO::FormatNotFound.new(
            :message("Render format module not found for $format"),
            :format(normalize-format-name($format)),
            :parse-or-render('Render'),
            :operator-type('RenderOperator'),
        ).throw;
    }
    $module
}

class SourceOperator is RakuAST::Node does IOOperator does OperatorBase is export {
    has Str $.location is required;

    submethod BUILD(Str :$!location!) {
        validate-location($!location);
    }

    method describe(--> Str) {
        "SourceOperator(location: '$!location')"
    }
}

class ParseOperator is RakuAST::Node does IOOperatorNode is export {
    has Str $.format is required;

    submethod TWEAK {
        ensure-parse-format($!format);
    }

    method describe(--> Str) {
        self.io-describe("format: '{$!format.lc}'")
    }
}

class RenderOperator is RakuAST::Node does IOOperatorNode is export {
    has Str $.format is required;
    has %.options;

    submethod TWEAK {
        ensure-render-format($!format);
    }

    method describe(--> Str) {
        self.io-describe("format: '{$!format.lc}', options: {%.options.raku}")
    }
}

class DestinationOperator is RakuAST::Node does IOOperatorNode is export {
    has Str $.location is required;

    submethod BUILD(Str :$!location!) {
        validate-location($!location);
    }

    method describe(--> Str) {
        self.io-describe("location: '$!location'")
    }
}
