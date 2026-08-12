/// @file Instrumenter.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include "muffin/injection/Instrumenter.hpp"

#include <map>

#include "muffin/discovery/LocationVisitor.hpp"
#include "muffin/injection/MutPortInjector.hpp"

namespace muffin
{
namespace injection
{

Instrumenter::Instrumenter(hif::semantics::ILanguageSemantics *sem)
    : _factory(sem)
    , _sem(sem)
{
    // Nothing to do.
}

hif::Value *Instrumenter::buildForcedValue(hif::Value *originalCopy, std::uint64_t width, const faults::Fault &fault)
{
    const bool forceOne = fault.type == faults::FaultType::SA1;

    if (width == 1) {
        delete originalCopy;
        return _factory.bitval(forceOne ? '1' : '0');
    }

    const auto bit = static_cast<std::int64_t>(fault.bitIndex);
    if (forceOne) {
        return _factory.expression(originalCopy, hif::op_bor, _factory.intval(std::int64_t(1) << bit));
    }
    return _factory.expression(originalCopy, hif::op_band, _factory.intval(~(std::int64_t(1) << bit)));
}

void Instrumenter::instrument(const std::vector<hif::Assign *> &locations, const std::vector<faults::Fault> &faults)
{
    std::map<std::size_t, std::vector<const faults::Fault *>> faultsByLocation;
    for (const auto &fault : faults) {
        faultsByLocation[fault.locationId].push_back(&fault);
    }

    for (auto *location : locations) {
        auto *idProperty = dynamic_cast<hif::IntValue *>(
            location->getProperty(discovery::LocationVisitor::LOCATION_ID_PROPERTY));
        if (idProperty == nullptr) {
            continue;
        }
        const auto locationId = static_cast<std::size_t>(idProperty->getValue());

        auto found = faultsByLocation.find(locationId);
        if (found == faultsByLocation.end() || found->second.empty()) {
            continue;
        }

        hif::Type *lhsType = hif::semantics::getSemanticType(location->getLeftHandSide(), _sem);
        std::uint64_t width = lhsType != nullptr ? hif::semantics::typeGetSpanBitwidth(lhsType, _sem) : 0;
        if (width == 0) {
            width = 1;
        }

        hif::Value *originalRhs = location->getRightHandSide();

        auto *when = new hif::When();
        for (const auto *fault : found->second) {
            auto *alt = new hif::WhenAlt();
            alt->setCondition(_factory.expression(
                _factory.identifier(MutPortInjector::MUT_PORT_NAME), hif::op_eq,
                _factory.intval(static_cast<std::int64_t>(fault->id))));
            alt->setValue(buildForcedValue(hif::copy(originalRhs), width, *fault));
            when->alts.push_back(alt);
        }
        when->setDefault(originalRhs);

        location->setRightHandSide(when);
    }
}

} // namespace injection
} // namespace muffin
