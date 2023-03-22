package Deriv::Service::Trading;

use Myriad::Service;
use JSON::MaybeUTF8 qw(:v1);

has $sum;
has $count;

async method startup () {
    $count = 0;
    $sum = 0;
}

async method diagnostics ($level) {
    return 'ok';
}

async method value_updated : Receiver(service => 'deriv.service.reporting') ($sink, $api, %args) {
    $log->warnf('Receiver Called | %s | %s | %s');

    while(1) {
        await $sink->map(
            sub {
                my $e = shift;
                my %info = ($e->@*);
                $log->infof('INFO %s', \%info);

                my $data = decode_json_utf8($info{'data'});
                if ( ++$count == $data->{count} ){
                    $sum += $data->{value};
                } else {
                    $sum = $data->{value};
                    $count = $data->{count};
                }
            })->completed;
    }

}

async method current_sum : RPC {
    return { sum => $sum, count => $count};
}

1;
