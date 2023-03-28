module sui_mamoru_relay::validators {
    friend sui_mamoru_relay::incidents;

    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    /// Represents a registry of validators.
    /// We store addresses instead of using capabilities
    /// because we want to be able to remove validators from the registry.
    struct ValidatorRegistry has key {
        id: UID,
        validators: Table<address, bool>,
    }

    /// The capability to add/remove validators from a registry.
    struct ValidatorRegistryOwnerCap has key {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        init_module(ctx);
    }

    public(friend) fun init_for_test(ctx: &mut TxContext) {
        init_module(ctx);
    }

    /// The function to bypass `init` function visibility restrictions.
    fun init_module(ctx: &mut TxContext) {
        let registry = ValidatorRegistry {
            id: object::new(ctx),
            validators: table::new(ctx),
        };
        let owner_cap = ValidatorRegistryOwnerCap {
            id: object::new(ctx),
        };

        transfer::share_object(registry);
        transfer::transfer(owner_cap, tx_context::sender(ctx));
    }

    /// Adds validator to a registry.
    ///
    /// `ValidatorRegistryOwnerCap` ensures that only the owner of the registry can add validators.
    /// Aborts if validator is already in the registry.
    public entry fun register_validator(
        _: &ValidatorRegistryOwnerCap,
        registry: &mut ValidatorRegistry,
        validator: address,
    ) {
        table::add(&mut registry.validators, validator, true);
    }

    /// Removes validator from a registry.
    ///
    /// `ValidatorRegistryOwnerCap` ensures that only the owner of the registry can remove validators.
    /// Aborts if validator is not in the registry.
    public entry fun unregister_validator(
        _: &ValidatorRegistryOwnerCap,
        registry: &mut ValidatorRegistry,
        validator: address,
    ) {
        table::remove(&mut registry.validators, validator);
    }

    /// Checks if validator is in the registry.
    public fun is_validator(registry: &ValidatorRegistry, validator: address): bool {
        table::contains(&registry.validators, validator)
    }

    #[test]
    fun register_validator_ok() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator_addr = @0x0;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, admin);
        {
            init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let cap = test_scenario::take_from_sender<ValidatorRegistryOwnerCap>(scenario);
            let registry = test_scenario::take_shared<ValidatorRegistry>(scenario);

            register_validator(&cap, &mut registry, validator_addr);
            assert!(table::contains(&mut registry.validators, validator_addr), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = sui::dynamic_field::EFieldAlreadyExists)]
    fun register_validator_already_registered() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator_addr = @0x0;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, admin);
        {
            init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let cap = test_scenario::take_from_sender<ValidatorRegistryOwnerCap>(scenario);
            let registry = test_scenario::take_shared<ValidatorRegistry>(scenario);

            register_validator(&cap, &mut registry, validator_addr);
            register_validator(&cap, &mut registry, validator_addr);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun unregister_validator_ok() {
        use sui::test_scenario;

        let admin = @0xAD014;
        let validator_addr = @0x0;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, admin);
        {
            init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let cap = test_scenario::take_from_sender<ValidatorRegistryOwnerCap>(scenario);
            let registry = test_scenario::take_shared<ValidatorRegistry>(scenario);

            register_validator(&cap, &mut registry, validator_addr);
            assert!(table::contains(&mut registry.validators, validator_addr), 1);

            unregister_validator(&cap, &mut registry, validator_addr);
            assert!(!table::contains(&mut registry.validators, validator_addr), 2);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = sui::dynamic_field::EFieldDoesNotExist)]
    fun unregister_validator_not_registered() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator_addr = @0x0;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, admin);
        {
            init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let cap = test_scenario::take_from_sender<ValidatorRegistryOwnerCap>(scenario);
            let registry = test_scenario::take_shared<ValidatorRegistry>(scenario);

            unregister_validator(&cap, &mut registry, validator_addr);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(registry);
        };

        test_scenario::end(scenario_val);
    }
}
