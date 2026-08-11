/// @file LocationVisitor.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <cstddef>
#include <hif/hif.hpp>
#include <vector>

namespace muffin
{
namespace discovery
{

/// @brief Discovers injectable fault locations.
/// @details For v1, a location is the whole right-hand side of an `Assign`
/// found inside a user design unit. Each discovered `Assign` is marked with
/// the `LOCATION_ID_PROPERTY` property, holding a deterministic id assigned
/// in visitation order.
class LocationVisitor : public hif::GuideVisitor
{
public:
    /// @brief Name of the property used to mark a discovered location.
    static const std::string LOCATION_ID_PROPERTY;

    LocationVisitor();
    ~LocationVisitor() override;

    int visitDesignUnit(hif::DesignUnit &o) override;
    int visitAssign(hif::Assign &o) override;

    /// @brief Only the loop body is a candidate for injection: the
    /// initialization and step assignments (e.g. `i = 0`, `i = i + 1`) drive
    /// a loop index, not RTL state, and are elaborated away rather than
    /// synthesized.
    int visitFor(hif::For &o) override;

    /// @brief Number of locations discovered so far.
    std::size_t getLocationCount() const;

    /// @brief The discovered locations, in visitation (i.e. location id) order.
    const std::vector<hif::Assign *> &getLocations() const;

private:
    LocationVisitor(const LocationVisitor &)            = delete;
    LocationVisitor &operator=(const LocationVisitor &) = delete;

    hif::DesignUnit *_designUnit;
    std::vector<hif::Assign *> _locations;
};

} // namespace discovery
} // namespace muffin
