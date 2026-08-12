/// @file FaultReportWriter.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <hif/hif.hpp>
#include <string>
#include <vector>

#include "muffin/faults/Fault.hpp"

namespace muffin
{
namespace report
{

/// @brief Writes the enumerated faults for a design as JSON, so an external
/// orchestrator (e.g. a Python fault-campaign script) never has to touch
/// HIF directly.
/// @details Deliberately does not emit a source line number: `verilog2hif`'s
/// line tracking is currently unreliable (see hif-muffin/docs/known-issues.md),
/// so a wrong line would mislead more than no line at all. `signal` and
/// `source` (the base filename) are resolved from each fault's location and
/// are safe to trust.
class FaultReportWriter
{
public:
    FaultReportWriter();

    /// @brief Writes `faults` to `path` as JSON, resolving each fault's
    /// signal name and source file from `locations`.
    /// @param path Output file path.
    /// @param designName Name to record under the report's "design" field.
    /// @param locations The discovered locations (see LocationVisitor).
    /// @param faults The enumerated faults (see FaultEnumerator).
    void write(
        const std::string &path, const std::string &designName, const std::vector<hif::Assign *> &locations,
        const std::vector<faults::Fault> &faults) const;

private:
    FaultReportWriter(const FaultReportWriter &)            = delete;
    FaultReportWriter &operator=(const FaultReportWriter &) = delete;
};

} // namespace report
} // namespace muffin
