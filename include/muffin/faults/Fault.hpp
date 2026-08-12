/// @file Fault.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <cstddef>
#include <cstdint>

namespace muffin
{
namespace faults
{

/// @brief The kind of stuck-at fault.
enum class FaultType {
    SA0, ///< Stuck-at-0.
    SA1  ///< Stuck-at-1.
};

/// @brief A single bit-level stuck-at fault at a discovered location.
struct Fault {
    /// @brief Deterministic id, unique across the whole design, assigned in
    /// enumeration order.
    std::size_t id;
    /// @brief Id of the location this fault belongs to (see
    /// `discovery::LocationVisitor::LOCATION_ID_PROPERTY`).
    std::size_t locationId;
    /// @brief Index of the affected bit within the location's value, 0 being
    /// the least significant bit.
    std::size_t bitIndex;
    /// @brief The kind of stuck-at fault.
    FaultType type;
    /// @brief Bit-width of the location this fault belongs to.
    std::uint64_t width;
};

} // namespace faults
} // namespace muffin
