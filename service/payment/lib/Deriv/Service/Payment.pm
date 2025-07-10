package Deriv::Service::Payment;

use Myriad::Service;
use Ryu::Source;
use Database::Async;
use Database::Async::Engine::PostgreSQL;
use JSON::MaybeUTF8 qw(decode_json_utf8);

field $events;
field $dbh;
field $trading_svc;
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
    $trading_svc = $api->service_by_name('deriv.service.trading');
    $reporting_svc = $api->service_by_name('deriv.service.reporting');
}

async method diagnostics ($level) {
    return 'ok';
}

async method process_payment : RPC (%payment) {
    foreach my $key (qw/user_id amount gateway/){ # symbol_id removed as it's not used in store_payment
        return { error => 1, content => "$key must be defined" } unless defined $payment{$key};
    }
    # Basic validation
    return { error => 1, content => "user_id must be an integer" } unless $payment{user_id} =~ /^\d+$/;
    return { error => 1, content => "amount must be a positive number" } unless $payment{amount} =~ /^\d*(\.\d+)?$/ && $payment{amount} > 0;
    return { error => 1, content => "gateway must be 'trading' or 'cashier'" } unless $payment{gateway} eq 'trading' || $payment{gateway} eq 'cashier';

    if ( $self->is_valid_payment(%payment) ){
        $payment{state} = 'pending';
        try {
            $payment{id} = await $self->store_payment(%payment);
            die "Could not store payment" if $payment{id} eq '-1' || $payment{id} == 0; # id can be 0 on error from store_payment
            $log->infof('ID of new payment %s', $payment{id});
            $events->emit(\%payment);
            $log->infof('Emitted new payment event %s', \%payment);
            return { success => 1, content => \%payment };
        } catch ($e) {
            $log->errorf("Error processing payment: %s", $e);
            return { error => 1, content => "Error processing payment: $e" };
        }
    } else {
        $log->errorf('Failed to process invalid payment.');
        return { error => 1, content => 'Invalid payment'};
    }
}

method is_valid_payment (%args) {
    return 1;
}

async method publish_payment_event : Emitter() ($sink) {
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
        $log->infof('Created payment: %s', $res);
        my $id = $res->{create_payment};
        return $id;
    } catch ($e) {
        $log->errorf("Failed to store payment with error: $e");
        return 0;
    }
}

async method get_payment_status : RPC (%args) {
    my $payment_id = $args{payment_id};
    return { error => 1, content => "payment_id must be defined" } unless defined $payment_id;
    return { error => 1, content => "payment_id must be an integer" } unless $payment_id =~ /^\d+$/;

    try {
        my $status = await $dbh->query_single(
            q{SELECT CASE WHEN EXISTS (SELECT 1 FROM payment.payment WHERE id = $1) THEN 'successful' ELSE 'not_found' END},
            $payment_id
        );
        # In a real scenario, we might have more statuses like 'pending', 'failed', etc.
        # For now, we assume if it exists, it's 'successful' as per the original placeholder.
        # The payment table itself doesn't have a status column yet.
        return { success => 1, content => { payment_id => $payment_id, status => $status } };
    } catch ($e) {
        $log->errorf("Error fetching payment status for ID %s: %s", $payment_id, $e);
        return { error => 1, content => "Error fetching payment status: $e" };
    }
}

async method get_payment_history : RPC (%args) {
    my $user_id = $args{user_id};
    return { error => 1, content => "user_id must be defined" } unless defined $user_id;
    return { error => 1, content => "user_id must be an integer" } unless $user_id =~ /^\d+$/;

    try {
        my $rows = await $dbh->query(
            q{SELECT id, foreign_id, created_at, gateway, amount, balance FROM payment.payment WHERE user_id = $1 ORDER BY created_at DESC},
            $user_id
        )->row_hashrefs->as_list;

        return { success => 1, content => $rows };
    } catch ($e) {
        $log->errorf("Error fetching payment history for user ID %s: %s", $user_id, $e);
        return { error => 1, content => "Error fetching payment history: $e" };
    }
}

1;

