package Deriv::Service::Payment;

# Simple batch method example.

use Myriad::Service;

has $count = 0;

async method diagnostics ($level) {
    return 'ok';
}

async method current : RPC {
    return $count;
}

async method next_batch : Batch {
    my $srv = await $api->service_by_name('myriad.example.call'); 
    my $res = await $srv->target_method;
    $log->infof("Three got %s", $res);
    return 
}

1;