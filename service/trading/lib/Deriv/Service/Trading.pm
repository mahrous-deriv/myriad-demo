package Deriv::Service::Trading;

use Myriad::Service;
use Ryu::Source;
use Database::Async;
use Database::Async::Engine::PostgreSQL;
use JSON::MaybeUTF8 qw(decode_json_utf8);
use XXX;

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
    $order{state} = 'pending';
    $order{id} = await $self->store_transaction($order{symbol}, $order{amount});
    await $self->publish_transaction_event($order{symbol}, $order{amount}, $order{id});
    return { state => 'success', content => $order{id} };
}

method store_transaction (%transaction) {
    return {success => 1, content => $transaction{id}};
}

async method value_updated : Receiver(service => 'deriv.service.reporting') ($sink, $api, %args) {
    $log->warnf('Receiver Called | %s | %s | %s', $sink, $api, \%args);
    my $count = 0;
    my $sum = 0;

    while (my $e = await $sink) {
        my %info = $e->@*;
        $log->infof('INFO %s', \%info);

        my $data = decode_json_utf8($info{'data'});
        if ($data->{count} == $count + 1) {
            $sum += $data->{value};
            $count = $data->{count};
        } elsif ($data->{count} > $count + 1) {
            $log->warnf('Skipping data with count %d, expected %d', $data->{count}, $count + 1);
            $sum = $data->{value};
            $count = $data->{count};
        } else {
            $log->warnf('Ignoring duplicate data with count %d', $data->{count});
        }
    }
}

async method publish_transaction_event ($type, $amount, $transaction_id) {
    my $event_data = {type => $type, amount => $amount, transaction_id => $transaction_id};
	  $events->emit({transaction => encode_json_utf8($event_data)});
}

1;
