// homework
#[starknet::interface]
pub trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
}

#[starknet::contract]
pub mod counter_contract {
    use workshop::counter::ICounter;
    use starknet::ContractAddress;
    use kill_switch::IKillSwitchDispatcher;
    use kill_switch::IKillSwitchDispatcherTrait;
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        value: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            let value = self.counter.read();
            return value;
        }


        fn increase_counter(ref self: ContractState) {

            self.ownable.assert_only_owner();

            let kill_switch_address = self.kill_switch.read();
            let dispatcher = IKillSwitchDispatcher { contract_address: kill_switch_address };
            let is_active = dispatcher.is_active();

            assert!(!is_active, "Kill Switch is active");
            let value = self.counter.read();
            self.counter.write(value + 1);
            self.emit(CounterIncreased { value: self.counter.read() });
            
        }
    }
}
