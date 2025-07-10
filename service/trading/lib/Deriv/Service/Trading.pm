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
    # Basic Validation
    return { error => 1, content => "user_id must be an integer" } unless $order{user_id} =~ /^\d+$/;
    return { error => 1, content => "amount must be a positive number" } unless $order{amount} =~ /^\d*(\.\d+)?$/ && $order{amount} > 0;
    return { error => 1, content => "type must be 'buy' or 'sell'" } unless $order{type} eq 'buy' || $order{type} eq 'sell';
    return { error => 1, content => "symbol must not be empty" } if !length $order{symbol};


    my $order_to_store = {
        user_id    => $order{user_id},
        symbol     => $order{symbol},
        order_type => $order{type},
        price      => 1.00,
        quantity   => $order{amount},
        status     => 'executed', # Assuming immediate execution for this demo
    };

    try {
        my $res = await $dbh->query(
            q{
                INSERT INTO trading.orders (user_id, symbol, order_type, price, quantity, timestamp, status)
                VALUES ($1, $2, $3, $4, $5, NOW(), $6)
                RETURNING order_id, timestamp, status
            },
            $order_to_store->{user_id}, $order_to_store->{symbol}, $order_to_store->{order_type},
            $order_to_store->{price}, $order_to_store->{quantity}, $order_to_store->{status}
        )->row_hashrefs->first;

        if (!$res || !$res->{order_id}) {
            $log->errorf("Failed to store order for user %s: No order_id returned", $order{user_id});
            return { error => 1, content => "Failed to store order in database" };
        }

        $order{order_id} = $res->{order_id};
        $order{timestamp} = $res->{timestamp}; # This will be a string representation from DB
        $order{state} = $res->{status}; # Update state from DB in case it's different

        $events->emit(\%order); # Emit the augmented order data
        $log->infof('Stored and emitted order %s', encode_json_utf8(\%order));
        return { success => 1, content => \%order };

    } catch ($e) {
        $log->errorf("Error storing order for user %s: %s", $order{user_id}, $e);
        return { error => 1, content => "Error storing order: $e" };
    }
}

async method get_order_details : RPC (%args) {
    my $order_id = $args{order_id};
    return { error => 1, content => "order_id must be defined" } unless defined $order_id;
    return { error => 1, content => "order_id must be an integer" } unless $order_id =~ /^\d+$/;

    try {
        my $order_details = await $dbh->query(
            q{SELECT order_id, user_id, symbol, order_type, price, quantity, timestamp, status FROM trading.orders WHERE order_id = $1},
            $order_id
        )->row_hashrefs->first;

        if ($order_details) {
            return { success => 1, content => $order_details };
        } else {
            return { error => 1, content => "Order not found" };
        }
    } catch ($e) {
        $log->errorf("Error fetching order details for ID %s: %s", $order_id, $e);
        return { error => 1, content => "Error fetching order details: $e" };
    }
}

async method publish_trade_event : Emitter() ($sink) {
    $sink->from($events);
    await $sink->source->completed;
}

1;

