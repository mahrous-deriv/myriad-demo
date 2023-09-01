package Deriv::Service::Reporting;

use Myriad::Service;
use Ryu::Source;
use JSON::MaybeUTF8 qw(encode_json_utf8);

has %trade_stats = (
    trade_count => 0,
    total_amount => 0,
);

has %payment_stats = (
    payment_count => 0,
    total_amount => 0,
);

async method startup() {}

async method diagnostics ($level) {
    return 'ok';
}

async method trade: Receiver(
  service => 'deriv.service.trading',
  channel => 'publish_trade_event'
) ($sink) {
  return $sink->map(async sub {
        my $trade_data = shift;
        $trade_data = $trade_data->{data};
        $log->infof('Trade event data %s', $trade_data);
        $trade_stats{trade_count}++;
        $trade_stats{total_amount} += $trade_data->{amount};
        $log->infof('%s', encode_json_utf8 \%trade_stats);
    })->resolve;
}

async method payment : Receiver(
  service => 'deriv.service.payment',
  channel => 'publish_payment_event'
) ($sink) {
  return $sink->map(async sub {
        my $payment_data = shift;
        $log->infof('Payment event data %s', $payment_data);
        $payment_stats{payment_count}++;
        $payment_stats{total_amount} += $payment_data->{amount} // 0; 
        $log->infof('%s', encode_json_utf8 \%payment_stats);
    })->resolve;
}


async method trader_pay : Receiver(
  service => 'deriv.service.trader',
  channel => 'pay'
) ($sink) {
  return $sink->map(async sub {
      my $data = shift;
      $log->infof('New payment %s', encode_json_utf8 $data);
    })->resolve;
}

async method trader_trade : Receiver(
  service => 'deriv.service.trader',
  channel => 'trade'
) ($sink) {
  return $sink->map(async sub {
      my $data = shift;
      $log->infof('New trade %s', encode_json_utf8 $data);
    })->resolve;
}

1;
