/// @file main.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include <hif/hif.hpp>

#include "muffin/MuffinParseLine.hpp"
#include "muffin/discovery/LocationVisitor.hpp"
#include "muffin/faults/FaultEnumerator.hpp"
#include "muffin/injection/Instrumenter.hpp"
#include "muffin/injection/MutPortInjector.hpp"
#include "muffin/report/FaultReportWriter.hpp"

using namespace hif;

namespace
{

/// @brief Derives a design name from the input file, for the JSON report:
/// the basename, with a trailing ".hif.xml"/".hif"/".xml" extension (if any)
/// stripped.
std::string designNameFromInputFile(const std::string &inputFile)
{
    const auto slash  = inputFile.find_last_of("/\\");
    const std::string base = slash == std::string::npos ? inputFile : inputFile.substr(slash + 1);

    for (const std::string ext : {".hif.xml", ".hif", ".xml"}) {
        if (base.size() > ext.size() && base.compare(base.size() - ext.size(), ext.size(), ext) == 0) {
            return base.substr(0, base.size() - ext.size());
        }
    }
    return base;
}

} // namespace

auto main(int argc, char *argv[]) -> int
{
    hif::application_utils::initializeLogHeader("MUFFIN", "");

    MuffinParseLine cLine(argc, argv);
    hif::application_utils::setVerboseLog(cLine.isVerbose());

    const std::string inputFile = cLine.getFiles().front();

    auto *system = dynamic_cast<System *>(hif::readFile(inputFile));
    if (system == nullptr) {
        messageError(std::string("File: ") + inputFile + "\nWrong hif.xml system description.", nullptr, nullptr);
    }

    muffin::discovery::LocationVisitor locationVisitor;
    system->acceptVisitor(locationVisitor);

    messageInfo("Found " + std::to_string(locationVisitor.getLocationCount()) + " injectable location(s).");

    muffin::faults::FaultEnumerator faultEnumerator(semantics::HIFSemantics::getInstance());

    // Enumeration runs against a throwaway copy, never against the description
    // we go on to instrument and write out.
    //
    // Resolving a location's width means folding its span bounds, and a bound
    // like `WIDTH - 1` only folds if template-parameter substitution is on.
    // That substitution rewrites the tree it is resolving -- it replaces the
    // parameter and drops the declaration behind it, so the module loses its
    // `parameter WIDTH = 4` header and regenerates with a span of
    // [18446744073709551615:0]. Setting SimplifyOptions::replace_result = false
    // does not prevent it (hif-core issue #16).
    //
    // Discovery is a deterministic pre-order walk, so the copy's locations come
    // out in the same order with the same ids, and the fault list computed here
    // applies unchanged to the original.
    auto *enumerationCopy = hif::copy(system);
    muffin::discovery::LocationVisitor enumerationVisitor;
    enumerationCopy->acceptVisitor(enumerationVisitor);

    if (enumerationVisitor.getLocationCount() != locationVisitor.getLocationCount()) {
        messageError(
            "Internal error: discovery found a different number of locations on a copy of the design than on "
            "the design itself, so enumerated fault ids would not line up with what is instrumented.",
            nullptr, nullptr);
    }

    const auto faultList = faultEnumerator.enumerate(enumerationVisitor.getLocations());

    delete enumerationCopy;

    messageInfo("Enumerated " + std::to_string(faultList.size()) + " stuck-at fault(s).");

    if (cLine.isListFaults()) {
        muffin::report::FaultReportWriter reportWriter;
        reportWriter.write(
            cLine.getFaultsListPath(), designNameFromInputFile(inputFile), locationVisitor.getLocations(),
            faultList);

        messageInfo("Wrote fault list to " + cLine.getFaultsListPath() + ".");
    } else {
        muffin::injection::MutPortInjector mutPortInjector(semantics::HIFSemantics::getInstance());
        system->acceptVisitor(mutPortInjector);

        messageInfo(
            "Wired activation port through " + std::to_string(mutPortInjector.getPortCount()) + " view(s) and " +
            std::to_string(mutPortInjector.getPortAssignCount()) + " instance(s).");

        muffin::injection::Instrumenter instrumenter(semantics::HIFSemantics::getInstance());
        instrumenter.instrument(locationVisitor.getLocations(), faultList);

        messageInfo("Instrumented " + std::to_string(locationVisitor.getLocationCount()) + " location(s).");

        hif::writeFile(cLine.getOutputFile(), system, true);

        messageInfo("Wrote instrumented design to " + cLine.getOutputFile() + ".");
    }

    delete system;

    hif::application_utils::restoreLogHeader();
    return 0;
}
