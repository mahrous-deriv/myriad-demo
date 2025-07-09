package Deriv::Service::Trading;

use Myriad::Service;
use Ryu::Source;
use Database::Async;
use Database::Async::Engine::PostgreSQL;
use JSON::MaybeUTF8 qw(decode_json_utf8);

field $events;
field $dbh;
field $payment_svc;
field $reporting_svc;

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
    foreach my $key (qw/user_id symbol amount type/){
        return { error => 1, content => "$key must be defined" } unless defined $order{$key};
    } 
    $order{state} = 'done';
    $events->emit(\%order);
    $log->infof('Created order %s', join(q{, }, map{qq{$_ => $order{$_}}} sort keys %order));
    return { success => 1, content => \%order};
}

async method publish_trade_event : Emitter() ($sink) {
    $sink->from($events);
    await $sink->source->completed;
}

1;
