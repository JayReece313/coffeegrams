//
//  AppTests.swift
//  CoffeeGramsTests
//
//  Root test suite for the app target.
//
//  `.serialized` forces every test in the target to run one at a time. This is
//  required because the brew-log tests exercise SwiftData, whose ModelContainer
//  and save operations trap when run concurrently with other tests under Swift
//  Testing's default parallelism (they pass 100% in isolation). Every suite in
//  this target is declared as a nested type of `AppTests` (via extensions), so
//  the trait propagates and the whole target runs serially.
//

import Testing

@Suite(.serialized)
struct AppTests {}
