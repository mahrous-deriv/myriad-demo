package Deriv::Service::Reporting;

use Myriad::Service;
use Ryu::Source;

has $count = 0;
has $value;
has $call_event_handler = Ryu::Source->new;

async method diagnostics ($level) {
    return 'ok';
}

async method current : RPC {
    return { value => $value, count => $count};
}

async method update : RPC (%args) {

    $value = $args{new_value};
    $count = 0 if $args{reset};
    $call_event_handler->emit(1);
    return await $self->current;

}


async method value_updated : Emitter() ($sink, $api, %args){
    $call_event_handler->each(sub {
        my $emit = shift;
        my $e = {name => "EMITTER-Trigger service", value => $value, count => ++$count};
        $sink->emit($e) if $emit;
    });
}

1;