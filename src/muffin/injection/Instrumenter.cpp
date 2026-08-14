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

    // The mask is built as a literal of exactly `width` bits rather than as an
    // integer shift. `1 << bit` cannot express bit 63 (it overflows into the
    // sign bit, and the resulting negative decimal sign-extends when it meets a
    // wider target) and silently wraps for bit >= 64, which would make the
    // masks for the top bits of a wide vector alias the masks for its bottom
    // bits. A sized literal has neither problem at any width.
    std::string mask(static_cast<std::size_t>(width), forceOne ? '0' : '1');
    mask[static_cast<std::size_t>(width - 1 - fault.bitIndex)] = forceOne ? '1' : '0';

    // State the literal's type explicitly rather than leaving its width to be
    // inferred downstream. See issue #14.
    auto *maskType = _factory.bitvector(
        _factory.range(static_cast<std::int64_t>(width) - 1, 0), /* logic */ true, /* resolved */ true,
        /* const_expr */ true, /* isSigned */ false);

    return _factory.expression(
        originalCopy, forceOne ? hif::op_bor : hif::op_band, _factory.bitvectorval(mask, maskType));
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

        hif::Value *originalRhs = location->getRightHandSide();

        auto *when = new hif::When();
        for (const auto *fault : found->second) {
            auto *alt = new hif::WhenAlt();
            alt->setCondition(_factory.expression(
                _factory.identifier(MutPortInjector::MUT_PORT_NAME), hif::op_eq,
                _factory.intval(static_cast<std::int64_t>(fault->id))));
            alt->setValue(buildForcedValue(hif::copy(originalRhs), fault->width, *fault));
            when->alts.push_back(alt);
        }
        when->setDefault(originalRhs);

        location->setRightHandSide(when);

        registerActivationPortInSensitivity(location);
    }
}

void Instrumenter::registerActivationPortInSensitivity(hif::Assign *location)
{
    auto *process = hif::getNearestParent<hif::StateTable>(location);
    if (process == nullptr) {
        return;
    }

    // Only purely level-sensitive processes. An edge-sensitive process must
    // keep waiting for its edge -- a register that updated because the
    // activation port moved between clock edges would not be the design under
    // test any more. Sequential faults legitimately take effect on the next
    // edge.
    if (!process->sensitivityPos.empty() || !process->sensitivityNeg.empty()) {
        return;
    }

    // An empty list is not "sensitive to nothing", it is `always @*`. Adding
    // the port there would replace implicit sensitivity to everything with
    // explicit sensitivity to one signal.
    if (process->sensitivity.empty()) {
        return;
    }

    for (auto *entry : process->sensitivity) {
        auto *identifier = dynamic_cast<hif::Identifier *>(entry);
        if (identifier != nullptr && identifier->getName() == MutPortInjector::MUT_PORT_NAME) {
            return;
        }
    }

    process->sensitivity.push_back(_factory.identifier(MutPortInjector::MUT_PORT_NAME));
}

} // namespace injection
} // namespace muffin
