/// @file Instrumenter.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <cstdint>
#include <hif/hif.hpp>
#include <vector>

#include "muffin/faults/Fault.hpp"

namespace muffin
{
namespace injection
{

/// @brief Replaces each discovered location's right-hand side with a
/// conditional expression that selects the faulty value when
/// `muffinMutPort` matches one of the location's fault ids, and the
/// original value otherwise.
/// @details Built as a `When` (HIF's ternary/conditional-expression
/// construct), one alternative per fault, so the no-fault-active case is
/// exactly the original expression. A single-bit location's forced value is
/// the fault's constant (0 or 1); a wider location's forced value is the
/// original value with just that bit forced, via a bitwise mask of exactly
/// the location's width, so the rest of the vector is left untouched.
/// @note The width comes from the `Fault` record rather than being recomputed
/// from the target's type: the enumerator is the single place that decides how
/// wide a location is, so the injected value cannot disagree with the fault
/// list that describes it.
class Instrumenter
{
public:
    explicit Instrumenter(hif::semantics::ILanguageSemantics *sem);

    /// @brief Instruments every location that has at least one fault.
    /// @param locations The discovered locations (see LocationVisitor).
    /// @param faults The enumerated faults (see FaultEnumerator).
    void instrument(const std::vector<hif::Assign *> &locations, const std::vector<faults::Fault> &faults);

private:
    Instrumenter(const Instrumenter &)            = delete;
    Instrumenter &operator=(const Instrumenter &) = delete;

    /// @brief Builds the value a single fault forces the location to.
    hif::Value *buildForcedValue(hif::Value *originalCopy, std::uint64_t width, const faults::Fault &fault);

    hif::HifFactory _factory;
};

} // namespace injection
} // namespace muffin
