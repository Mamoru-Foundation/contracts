module aptos_mamoru_relay::incidents {
    use std::string::String;
    use aptos_mamoru_relay::validators::{is_validator};
    use std::vector;
    use std::option;
    use aptos_std::table::Table;
    use std::signer;
    use aptos_std::table;
    use aptos_mamoru_relay::iterable_table::{IterableTable, Self};

    /// Error: only validators can use this action.
    const ERegistryIsNotInitialized: u64 = 1200;
    const ESenderIsNotValidator: u64 = 1201;
    const ENotEnoughPermissions: u64 = 1202;

    /// Severity levels to use instead of numbers.
    const IncidentSeverityInfo: u8 = 0;
    const IncidentSeverityWarning: u8 = 1;
    const IncidentSeverityError: u8 = 2;
    const IncidentSeverityAlert: u8 = 3;

    /// The registry that stores all incidents.
    struct DaemonIncidentRegistry has key {
        // vector<u8> is a Daemon ID
        daemons: Table<vector<u8>, DaemonIncidentList>,
    }

    /// A list of incidents for a specific daemon.
    struct DaemonIncidentList has store {
        incidents: IterableTable<String, Incident>,
    }

    /// The Mamoru Incident.
    struct Incident has store, copy, drop {
        /// The incident id as it is in Mamoru.
        id: String,

        /// The incident severity.
        /// See `IncidentSeverity*` constants for available values.
        severity: u8,

        /// The address of the contract that caused the incident.
        /// This field is defined by a daemon.
        address: String,

        /// The custom data that is attached to the incident.
        /// This field is defined by a daemon.
        data: vector<u8>,

        /// The unix timestamp in milliseconds when the incident was created.
        /// This field is set by Mamoru.
        created_at: u64,

        /// The list of validators that reported the incident.
        ///
        /// NOTE: validators may report different incident payload for the same incident id.
        /// The returned payload is the first one reported.
        reported_by: vector<address>,
    }

    /// Initializes the validator registry.
    /// Can only be called by the owner of the registry.
    public entry fun initialize(aptos_mamoru_relay: &signer) {
        assert!(signer::address_of(aptos_mamoru_relay) == @aptos_mamoru_relay, ENotEnoughPermissions);

        let registry = DaemonIncidentRegistry {
            daemons: table::new(),
        };

        move_to(aptos_mamoru_relay, registry)
    }

    /// Reports an incident.
    /// This action can only be called by a Mamoru Validator.
    public entry fun report_incident(
        sender: &signer,
        daemon_id: vector<u8>,
        incident_id: String,
        severity: u8,
        address: String,
        data: vector<u8>,
        created_at: u64,
    ) acquires DaemonIncidentRegistry {
        let sender_addr = signer::address_of(sender);
        assert!(is_validator(sender_addr), ESenderIsNotValidator);
        assert!(exists<DaemonIncidentRegistry>(@aptos_mamoru_relay), ERegistryIsNotInitialized);

        let incident_registry = borrow_global_mut<DaemonIncidentRegistry>(@aptos_mamoru_relay);

        if (!table::contains(&incident_registry.daemons, daemon_id)) {
            table::add(&mut incident_registry.daemons, daemon_id, DaemonIncidentList {
                incidents: iterable_table::new(),
            });
        };

        let daemon_incident_list = table::borrow_mut(&mut incident_registry.daemons, daemon_id);

        if (iterable_table::contains(&daemon_incident_list.incidents, incident_id)) {
            let incident = iterable_table::borrow_mut(&mut daemon_incident_list.incidents, incident_id);

            vector::push_back(&mut incident.reported_by, sender_addr);
        } else {
            let reported_by = vector::empty<address>();
            vector::push_back(&mut reported_by, sender_addr);

            iterable_table::add(&mut daemon_incident_list.incidents, incident_id, Incident {
                id: incident_id,
                severity,
                address,
                data,
                created_at,
                reported_by,
            });
        }
    }

    /// Returns `max_count` incidents for the given daemon id since the given timestamp.
    /// The timestamp must be a unix timestamp in milliseconds.
    /// Note: the function returns the incidents in the reverse order, so the latest incident is the first in the result.
    public fun get_incidents_since(
        daemon_id: vector<u8>,
        since: u64,
        max_count: u64,
    ): vector<Incident> acquires DaemonIncidentRegistry {
        assert!(exists<DaemonIncidentRegistry>(@aptos_mamoru_relay), ERegistryIsNotInitialized);

        let incident_registry = borrow_global<DaemonIncidentRegistry>(@aptos_mamoru_relay);
        let incidents = vector::empty<Incident>();

        if (!table::contains(&incident_registry.daemons, daemon_id)) {
            // No incidents found for this daemon.
            return incidents
        };

        let daemon_incident_list = table::borrow(&incident_registry.daemons, daemon_id);

        // get the latest incident for the daemon
        let maybe_incident_id = iterable_table::tail_key(&daemon_incident_list.incidents);

        while (option::is_some(&maybe_incident_id)) {
            let incident_id = *option::borrow(&maybe_incident_id);
            let (incident, prev, _) = iterable_table::borrow_iter(&daemon_incident_list.incidents, incident_id);

            if (is_incident_in_range(incident, since)) {
                // if the incident is new enough, add it to the result
                vector::push_back(&mut incidents, *incident);

                // see if there are any more incidents
                maybe_incident_id = prev;
            } else {
                // otherwise, no need to continue, as new incidents are added to the end of the list
                break
            };

            if (vector::length(&incidents) >= max_count) {
                break
            };
        };

        incidents
    }

    /// Returns if there are any incidents for the given daemon id since the given timestamp.
    /// The timestamp must be a unix timestamp in milliseconds.
    /// The function is cheaper then `get_incidents_since` as it doesn't need to return the actual incidents.
    public fun has_incidents_since(
        daemon_id: vector<u8>,
        since: u64,
    ): bool acquires DaemonIncidentRegistry {
        assert!(exists<DaemonIncidentRegistry>(@aptos_mamoru_relay), ERegistryIsNotInitialized);

        let incident_registry = borrow_global<DaemonIncidentRegistry>(@aptos_mamoru_relay);

        if (!table::contains(&incident_registry.daemons, daemon_id)) {
            // No incidents found for this daemon.
            return false
        };

        let daemon_incident_list = table::borrow(&incident_registry.daemons, daemon_id);
        let maybe_incident_id = iterable_table::tail_key(&daemon_incident_list.incidents);

        if (option::is_none(&maybe_incident_id)) {
            // No incidents found for this daemon.
            return false
        };

        let incident_id = *option::borrow(&maybe_incident_id);
        let incident = iterable_table::borrow(&daemon_incident_list.incidents, incident_id);

        is_incident_in_range(incident, since)
    }

    fun is_incident_in_range(incident: &Incident, since: u64): bool {
        incident.created_at >= since
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun report_incident_ok_empty_state(admin: signer, validator: signer) acquires DaemonIncidentRegistry {
        let validator_addr = signer::address_of(&validator);
        let admin_addr = signer::address_of(&admin);
        init_test_env(&admin, vector::singleton(validator_addr));

        let test_daemon_id = report_test_incidents(&validator, 1);
        let incident_registry = borrow_global<DaemonIncidentRegistry>(admin_addr);

        let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
        assert!(iterable_table::length(&incidents.incidents) == 1, 0);
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun report_incident_ok_existing_state(admin: signer, validator: signer) acquires DaemonIncidentRegistry {
        let validator_addr = signer::address_of(&validator);
        let admin_addr = signer::address_of(&admin);
        init_test_env(&admin, vector::singleton(validator_addr));

        let total_incidents: u64 = 3;
        let test_daemon_id = report_test_incidents(&validator, total_incidents);

        let incident_registry = borrow_global<DaemonIncidentRegistry>(admin_addr);
        let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
        assert!(iterable_table::length(&incidents.incidents) == total_incidents, 0);
    }


    #[test(admin = @aptos_mamoru_relay, validator = @0x0, not_validator = @0x1)]
    #[expected_failure(abort_code = ESenderIsNotValidator)]
    fun report_incident_fails_invalid_validator(
        admin: signer,
        validator: signer,
        not_validator: signer
    ) acquires DaemonIncidentRegistry {
        let validator_addr = signer::address_of(&validator);
        init_test_env(&admin, vector::singleton(validator_addr));

        _ = report_test_incidents(&not_validator, 1);
    }


    #[test(admin = @aptos_mamoru_relay, validator1 = @0x0, validator2 = @0x1)]
    fun report_incident_ok_multiple_reporters(admin: signer,
                                              validator1: signer,
                                              validator2: signer) acquires DaemonIncidentRegistry {
        use std::string;

        let admin_addr = signer::address_of(&admin);
        let validator1_addr = signer::address_of(&validator1);
        let validator2_addr = signer::address_of(&validator2);

        let validators = vector::empty<address>();
        vector::push_back(&mut validators, validator1_addr);
        vector::push_back(&mut validators, validator2_addr);

        init_test_env(&admin, validators);

        report_test_incidents(&validator1, 1);
        let test_daemon_id = report_test_incidents(&validator2, 1);

        let incident_id = string::utf8(vector::singleton<u8>(0));

        let incident_registry = borrow_global<DaemonIncidentRegistry>(admin_addr);

        let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
        assert!(iterable_table::length(&incidents.incidents) == 1, 0);

        let reported_incident = iterable_table::borrow(&incidents.incidents, incident_id);

        assert!(vector::length(&reported_incident.reported_by) == 2, 1);
        assert!(vector::contains(&reported_incident.reported_by, &validator1_addr), 2);
        assert!(vector::contains(&reported_incident.reported_by, &validator2_addr), 3);
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun get_incidents_since_ok(
        admin: signer,
        validator: signer,
    ) acquires DaemonIncidentRegistry {
        let admin_addr = signer::address_of(&admin);
        let validator_addr = signer::address_of(&validator);

        init_test_env(&admin, vector::singleton(validator_addr));
        let total_incidents: u64 = 3;
        let test_daemon_id = report_test_incidents(&validator, total_incidents);

        {
            let incident_registry = borrow_global<DaemonIncidentRegistry>(admin_addr);

            let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
            // should have `total_incidents` in the registry
            assert!(iterable_table::length(&incidents.incidents) == total_incidents, 0);
        };

        {
            let incidents_since = get_incidents_since(test_daemon_id, 0, total_incidents);
            // should return all incidents
            assert!(vector::length(&incidents_since) == total_incidents, 1);
        };

        {
            let incidents_since = get_incidents_since(test_daemon_id, 0, 2);
            // should return 2 as per `max_count` limit
            assert!(vector::length(&incidents_since) == 2, 2);
        };

        {
            let incidents_since = get_incidents_since(test_daemon_id, 1, total_incidents);
            // should return all incidents except the first one
            assert!(vector::length(&incidents_since) == (total_incidents - 1), 3);
        };

        {
            let incidents_since = get_incidents_since(
                test_daemon_id,
                total_incidents + 1,
                total_incidents
            );
            // should return no incidents since `total_incidents + 1`
            assert!(vector::length(&incidents_since) == 0, 4);
        };
    }

    #[test(admin = @aptos_mamoru_relay)]
    fun get_incidents_since_empty_state(
        admin: signer,
    ) acquires DaemonIncidentRegistry {
        init_test_env(&admin, vector::empty());

        let incidents_since = get_incidents_since(b"test_daemon_id", 0, 1);
        // should return no incidents
        assert!(vector::length(&incidents_since) == 0, 0);
    }


    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun has_incidents_since_ok(admin: signer, validator: signer) acquires DaemonIncidentRegistry {
        let admin_addr = signer::address_of(&admin);
        let validator_addr = signer::address_of(&validator);
        init_test_env(&admin, vector::singleton(validator_addr));

        let total_incidents: u64 = 3;
        let test_daemon_id = report_test_incidents(&validator, total_incidents);

        {
            let incident_registry = borrow_global<DaemonIncidentRegistry>(admin_addr);

            let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
            // should have `total_incidents` in the registry
            assert!(iterable_table::length(&incidents.incidents) == total_incidents, 0);
        };

        let has_incidents_since = has_incidents_since(test_daemon_id, 0);
        assert!(has_incidents_since, 1);

        let has_incidents_since2 = has_incidents_since(test_daemon_id, 1);
        assert!(has_incidents_since2, 2);

        let has_incidents_since3 = has_incidents_since(test_daemon_id, total_incidents + 1);
        // no incidents since `total_incidents + 1`
        assert!(!has_incidents_since3, 3);
    }

    #[test(admin = @aptos_mamoru_relay, validator = @0x0)]
    fun has_incidents_since_empty_state(admin: signer, validator: signer) acquires DaemonIncidentRegistry {
        let validator_addr = signer::address_of(&validator);

        init_test_env(&admin, vector::singleton(validator_addr));

        let has_incidents_since = has_incidents_since(b"test_daemon_id", 0);
        // no incidents were reported for this daemon
        assert!(!has_incidents_since, 0);
    }

    #[test_only]
    fun init_test_env(admin: &signer, validators: vector<address>) {
        initialize(admin);
        aptos_mamoru_relay::validators::initialize(admin);

        let v = 0;

        while (v < vector::length(&validators)) {
            aptos_mamoru_relay::validators::register_validator(
                admin,
                *vector::borrow(&validators, v),
            );

            v = v + 1;
        };
    }

    #[test_only]
    fun report_test_incidents(creator: &signer, amount: u64): vector<u8> acquires DaemonIncidentRegistry {
        use std::string;

        assert!(amount > 0, 42);
        let test_daemon_id = b"test_daemon_id";

        let i = 0;
        while ((i as u64) < amount) {
            let mamoru_id = vector::empty<u8>();
            vector::push_back(&mut mamoru_id, i);

            report_incident(
                creator,
                test_daemon_id,
                string::utf8(mamoru_id),
                IncidentSeverityInfo,
                string::utf8(b"cosmos"),
                vector::empty<u8>(),
                (i as u64),
            );

            i = i + 1;
        };

        test_daemon_id
    }
}
