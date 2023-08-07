package Deriv::Service::Reporting;

use Myriad::Service;
use Ryu::Source;
use Database::Async;
use Database::Async::Engine::PostgreSQL;
use JSON::MaybeUTF8 qw(encode_json_utf8);

has $call_event_handler = Ryu::Source->new;
has $events;
has $dbh;
has $trading_svc;
has $payment_svc;

async method startup() {
    $events = $self->ryu->source;
    $self->add_child(
        $dbh = Database::Async->new(
            uri => $ENV{DATABASE_URL},
            pool => {
                max => 8
            }
        )
    );
    $trading_svc = $api->service_by_name('deriv.service.trading');
    $payment_svc = $api->service_by_name('deriv.service.payment');
}

async method diagnostics ($level) {
    return 'ok';
}

async method payment : Receiver(service => 'deriv.service.payment', channel => 'publish_payment_event') ($sink) {
    $log->info('Receiver');
  return $sink->map(async sub {
        my $payment_data = shift;
        $log->infof(encode_json_utf8 $payment_data);
    })->resolve;
}

1;
