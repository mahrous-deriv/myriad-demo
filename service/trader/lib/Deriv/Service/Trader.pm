package Deriv::Service::Trader;

use Myriad::Service;
use Ryu::Source;
use JSON::MaybeUTF8 qw(decode_json_utf8);

has $events;
has $trading_svc;
has $reporting_svc;
has $payment_svc;

async method startup() {
    $events = $self->ryu->source;
    $trading_svc = $api->service_by_name('deriv.service.trading');
    $payment_svc = $api->service_by_name('deriv.service.payment');
    $reporting_svc = $api->service_by_name('deriv.service.reporting');
}

async method diagnostics ($level) {
    return 'ok';
}

async method pay : Batch () {
    $log->infof('Trader paying...');
    my ($user_id, $symbol_id, $amount) = (1, 1, 10.00);
    my $res = await $payment_svc->call_rpc("process_payment", (user_id => $user_id, symbol_id => $symbol_id, amount => $amount, gateway => 'cashier'), timeout => 60);
    $log->infof('%s', $res);
    await $self->loop->delay_future(after => 10);
    return [];
}

async method trade : Batch () {
    $log->infof('Trader trading...');
    my ($user_id, $symbol_id, $type, $amount) = (1, 1, 'buy', 10.00);
    my $trade = await $trading_svc->call_rpc("create_order", (user_id => $user_id, symbol => 'frxUSDJPY', type => $type, amount => $amount), timeout => 60);
    $log->infof('%s', $trade);
    await $self->loop->delay_future(after => 10);
    return [];
}

1;

