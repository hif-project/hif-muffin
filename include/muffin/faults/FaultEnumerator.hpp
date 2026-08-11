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
/// of the assignment's left-hand side (the target being driven). A location
/// whose width cannot be statically determined is treated as 1 bit wide.
/// Faults are assigned deterministic, sequential ids in location order, then
/// bit order, then SA0 before SA1.
class FaultEnumerator
{
public:
    explicit FaultEnumerator(hif::semantics::ILanguageSemantics *sem);

    /// @brief Enumerates all faults for the given locations, in order.
    std::vector<Fault> enumerate(const std::vector<hif::Assign *> &locations) const;

private:
    FaultEnumerator(const FaultEnumerator &)            = delete;
    FaultEnumerator &operator=(const FaultEnumerator &) = delete;

    /// @brief Returns the bit-width of the location's left-hand side, or 1 if
    /// it cannot be statically determined.
    std::uint64_t getLocationWidth(hif::Assign *location) const;

    hif::semantics::ILanguageSemantics *_sem;
};

} // namespace faults
} // namespace muffin
