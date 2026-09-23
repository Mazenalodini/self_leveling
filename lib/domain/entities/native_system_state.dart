// Compatibility export retained during Phase 1 contract stabilization.
//
// New code should import `lib/domain/contracts/runtime_contract.dart` directly.

export '../contracts/runtime_contract.dart'
    show
        RuntimeStateSnapshot,
        LockStatePayload,
        InterventionEvent,
        InterventionStage,
        FocusModeSemantics,
        ReadinessState,
        RuntimeSettingKeys,
        LocalFlagKeys,
        AppCategory;
