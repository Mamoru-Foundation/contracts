module aptos_mamoru_relay::validators {
    friend aptos_mamoru_relay::incidents;

    use aptos_std::table::{Self, Table};
    use std::signer;

    const ENotEnoughPermissions: u64 = 1300;
    const ERegistryNotInitialized: u64 = 1301;
    const EValidatorAlreadyRegistered: u64 = 1302;
    const EValidatorNotRegistered: u64 = 1303;

    /// Represents a registry of validators.
    /// We store addresses instead of using capabilities
    /// because we want to be able to remove validators from the registry.
    struct ValidatorRegistry has key {
        validators: Table<address, bool>,
    }

    /// The capability to add/remove validators from a registry.
    struct ValidatorRegistryOwnerCap has key {}

    /// Initializes the validator registry.
    /// Can only be called by the owner of the registry.
    public entry fun initialize(aptos_mamoru_relay: &signer) {
        assert!(signer::address_of(aptos_mamoru_relay) == @aptos_mamoru_relay, ENotEnoughPermissions);

        let registry = ValidatorRegistry {
            validators: table::new(),
        };

        move_to(aptos_mamoru_relay, registry);
        move_to(aptos_mamoru_relay, ValidatorRegistryOwnerCap {});
    }

    /// Adds validator to a registry.
    ///
    /// `ValidatorRegistryOwnerCap` ensures that only the owner of the registry can add validators.
    /// Aborts if validator is already in the registry.
    public entry fun register_validator(
        sender: &signer,
        validator: address,
    ) acquires ValidatorRegistry {
        assert!(exists<ValidatorRegistry>(@aptos_mamoru_relay), ERegistryNotInitialized);
        assert!(exists<ValidatorRegistryOwnerCap>(signer::address_of(sender)), ENotEnoughPermissions);

        let registry = borrow_global_mut<ValidatorRegistry>(@aptos_mamoru_relay);

        assert!(!table::contains(&registry.validators, validator), EValidatorAlreadyRegistered);

        table::add(&mut registry.validators, validator, true);
    }

    /// Removes validator from a registry.
    ///
    /// `ValidatorRegistryOwnerCap` ensures that only the owner of the registry can remove validators.
    /// Aborts if validator is not in the registry.
    public entry fun unregister_validator(
        sender: &signer,
        validator: address,
    ) acquires ValidatorRegistry {
        assert!(exists<ValidatorRegistry>(@aptos_mamoru_relay), ERegistryNotInitialized);
        assert!(exists<ValidatorRegistryOwnerCap>(signer::address_of(sender)), ENotEnoughPermissions);

        let registry = borrow_global_mut<ValidatorRegistry>(@aptos_mamoru_relay);

        assert!(table::contains(&registry.validators, validator), EValidatorNotRegistered);

        table::remove(&mut registry.validators, validator);
    }

    /// Checks if validator is in the registry.
    public fun is_validator(validator: address): bool
    acquires ValidatorRegistry {
        assert!(exists<ValidatorRegistry>(@aptos_mamoru_relay), ERegistryNotInitialized);

        let registry = borrow_global<ValidatorRegistry>(@aptos_mamoru_relay);
        table::contains(&registry.validators, validator)
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun register_validator_ok(admin: signer, validator: signer) acquires ValidatorRegistry {
        use aptos_framework::account;

        let admin_addr = signer::address_of(&admin);
        let validator_addr = signer::address_of(&validator);

        account::create_account_for_test(signer::address_of(&admin));

        initialize(&admin);
        register_validator(&admin, validator_addr);

        let registry = borrow_global<ValidatorRegistry>(admin_addr);

        assert!(table::contains(&registry.validators, validator_addr), 1);
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    #[expected_failure(abort_code = EValidatorAlreadyRegistered)]
    fun register_validator_already_registered(admin: signer, validator: signer) acquires ValidatorRegistry {
        use aptos_framework::account;

        let validator_addr = signer::address_of(&validator);

        account::create_account_for_test(signer::address_of(&admin));

        initialize(&admin);
        register_validator(&admin, validator_addr);
        register_validator(&admin, validator_addr);
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun unregister_validator_ok(admin: signer, validator: signer) acquires ValidatorRegistry {
        use aptos_framework::account;

        let admin_addr = signer::address_of(&admin);
        let validator_addr = signer::address_of(&validator);

        account::create_account_for_test(signer::address_of(&admin));

        initialize(&admin);

        register_validator(&admin, validator_addr);
        {
            let registry = borrow_global<ValidatorRegistry>(admin_addr);
            assert!(table::contains(&registry.validators, validator_addr), 1);
        };

        unregister_validator(&admin, validator_addr);
        {
            let registry = borrow_global<ValidatorRegistry>(admin_addr);
            assert!(!table::contains(&registry.validators, validator_addr), 2);
        };
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    #[expected_failure(abort_code = EValidatorNotRegistered)]
    fun unregister_validator_not_registered(admin: signer, validator: signer) acquires ValidatorRegistry {
        use aptos_framework::account;

        let validator_addr = signer::address_of(&validator);

        account::create_account_for_test(signer::address_of(&admin));

        initialize(&admin);
        unregister_validator(&admin, validator_addr);
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun is_validator_ok(admin: signer, validator: signer) acquires ValidatorRegistry {
        use aptos_framework::account;

        let validator_addr = signer::address_of(&validator);

        account::create_account_for_test(signer::address_of(&admin));

        initialize(&admin);
        register_validator(&admin, validator_addr);

        assert!(is_validator(validator_addr), 1);
    }
}
