/// @file MutPortInjector.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <cstddef>
#include <hif/hif.hpp>

namespace muffin
{
namespace injection
{

/// @brief Threads a single fault-activation control signal through the
/// whole design hierarchy.
/// @details Adds an `integer` input port named `MUT_PORT_NAME` to every RTL
/// design unit's entity, and connects it, at every instance, to the
/// same-named identifier in the instantiating scope. A value driven on this
/// port at the top level therefore reaches every instantiated module,
/// regardless of nesting depth.
/// @note Whether there are any instances left to wire depends on the frontend,
/// not on this visitor: `verilog2hif` inlines them by default and preserves
/// them under `-s`/`--structure`, while `vhdl2hif` preserves them always.
/// Seeing `getPortAssignCount() == 0` on a Verilog design is therefore the
/// expected outcome of a flattened input, not evidence that the wiring is
/// broken. Both cases are pinned by the `hierarchical_wiring` test.
class MutPortInjector : public hif::GuideVisitor
{
public:
    /// @brief Name of the fault-activation control port.
    static const std::string MUT_PORT_NAME;

    explicit MutPortInjector(hif::semantics::ILanguageSemantics *sem);
    ~MutPortInjector() override;

    int visitView(hif::View &o) override;
    int visitInstance(hif::Instance &o) override;

    /// @brief Number of RTL views that received the control port.
    std::size_t getPortCount() const;

    /// @brief Number of instances wired to their instantiating scope's port.
    std::size_t getPortAssignCount() const;

private:
    MutPortInjector(const MutPortInjector &)            = delete;
    MutPortInjector &operator=(const MutPortInjector &) = delete;

    hif::HifFactory _factory;
    std::size_t _portCount;
    std::size_t _portAssignCount;
};

} // namespace injection
} // namespace muffin
