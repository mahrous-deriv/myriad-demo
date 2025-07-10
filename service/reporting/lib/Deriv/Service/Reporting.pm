package Deriv::Service::Reporting;

use Myriad::Service;
use Ryu::Source;
use JSON::MaybeUTF8 qw(encode_json_utf8);

field %trade_stats = (
    trade_count => 0,
    total_amount => 0,
);

field %payment_stats = (
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
        my $event = shift;
        my $trade_data = $event->{data} // $event; 
        $log->infof('Trade event data %s', $trade_data);
        if (defined $trade_data->{amount}) {
            $trade_stats{trade_count}++;
            $trade_stats{total_amount} += $trade_data->{amount};
            $log->infof('Updated trade stats: %s', encode_json_utf8 \%trade_stats);
        } else {
            $log->warnf('Trade event received without amount: %s', $trade_data);
        }
    })->resolve;
}

async method payment : Receiver(
  service => 'deriv.service.payment',
  channel => 'publish_payment_event'
) ($sink) {
  return $sink->map(async sub {
        my $event = shift;
        my $payment_data = $event->{data} // $event;
        $log->infof('Payment event data %s', $payment_data);
        if (defined $payment_data->{amount}) {
            $payment_stats{payment_count}++;
            $payment_stats{total_amount} += $payment_data->{amount};
            $log->infof('Updated payment stats: %s', encode_json_utf8 \%payment_stats);
        } else {
            $log->warnf('Payment event received without amount: %s', $payment_data);
        }
    })->resolve;
}

async method trader_pay : Receiver(
  service => 'deriv.service.trader',
  channel => 'pay'
) ($sink) {
  return $sink->map(async sub {
      my $data = shift;
      $log->infof('Received trader pay event: %s', encode_json_utf8 $data);
    })->resolve;
}

async method trader_trade : Receiver(
  service => 'deriv.service.trader',
  channel => 'trade'
) ($sink) {
  return $sink->map(async sub {
      my $data = shift;
      $log->infof('Received trader trade event: %s', encode_json_utf8 $data);
    })->resolve;
}

async method get_reporting_stats : RPC () {
    return {
        success => 1,
        content => {
            trade_stats   => \%trade_stats,
            payment_stats => \%payment_stats,
        }
    };
}

1;

