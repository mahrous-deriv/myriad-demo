package Deriv::Service::Payment;

use Myriad::Service;
use Ryu::Source;
use Database::Async;
use Database::Async::Engine::PostgreSQL;
use JSON::MaybeUTF8 qw(decode_json_utf8);

has $events;
has $dbh;
has $trading_svc;
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
    $trading_svc = $api->service_by_name('deriv.service.trading');
    $reporting_svc = $api->service_by_name('deriv.service.reporting');
}

async method diagnostics ($level) {
    return 'ok';
}

async method process_payment : RPC (%payment) {
    foreach my $key (qw/user_id symbol_id type amount gateway/){
        return { state => 'fail', content => "$key must be defined" } unless defined $payment{$key};
    } 
    if ( $self->is_valid_payment(%payment) ){
        $payment{state} = 'pending';
        try {
            $payment{id} = await $self->store_payment(%payment);
            die "Could not store payment" if $payment{id} eq '-1';
            $self->publish_payment_event($payment{symbol}, $payment{amount}, $payment{id});
            $log->infof('ID of new payment %s', $payment{id});
            $events->emit(\%payment);
            $log->infof('Emitted new payment event %s', \%payment);
            return { state => 'success', content => $payment{id} };
        } catch ($e) {
            return { state => 'fail', content => $e };
        }
    } else {
        $log->errorf('Failed to process invalid payment.');
        return { state => 'fail', content => 'Invalid payment'};
    }
}

method is_valid_payment (%args) {
    return 1;
}

async method publish_payment_event : Emitter() ($sink) {
    $log->infof('Emitter up and emitting...');
    $sink->from($events);
    await $sink->source->completed;
}

async method store_payment (%payment) {
    try {
        my $balance = await $dbh->query('
            SELECT balance 
              FROM payment.payment
             WHERE user_id = $1 
             order by created_at desc
             limit 1
             ', $payment{user_id})->single;
        $balance += $payment{amount};
        my $res = await $dbh->query(q{SELECT * FROM payment.create_payment($1::integer, $2::integer, $3::payment.gateway, $4::numeric, $5::numeric)}, $payment{user_id}, '1235', $payment{gateway}, $payment{amount}, $balance // 0)->row_hashrefs->as_list;
        my $id = $res->{create_payment};
        return $id;
    } catch ($e) {
        $log->errorf("Failed to store payment with error: $e");
        return 0;
    }
}

async method get_payment_status : RPC (%args) {
    my $payment_id = $args{payment_id};
    return 'successful';
}

async method get_payment_history : RPC (%args) {
    my $user_id = $args{user_id};
    my @payment_history = (); 
    return \@payment_history;
}

1;

