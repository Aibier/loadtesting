use forks; # recommended
use strict;
use warnings;
use Mojo::Util qw(dumper);
use DateTime;
use Mojo::JSON qw(from_json to_json encode_json decode_json);
use Mojo::URL;
use Try::Tiny;
use Text::CSV_XS;
use Moo;
use feature 'say';


my $configuration;
my $total_thread_number = 11;
my @workers;
my $time = time();
my $request_timeout = 120;
my $filename = "./csv_reports/transactions_v1_no_trx_".$total_thread_number."_".$time."_" . $request_timeout .".csv";
my ($start, $end);
my $transaction = {};
my @final_responses;


run();


sub run {
    my @workers = map { threads->create(\&send_transaction) } 1..$total_thread_number;
    foreach my $worker (@workers) {
        my $response = $worker->join;
        push @final_responses, $response;
    }
    generate_csv_report();
}

sub send_transaction {
    my ($transaction) = shift;
    # do your things
    say "calling me? ";
    $transaction->{duration} = 2;
    $transaction->{request} = "your request";
    $transaction->{response} = "your response";
    $transaction->{responseCode} = 200;
    return $transaction;
}

sub generate_csv_report{
    my $fh;
    my $csv = Text::CSV_XS->new({ binary => 1 });
    $csv->eol("\r\n");
    my @rows = ();
    push @rows, [ 'Response Code', 'Response Time', 'Request', 'Response' ];
    say ( dumper(\@final_responses));
    foreach my $response (@final_responses){
        push @rows, [
            $response->{responseCode},
            $response->{duration},
            $response->{request},
            $response->{response},
        ];
    }
    open $fh, ">:encoding(utf8)", $filename or die "$filename: $!";
    $csv->print($fh, $_) for @rows;
    close $fh or die "$filename: $!";
}

no Moo;
1;
