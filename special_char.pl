use strict;
use warnings;
use lib 'local/lib/perl5';
use feature 'say';
use Encode qw(encode_utf8 decode_utf8);
use Text::Unidecode qw(unidecode);

my $message = "Motorstraßé 32d, #15, 3rd floor, Munich Germany 80809";
$message = "2 Rue Georges Dupréé, 3 Etage Droit Saint-Étienne France 42000";
$message = "Vorgartenstraße";
my $result = cleanup_special_chars($message);
say $result;
$message = "张小三";
$message = "Ad";
$result = detect_chinese_char($message);
say $result;


sub cleanup_special_chars {
    my $input = shift;

    return "" if ( !$input );
    $input = decode_utf8($input) unless utf8::is_utf8($input);
    $input = unidecode($input);
    say $input;
    $input =~ s/[^\w ]//g;
    $input =~ s/_//g;
    return $input;
}

sub detect_chinese_char {
    my $input = shift;
    $input = decode_utf8($input) unless utf8::is_utf8($input);
    my $is_sender_name_chinese = $input =~ /\p{Han}/;
    if ( $is_sender_name_chinese ) {
        return 1;
    }
    return 0;
}