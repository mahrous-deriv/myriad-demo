package Deriv::Service::Trading;

use Myriad::Service;
use Ryu::Source;
use Database::Async;
use Database::Async::Engine::PostgreSQL;
use JSON::MaybeUTF8 qw(decode_json_utf8);

has $events;
has $dbh;
has $payment_svc;
has $reporting_svc;

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
    $payment_svc = $api->service_by_name('deriv.service.payment');
    $reporting_svc = $api->service_by_name('deriv.service.trading');
}

async method diagnostics ($level) {
    return 'ok';
}

async method create_order : RPC (%order) {
    return { state => 'fail', content => "Must be defined" } unless keys %order;
    $log->infof('Creating order %s', %order);
    $order{state} = 'pending';
    await $self->store_transaction($order{symbol}, $order{amount}, );
    $log->info('Publishing transaction event');
    await $self->publish_transaction_event($order{symbol}, $order{amount}, $order{id});
    return { state => 'success', content => $order{id} };
}

method store_transaction (%transaction) {
    return {success => 1, content => $transaction{id}};
}

async method publish_transaction_event : Emitter() ($sink) {
    $sink->from($events);
    await $sink->source->completed;
}

1;
