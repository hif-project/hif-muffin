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
    const auto faultList = faultEnumerator.enumerate(locationVisitor.getLocations());

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
