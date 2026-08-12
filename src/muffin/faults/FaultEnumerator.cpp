/// @file FaultEnumerator.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include "muffin/faults/FaultEnumerator.hpp"

#include "muffin/discovery/LocationVisitor.hpp"

namespace muffin
{
namespace faults
{

FaultEnumerator::FaultEnumerator(hif::semantics::ILanguageSemantics *sem)
    : _sem(sem)
{
    // Nothing to do.
}

std::uint64_t FaultEnumerator::getLocationWidth(hif::Assign *location) const
{
    hif::Type *type = hif::semantics::getSemanticType(location->getLeftHandSide(), _sem);
    if (type == nullptr) {
        return 1;
    }
    const std::uint64_t width = hif::semantics::typeGetSpanBitwidth(type, _sem);
    return width == 0 ? 1 : width;
}

std::vector<Fault> FaultEnumerator::enumerate(const std::vector<hif::Assign *> &locations) const
{
    std::vector<Fault> result;
    std::size_t nextId = 1;

    for (auto *location : locations) {
        auto *idProperty =
            dynamic_cast<hif::IntValue *>(location->getProperty(discovery::LocationVisitor::LOCATION_ID_PROPERTY));
        if (idProperty == nullptr) {
            messageError(
                "Location is missing its " + discovery::LocationVisitor::LOCATION_ID_PROPERTY + " property.",
                location, _sem);
        }
        const auto locationId       = static_cast<std::size_t>(idProperty->getValue());
        const std::uint64_t width = getLocationWidth(location);

        for (std::uint64_t bit = 0; bit < width; ++bit) {
            result.push_back(Fault{nextId++, locationId, bit, FaultType::SA0, width});
            result.push_back(Fault{nextId++, locationId, bit, FaultType::SA1, width});
        }
    }

    return result;
}

} // namespace faults
} // namespace muffin
