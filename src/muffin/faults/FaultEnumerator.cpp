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

namespace
{

/// @brief Simplification options used when resolving a location's bit-width.
/// @details A span bound is allowed to be an expression over the design unit's
/// template parameters: `reg [WIDTH-1:0]` reaches Muffin as a cast of the
/// expression `WIDTH - 1`, not as a literal. Under the default options those
/// bounds stay symbolic and the width comes back as "not statically known",
/// which is indistinguishable from a genuinely unresolvable width. Enabling
/// constant and template-parameter substitution lets such a bound fold to the
/// parameter's elaborated/default value. This resolves widths only for the
/// query — `typeGetSpanBitwidth` simplifies a copy of the span, so the design
/// itself is left untouched and still emits `WIDTH` symbolically.
hif::manipulation::SimplifyOptions getWidthSimplifyOptions()
{
    hif::manipulation::SimplifyOptions opts;
    opts.simplify_constants           = true;
    opts.simplify_template_parameters = true;
    return opts;
}

} // namespace

FaultEnumerator::FaultEnumerator(hif::semantics::ILanguageSemantics *sem)
    : _sem(sem)
{
    // Nothing to do.
}

std::uint64_t FaultEnumerator::getLocationWidth(hif::Assign *location) const
{
    hif::Type *type = hif::semantics::getSemanticType(location->getLeftHandSide(), _sem);
    if (type == nullptr) {
        return 0;
    }
    // Scalar types carry a one-element span of their own (hif::typeGetSpan
    // hands back a dummy 1-bit range for Bit and Bool), so a zero here always
    // means "could not be resolved" and never "this signal is a scalar".
    return hif::semantics::typeGetSpanBitwidth(type, _sem, true, getWidthSimplifyOptions());
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
        const auto locationId     = static_cast<std::size_t>(idProperty->getValue());
        const std::uint64_t width = getLocationWidth(location);

        // Never fall back to a guessed width. Assuming 1 bit for a target that
        // is actually N bits wide silently under-enumerates by 2 * (N - 1)
        // faults and, worse, makes the injector overwrite the whole target
        // instead of forcing a single bit -- fault records that do not describe
        // the design they claim to.
        if (width == 0) {
            messageError(
                "Cannot statically resolve the bit-width of this assignment's target, so the faults on it "
                "cannot be enumerated. If the width depends on a parameter, check that the parameter has a "
                "default value that Muffin can elaborate.",
                location, _sem);
        }

        for (std::uint64_t bit = 0; bit < width; ++bit) {
            result.push_back(Fault{nextId++, locationId, bit, FaultType::SA0, width});
            result.push_back(Fault{nextId++, locationId, bit, FaultType::SA1, width});
        }
    }

    return result;
}

} // namespace faults
} // namespace muffin
