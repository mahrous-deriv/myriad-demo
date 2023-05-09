package Deriv::Service::Payment;

use Myriad::Service;

has $timer;

async method startup () {
    $timer = 10;
}

async method diagnostics ($level) {
    return 'ok' if defined $timer;
}

async method current_timer : RPC (%args) {
    return $timer;
}

async method next_batch : Batch () {
    $log->infof('Hello');
    await $self->loop->delay_future(after => $timer);
    return [];

}

1;
