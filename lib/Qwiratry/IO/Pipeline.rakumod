=begin pod

Execute I/O operator pipelines (source, parse, query, render, destination).

=end pod
unit module Qwiratry::IO::Pipeline;

use Qwiratry::Operator::IO;
use Qwiratry::Operator::Capability;
use Qwiratry::Operator::MapReduce;
use Qwiratry::Query::Match;
use Qwiratry::Exception::Operator;

our sub execute(Mu $op, Mu :$origin) is export {
    given $op {
        when DestinationOperator {
            my $content = execute($op.subject // $origin, :$origin);
            write-location($op.location, $content);
            $content
        }
        when RenderOperator {
            my $data = execute($op.subject // $origin, :$origin);
            render-data($op.format, $data, $op.options)
        }
        when ParseOperator {
            my $text = execute($op.subject // $origin, :$origin);
            parse-data($op.format, $text)
        }
        when SourceOperator {
            read-location($op.location)
        }
        when IOOperator | NavigationOperator | SetOperator | MapReduceOperator {
            my $root = pipeline-root($op, $origin);
            my @results = select($op, $root).list;
            @results.elems == 1 ?? @results[0] !! @results
        }
        default {
            $op
        }
    }
}

sub pipeline-root(Mu $op, Mu $origin --> Mu) {
    if $op.can('subject') && $op.subject.defined {
        return execute($op.subject, :$origin) if $op.subject ~~ IOOperator;
        return pipeline-root($op.subject, $origin) if $op.subject.can('subject');
        return $op.subject;
    }
    $origin // $op
}

sub read-location(Str $location --> Str) {
    if $location.starts-with(any('http://', 'https://')) {
        X::Qwiratry::IO::LocationError.new(
            :message("Cannot fetch network location: $location"),
            :location($location),
            :reason('Network fetch not available in test environment'),
            :operator-type('SourceOperator'),
        ).throw;
    }
    unless $location.IO.e {
        X::Qwiratry::IO::LocationError.new(
            :message("I/O location not found: $location"),
            :location($location),
            :reason('File not found'),
            :operator-type('SourceOperator'),
        ).throw;
    }
    $location.IO.slurp
}

sub write-location(Str $location, Mu $content) {
    my $text = $content ~~ Str ?? $content !! ~$content;
    my $path = $location;
    $path.IO.parent.mkdir unless $path.IO.parent.d;
    spurt $path, $text
}

sub parse-data(Str $format, Str $text) {
    my $module-name = ensure-parse-format($format);
    my $loaded = (require ::($module-name));
    $loaded.WHO{'&parse'}($text)
}

sub render-data(Str $format, Mu $data, Associative $options) {
    my $module-name = ensure-render-format($format);
    my $loaded = (require ::($module-name));
    $loaded.WHO{'&render'}($data, |%($options // %()))
}
