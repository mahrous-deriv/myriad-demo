package Deriv::Service::Trader;

use Myriad::Service;
use Ryu::Source;
use JSON::MaybeUTF8 qw(decode_json_utf8);

field $events;
field $trading_svc;
field $reporting_svc;
field $payment_svc;

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
    await $self->loop->delay_future(after => rand(5) + 5); # Random delay between 5-10 seconds
    my $user_id = int(rand(2)) + 1; # User 1 or 2
    my $amount = sprintf("%.2f", rand(50) + 1); # Random amount between 1.00 and 50.99
    my $gateway = rand() > 0.5 ? 'cashier' : 'trading';

    $log->infof("Trader (user %d) attempting to pay %s via %s...", $user_id, $amount, $gateway);

    try {
        my $payment_result = await $payment_svc->call_rpc(
            "process_payment",
            { user_id => $user_id, amount => $amount, gateway => $gateway },
            timeout => 60
        );

        if ($payment_result->{error}) {
            $log->errorf("Payment RPC failed for user %d: %s", $user_id, $payment_result->{content});
            return [];
        }

        $log->infof("Payment RPC successful for user %d: %s", $user_id, encode_json_utf8($payment_result->{content}));
        return ref $payment_result->{content} eq 'ARRAY' ? $payment_result->{content} : [$payment_result->{content}];
    } catch ($e) {
        $log->errorf("Exception during payment RPC for user %d: %s", $user_id, $e);
        return [];
    }
}

async method trade : Batch () {
    await $self->loop->delay_future(after => rand(8) + 7); # Random delay between 7-15 seconds
    my $user_id = int(rand(2)) + 1; # User 1 or 2
    my $symbols = ['frxUSDJPY', 'frxEURUSD', 'volidx100'];
    my $symbol = $symbols->[rand @$symbols];
    my $type = rand() > 0.5 ? 'buy' : 'sell';
    my $amount = sprintf("%.2f", rand(100) + 5); # Random amount between 5.00 and 105.99

    $log->infof("Trader (user %d) attempting to %s %s of %s...", $user_id, $type, $amount, $symbol);

    try {
        my $trade_result = await $trading_svc->call_rpc(
            "create_order",
            { user_id => $user_id, symbol => $symbol, type => $type, amount => $amount },
            timeout => 60
        );

        if ($trade_result->{error}) {
            $log->errorf("Trade RPC failed for user %d (%s %s %s): %s", $user_id, $type, $amount, $symbol, $trade_result->{content});
            return [];
        }

        $log->infof("Trade RPC successful for user %d: %s", $user_id, encode_json_utf8($trade_result->{content}));
        return ref $trade_result->{content} eq 'ARRAY' ? $trade_result->{content} : [$trade_result->{content}];
    } catch ($e) {
        $log->errorf("Exception during trade RPC for user %d (%s %s %s): %s", $user_id, $type, $amount, $symbol, $e);
        return [];
    }
}

1;


