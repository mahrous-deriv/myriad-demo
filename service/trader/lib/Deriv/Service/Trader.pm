package Deriv::Service::Trader;

use Myriad::Service;
use Ryu::Source;
use JSON::MaybeUTF8 qw(decode_json_utf8);

has $trading_svc;
has $reporting_svc;
has $payment_svc;
has $timer;
has $events;

async method startup() {
    $events = $self->ryu->source;
    $trading_svc = $api->service_by_name('deriv.service.trading');
    $payment_svc = $api->service_by_name('deriv.service.payment');
    $reporting_svc = $api->service_by_name('deriv.service.reporting');
}

async method diagnostics ($level) {
    return 'ok';
}

async method next_batch : Batch () {
    $log->infof('Trader trading...');
    #await $self->loop->delay_future(after => $timer);
    my ($user_id, $symbol_id, $type, $amount) = (1, 1, 'deposit', 10.00);
    my $res = await $payment_svc->call_rpc("process_payment", (user_id => $user_id, symbol_id => $symbol_id, type => $type, amount => $amount, gateway => 'cashier'), timeout => 60);
    return [];
}

1;

