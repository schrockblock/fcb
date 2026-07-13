import Testing

/// Parent suite for ALL tests that touch CoreBluetoothMock's process-global
/// simulation (`CBMCentralManagerMock.simulate…` / `tearDownSimulation`).
/// `.serialized` is inherited by nested suites, so no two CBM-backed tests
/// ever run concurrently. Nest new CBM suites via `extension CBMBackedTests`.
@Suite(.serialized) struct CBMBackedTests {}
