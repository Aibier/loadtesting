use strict;
use warnings;
use lib 'local/lib/perl5';
use Data::Dumper;
use feature 'say';
use Mojo::URL;
use Mojo::UserAgent;
use DateTime;
use Text::CSV_XS qw(csv);
use Mojo::JSON qw(from_json encode_json to_json);
use threads;

my $request_timeout = 60;
my ($start, $end, $diff);
my $total_thread_number = 30;
my $time = time();
my $filename = "./production/v1_no_trx_".$total_thread_number."_".$time."_" . $request_timeout .".csv";
my @threads;


my $token = "";
my $host_name = "";


my @accounts = (
    {
        "lastname" => "{{lastname}}",
        "payer_id"  => "{{payer_id}}",
        "account"   => "1235645657"
    },
    # ... add more if u want to test with multi accounts
);

run();

sub run {
    ### TO PUSH to COBRA WORKERS
    my @transactionIds = ();
    foreach my $account (@accounts) {
        my $external_id = "THBD" . time() . int(rand(100)) ;
        my $path_quo = "money-transfer/quotations/";
        my $response = send_request($path_quo, encode_json(get_quotation_payload($external_id, $account->{payer_id})) );
        my $quotation_id = $response->{body}->{body}->{id};
        if ( $quotation_id) {
            my $transaction_path = "money-transfer/quotations/" .$quotation_id . "/transactions";
            my $trans_response = send_request(
                $transaction_path,
                encode_json(get_transaction_payload(time() . int(rand(100)), $account)));
            say Dumper($trans_response);
            push(@transactionIds, $trans_response->{body}->{body}->{id});
        }
    }

    for my $id (@transactionIds) {
        my $transaction_confirmation_path = "money-transfer/transactions/" . $id . "/confirm";
        push @threads, async {
            send_request($transaction_confirmation_path, encode_json({}));
        };
    }
    if (@transactionIds) {
        generate_csv_report();
    }
}
sub generate_csv_report{
    my $fh;
    my $csv = Text::CSV_XS->new({ binary => 1 });
    $csv->eol("\r\n");
    my @rows = ();
    push @rows, [ 'ResponseCode', 'ResponseTime', 'Request', 'Response' ];

    foreach my $thread (@threads){
        my $response = $thread->join;
        push @rows, [
            $response->{responseCode},
            $response->{duration},
            $response->{request},
            to_json(defined $response->{body} ? $response->{body} : $response, { utf8 => 1, pretty => 1 }),
        ];
    }
    open $fh, ">:encoding(utf8)", $filename or die "$filename: $!";
    $csv->print($fh, $_) for @rows;
    close $fh or die "$filename: $!";
}

sub get_quotation_payload {
    my $external_id = shift;
    my $payer_id = shift;
    my $quotation_payload = {
        "external_id"      => "" . $external_id,
        "payer_id"         => "" . $payer_id,
        "mode"             => "DESTINATION_AMOUNT",
        "transaction_type" => "B2C",
        "source"           => {
            "amount"           => undef,
            "currency"         => "SGD",
            "country_iso_code" => "SGP"
        },
        "destination"      => {
            "amount"   => "1",
            "currency" => "PHP"
        }
    };
    return $quotation_payload;
}

sub get_transaction_payload {
    my $external_id = shift;
    my $account = shift;
    my $transaction_payload = {
        "credit_party_identifier" => {
            "bank_account_number" => $account->{account},
            "msisdn" => $account->{account},
        },
        "external_id"             => "" . $external_id,
        # "sender"                  => {
        #     "lastname"         => "Thunes",
        #     "country_iso_code" => "SGP",
        #     "id_number"        => "11234578899",
        #     "id_type"          => "DRIVING_LICENSE",
        #     "address"          => "a",
        #     "date_of_birth"    => "1992-02-19",
        #     "city"             => "Singapore",
        #     "postal_code"      => "134322"
        # },
        "sending_business" => {
            "registered_name" => "Thunes",
            "country_iso_code" => "SGP",
            "address"          => "75 Anson Road",
        },
        "purpose_of_remittance"   => "OTHER",
        "beneficiary"             => {
            "lastname"  => $account->{lastname},
        }
    };
    return $transaction_payload;
}

sub send_request {
    $start = time();
    my ( $path, $request ) = @_;
    my $url = $host_name . $path;
    my $headers = {
        'Authorization' => 'Basic ' . $token,
        'Content-Type' => 'application/json',
    };
    my $ua = Mojo::UserAgent->new(
        request_timeout    => $request_timeout,
        inactivity_timeout => $request_timeout
    );

    say( "Sending POST request to $url" );
    my $tx = $ua->post( $url => $headers => $request );
    say Dumper('Request: ' . $tx->req->body );

    my $result_holder;
    my $response;
    if ( my $err = $tx->error ) {
        my $err_code          = $err->{ code };
        my $err_message       = $err->{ message };
        my $response_body_err = $tx->res->body;

        say Dumper( $err_code          ? "Error code: $err_code"             : 'Error code: undef' );
        say Dumper( $err_message       ? "Error message: $err_message"       : 'Error message: undef' );
        say Dumper( $response_body_err ? "Response body: $response_body_err" : 'Response body: undef' );

        $result_holder->{ code }  = $err_code;
        $result_holder->{ body }  = $tx->res->json || $response_body_err;
        $result_holder->{ error_message } = $err_message;

        if ( !$err_code || $err_code > 201 ) {
            # Connection error
            say Dumper( 'Connectivity issue while sending request.' );
            $result_holder->{ connection_error } = 1;

        } elsif ( $tx->res->json ) { # Handle other 4XX / 5XX with JSON body
            $result_holder->{ other_error } = 1;

        } else { # Treat other cases as unexpected response
            say Dumper("Unexpected Response / HTTP status");
            $result_holder->{ unexpected_response } = 1;
        }
        $end = time();
        $diff = $end - $start;
        $response = {
            duration        =>  $diff,
            request         =>  $tx->req->body,
            responseCode    => $result_holder->{ code },
            body         => $result_holder
        };
    } else {
        my $response_code = $tx->res->code;
        my $response_body = $tx->res->body;
        say Dumper("Response code: $response_code");
        say Dumper("Response body: $response_body");

        $result_holder->{ code } = $response_code;
        $result_holder->{ body } = $tx->res->json || $response_body;

        if ( $tx->res->json ) {
            $result_holder->{ success } = 1;

        } else {
            $result_holder->{ unexpected_response } = 1;
            say Dumper('Unexpected Response: No valid json body.');
        }
        $end = time();
        $diff = $end - $start;
        $response = {
            duration        =>  $diff,
            request         =>  $tx->req->body,
            responseCode    => $tx->res->code,
            body         => $result_holder
        };
    }
    return $response;
}