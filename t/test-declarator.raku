use lib 'lib';
use Qwiratry::Transformer;

transformer TestTransform is Transformer {
}

say "Success! Transformer declared: " ~ TestTransform.^name;

