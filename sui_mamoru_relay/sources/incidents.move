module sui_mamoru_relay::incidents {
    use sui::object::{Self, UID};
    use sui::linked_table::{Self, LinkedTable};
    use std::string::String;
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::tx_context;
    use sui_mamoru_relay::validators::{is_validator, ValidatorRegistry};
    use std::vector;
    use std::option;

    #[test_only]
    use sui::test_scenario::{Self, Scenario};

    /// Error: only validators can use this action.
    const ESenderIsNotValidator: u64 = 0;

    /// Severity levels to use instead of numbers.
    const IncidentSeverityInfo: u8 = 0;
    const IncidentSeverityWarning: u8 = 1;
    const IncidentSeverityError: u8 = 2;
    const IncidentSeverityAlert: u8 = 3;

    /// The registry that stores all incidents.
    struct DaemonIncidentRegistry has key {
        id: UID,
        // vector<u8> is a Daemon ID
        daemons: Table<vector<u8>, DaemonIncidentList>,
    }

    /// A list of incidents for a specific daemon.
    struct DaemonIncidentList has store {
        incidents: LinkedTable<String, Incident>,
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

    fun init(ctx: &mut TxContext) {
        let registry = DaemonIncidentRegistry {
            id: object::new(ctx),
            daemons: table::new(ctx),
        };

        transfer::share_object(registry);
    }

    /// Reports an incident.
    /// This action can only be called by a Mamoru Validator.
    /// The function is `entry`, so it can be called directly in a transaction.
    public entry fun report_incident(
        validator_registry: &ValidatorRegistry,
        incident_registry: &mut DaemonIncidentRegistry,
        daemon_id: vector<u8>,
        incident_id: String,
        severity: u8,
        address: String,
        data: vector<u8>,
        created_at: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(is_validator(validator_registry, sender), ESenderIsNotValidator);

        if (!table::contains(&incident_registry.daemons, daemon_id)) {
            table::add(&mut incident_registry.daemons, daemon_id, DaemonIncidentList {
                incidents: linked_table::new(ctx),
            });
        };

        let daemon_incident_list = table::borrow_mut(&mut incident_registry.daemons, daemon_id);

        if (linked_table::contains(&daemon_incident_list.incidents, incident_id)) {
            let incident = linked_table::borrow_mut(&mut daemon_incident_list.incidents, incident_id);

            vector::push_back(&mut incident.reported_by, sender);
        } else {
            let reported_by = vector::empty<address>();
            vector::push_back(&mut reported_by, sender);

            linked_table::push_back(&mut daemon_incident_list.incidents, incident_id, Incident {
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
        incident_registry: &DaemonIncidentRegistry,
        daemon_id: vector<u8>,
        since: u64,
        max_count: u64,
    ): vector<Incident> {
        let incidents = vector::empty<Incident>();

        if (!table::contains(&incident_registry.daemons, daemon_id)) {
            // No incidents found for this daemon.
            return incidents
        };

        let daemon_incident_list = table::borrow(&incident_registry.daemons, daemon_id);

        // get the latest incident for the daemon
        let maybe_incident_id = linked_table::back(&daemon_incident_list.incidents);

        while (option::is_some(maybe_incident_id)) {
            let incident_id = *option::borrow(maybe_incident_id);
            let incident = linked_table::borrow(&daemon_incident_list.incidents, incident_id);

            if (is_incident_in_range(incident, since)) {
                // if the incident is new enough, add it to the result
                vector::push_back(&mut incidents, *incident);

                // see if there are any more incidents
                maybe_incident_id = linked_table::prev(&daemon_incident_list.incidents, incident_id);
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
        incident_registry: &DaemonIncidentRegistry,
        daemon_id: vector<u8>,
        since: u64,
    ): bool {
        if (!table::contains(&incident_registry.daemons, daemon_id)) {
            // No incidents found for this daemon.
            return false
        };

        let daemon_incident_list = table::borrow(&incident_registry.daemons, daemon_id);
        let maybe_incident_id = linked_table::back(&daemon_incident_list.incidents);

        if (option::is_none(maybe_incident_id)) {
            // No incidents found for this daemon.
            return false
        };

        let incident_id = *option::borrow(maybe_incident_id);
        let incident = linked_table::borrow(&daemon_incident_list.incidents, incident_id);

        is_incident_in_range(incident, since)
    }

    fun is_incident_in_range(incident: &Incident, since: u64): bool {
        incident.created_at >= since
    }

    #[test]
    fun report_incident_ok_empty_state() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator = @0xCAFF;

        let scenario_val = init_test_env(admin, vector::singleton(validator));
        let scenario = &mut scenario_val;

        let test_daemon_id = report_test_incidents(scenario, validator, 1);

        test_scenario::next_tx(scenario, validator);
        {
            let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

            let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
            assert!(linked_table::length(&incidents.incidents) == 1, 0);

            test_scenario::return_shared(incident_registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun report_incident_ok_existing_state() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator = @0xCAFF;

        let scenario_val = init_test_env(admin, vector::singleton(validator));
        let scenario = &mut scenario_val;
        let total_incidents: u64 = 3;
        let test_daemon_id = report_test_incidents(scenario, validator, total_incidents);

        test_scenario::next_tx(scenario, validator);
        {
            let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

            let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
            assert!(linked_table::length(&incidents.incidents) == total_incidents, 0);

            test_scenario::return_shared(incident_registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = ESenderIsNotValidator)]
    fun report_incident_fails_invalid_validator() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator = @0xCAFF;
        let not_validator = @0xCAF0;

        let scenario_val = init_test_env(admin, vector::singleton(validator));
        let scenario = &mut scenario_val;

        let _ = report_test_incidents(scenario, not_validator, 1);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun report_incident_ok_multiple_reporters() {
        use sui::test_scenario;
        use std::string;

        let admin = @0xCAFE;
        let validator1 = @0xCAFF;
        let validator2 = @0xCAF1;

        let validators = vector::empty<address>();
        vector::push_back(&mut validators, validator1);
        vector::push_back(&mut validators, validator2);

        let scenario_val = init_test_env(admin, validators);
        let scenario = &mut scenario_val;

        let _ = report_test_incidents(scenario, validator1, 1);
        let test_daemon_id = report_test_incidents(scenario, validator2, 1);

        let incident_id = string::utf8(vector::singleton<u8>(0));

        test_scenario::next_tx(scenario, admin);
        {
            let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

            let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
            assert!(linked_table::length(&incidents.incidents) == 1, 0);

            let reported_incident = linked_table::borrow(&incidents.incidents, incident_id);

            assert!(vector::length(&reported_incident.reported_by) == 2, 1);
            assert!(vector::contains(&reported_incident.reported_by, &validator1), 2);
            assert!(vector::contains(&reported_incident.reported_by, &validator2), 3);

            test_scenario::return_shared(incident_registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun get_incidents_since_ok() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator = @0xCAFF;
        let not_validator = @0xCAF0;

        let scenario_val = init_test_env(admin, vector::singleton(validator));
        let scenario = &mut scenario_val;
        let total_incidents: u64 = 3;
        let test_daemon_id = report_test_incidents(scenario, validator, total_incidents);

        test_scenario::next_tx(scenario, not_validator);
        {
            let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

            let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
            // should have `total_incidents` in the registry
            assert!(linked_table::length(&incidents.incidents) == total_incidents, 0);

            {
                let incidents_since = get_incidents_since(&incident_registry, test_daemon_id, 0, total_incidents);
                // should return all incidents
                assert!(vector::length(&incidents_since) == total_incidents, 1);
            };

            {
                let incidents_since = get_incidents_since(&incident_registry, test_daemon_id, 0, 2);
                // should return 2 as per `max_count` limit
                assert!(vector::length(&incidents_since) == 2, 2);
            };

            {
                let incidents_since = get_incidents_since(&incident_registry, test_daemon_id, 1, total_incidents);
                // should return all incidents except the first one
                assert!(vector::length(&incidents_since) == (total_incidents - 1), 3);
            };

            {
                let incidents_since = get_incidents_since(
                    &incident_registry,
                    test_daemon_id,
                    total_incidents + 1,
                    total_incidents
                );
                // should return no incidents since `total_incidents + 1`
                assert!(vector::length(&incidents_since) == 0, 4);
            };

            test_scenario::return_shared(incident_registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun get_incidents_since_empty_state() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator = @0xCAFF;
        let not_validator = @0xCAF0;

        let scenario_val = init_test_env(admin, vector::singleton(validator));
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, not_validator);
        {
            let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

            let incidents_since = get_incidents_since(&incident_registry, b"test_daemon_id", 0, 1);
            // should return no incidents
            assert!(vector::length(&incidents_since) == 0, 0);

            test_scenario::return_shared(incident_registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun has_incidents_since_ok() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator = @0xCAFF;
        let not_validator = @0xCAF0;

        let scenario_val = init_test_env(admin, vector::singleton(validator));
        let scenario = &mut scenario_val;
        let total_incidents: u64 = 3;
        let test_daemon_id = report_test_incidents(scenario, validator, total_incidents);

        test_scenario::next_tx(scenario, not_validator);
        {
            let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

            let incidents = table::borrow(&incident_registry.daemons, test_daemon_id);
            // should have `total_incidents` in the registry
            assert!(linked_table::length(&incidents.incidents) == total_incidents, 0);

            let has_incidents_since = has_incidents_since(&incident_registry, test_daemon_id, 0);
            assert!(has_incidents_since, 1);

            let has_incidents_since2 = has_incidents_since(&incident_registry, test_daemon_id, 1);
            assert!(has_incidents_since2, 2);

            let has_incidents_since3 = has_incidents_since(&incident_registry, test_daemon_id, total_incidents + 1);
            // no incidents since `total_incidents + 1`
            assert!(!has_incidents_since3, 3);

            test_scenario::return_shared(incident_registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun has_incidents_since_empty_state() {
        use sui::test_scenario;

        let admin = @0xCAFE;
        let validator = @0xCAFF;
        let not_validator = @0xCAF0;

        let scenario_val = init_test_env(admin, vector::singleton(validator));
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, not_validator);
        {
            let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

            let has_incidents_since = has_incidents_since(&incident_registry, b"test_daemon_id", 0);
            // no incidents were reported for this daemon
            assert!(!has_incidents_since, 0);

            test_scenario::return_shared(incident_registry);
        };

        test_scenario::end(scenario_val);
    }

    #[test_only]
    fun init_test_env(admin: address, validators: vector<address>): Scenario {
        use sui_mamoru_relay::validators::ValidatorRegistryOwnerCap;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, admin);
        {
            let ctx = test_scenario::ctx(scenario);

            init(ctx);
            sui_mamoru_relay::validators::init_for_test(ctx);
        };

        let v = 0;

        while (v < vector::length(&validators)) {
            test_scenario::next_tx(scenario, admin);
            {
                let cap = test_scenario::take_from_sender<ValidatorRegistryOwnerCap>(scenario);
                let validator_registry = test_scenario::take_shared<ValidatorRegistry>(scenario);

                sui_mamoru_relay::validators::register_validator(
                    &cap,
                    &mut validator_registry,
                    *vector::borrow(&validators, v)
                );

                test_scenario::return_shared(validator_registry);
                test_scenario::return_to_sender(scenario, cap);
            };

            v = v + 1;
        };

        scenario_val
    }

    #[test_only]
    fun report_test_incidents(scenario: &mut test_scenario::Scenario, creator: address, amount: u64): vector<u8> {
        use std::string;

        assert!(amount > 0, 42);
        let test_daemon_id = b"test_daemon_id";

        let i = 0;
        while ((i as u64) < amount) {
            test_scenario::next_tx(scenario, creator);
            {
                let validator_registry = test_scenario::take_shared<ValidatorRegistry>(scenario);
                let incident_registry = test_scenario::take_shared<DaemonIncidentRegistry>(scenario);

                let mamoru_id = vector::empty<u8>();
                vector::push_back(&mut mamoru_id, i);

                report_incident(
                    &validator_registry,
                    &mut incident_registry,
                    test_daemon_id,
                    string::utf8(mamoru_id),
                    IncidentSeverityInfo,
                    string::utf8(b"cosmos"),
                    vector::empty<u8>(),
                    (i as u64),
                    test_scenario::ctx(scenario),
                );

                test_scenario::return_shared(validator_registry);
                test_scenario::return_shared(incident_registry);
            };

            i = i + 1;
        };


        test_daemon_id
    }
}
