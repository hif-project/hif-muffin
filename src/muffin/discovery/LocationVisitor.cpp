/// @file LocationVisitor.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include "muffin/discovery/LocationVisitor.hpp"

namespace muffin
{
namespace discovery
{

const std::string LocationVisitor::LOCATION_ID_PROPERTY = "muffinLocationId";

LocationVisitor::LocationVisitor()
    : GuideVisitor()
    , _designUnit(nullptr)
    , _locations()
{
    // Nothing to do.
}

LocationVisitor::~LocationVisitor() = default;

int LocationVisitor::visitDesignUnit(hif::DesignUnit &o)
{
    _designUnit  = &o;
    const int ret = hif::GuideVisitor::visitDesignUnit(o);
    _designUnit  = nullptr;
    return ret;
}

int LocationVisitor::visitAssign(hif::Assign &o)
{
    const int ret = hif::GuideVisitor::visitAssign(o);
    if (_designUnit == nullptr) {
        return ret;
    }
    _locations.push_back(&o);
    o.addProperty(LOCATION_ID_PROPERTY, new hif::IntValue(_locations.size()));
    return ret;
}

int LocationVisitor::visitFor(hif::For &o) { return visitList(o.forActions); }

std::size_t LocationVisitor::getLocationCount() const { return _locations.size(); }

const std::vector<hif::Assign *> &LocationVisitor::getLocations() const { return _locations; }

} // namespace discovery
} // namespace muffin
