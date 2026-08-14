/// @file FaultEnumerator.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <hif/hif.hpp>
#include <vector>

#include "muffin/faults/Fault.hpp"

namespace muffin
{
namespace faults
{

/// @brief Enumerates SA0/SA1 stuck-at faults for a set of discovered
/// locations.
/// @details For each location, the bit-width is taken from the semantic type
/// of the assignment's left-hand side (the target being driven), resolving
/// span bounds that are expressions over the design unit's template
/// parameters. A location whose width cannot be resolved is reported as an
/// error rather than assumed to be 1 bit wide, since a wrong width produces
/// fault records that misdescribe the design. Faults are assigned
/// deterministic, sequential ids in location order, then bit order, then SA0
/// before SA1.
class FaultEnumerator
{
public:
    explicit FaultEnumerator(hif::semantics::ILanguageSemantics *sem);

    /// @brief Enumerates all faults for the given locations, in order.
    std::vector<Fault> enumerate(const std::vector<hif::Assign *> &locations) const;

private:
    FaultEnumerator(const FaultEnumerator &)            = delete;
    FaultEnumerator &operator=(const FaultEnumerator &) = delete;

    /// @brief Returns the bit-width of the location's left-hand side, or 0 if
    /// it cannot be statically resolved.
    std::uint64_t getLocationWidth(hif::Assign *location) const;

    hif::semantics::ILanguageSemantics *_sem;
};

} // namespace faults
} // namespace muffin
