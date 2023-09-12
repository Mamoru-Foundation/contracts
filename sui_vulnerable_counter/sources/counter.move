// Taken from https://github.com/MystenLabs/sui/blob/ee9272b0c34f74d99f68ae83fda816305c60ec97/sui_programmability/examples/basics/sources/counter.move
// and modified to be vulnerable.
module vulnerable_counter::counter {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    /// A shared counter.
    struct Counter has key {
        id: UID,
        owner: address,
        value: u64
    }

    public fun owner(counter: &Counter): address {
        counter.owner
    }

    public fun value(counter: &Counter): u64 {
        counter.value
    }

    /// Create and share a Counter object.
    public entry fun create(ctx: &mut TxContext) {
        transfer::share_object(Counter {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            value: 0
        })
    }

    /// Increment a counter by 1.
    public entry fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
    }

    /// Set value (should only be runnable by the Counter owner)
    public entry fun set_value(counter: &mut Counter, value: u64, _ctx: &TxContext) {
        // Leaving this check commented to demonstrate the vulnerability.
        // assert!(counter.owner == tx_context::sender(ctx), 0);
        counter.value = value;
    }

    /// Assert a value for the counter.
    public entry fun assert_value(counter: &Counter, value: u64) {
        assert!(counter.value == value, 0)
    }
}

#[test_only]
module vulnerable_counter::counter_test {
    use sui::test_scenario;
    use vulnerable_counter::counter;

    #[test]
    fun test_counter() {
        let owner = @0xC0FFEE;
        let user1 = @0xA1;

        let scenario_val = test_scenario::begin(user1);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            counter::create(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, user1);
        {
            let counter_val = test_scenario::take_shared<counter::Counter>(scenario);
            let counter = &mut counter_val;

            assert!(counter::owner(counter) == owner, 0);
            assert!(counter::value(counter) == 0, 1);

            counter::increment(counter);
            counter::increment(counter);
            counter::increment(counter);
            test_scenario::return_shared(counter_val);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let counter_val = test_scenario::take_shared<counter::Counter>(scenario);
            let counter = &mut counter_val;

            assert!(counter::owner(counter) == owner, 0);
            assert!(counter::value(counter) == 3, 1);

            counter::set_value(counter, 100, test_scenario::ctx(scenario));

            test_scenario::return_shared(counter_val);
        };

        test_scenario::next_tx(scenario, user1);
        {
            let counter_val = test_scenario::take_shared<counter::Counter>(scenario);
            let counter = &mut counter_val;

            assert!(counter::owner(counter) == owner, 0);
            assert!(counter::value(counter) == 100, 1);

            counter::increment(counter);

            assert!(counter::value(counter) == 101, 2);

            test_scenario::return_shared(counter_val);
        };
        test_scenario::end(scenario_val);
    }
}
