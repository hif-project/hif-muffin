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
#include "muffin/injection/MutPortInjector.hpp"

using namespace hif;

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

    muffin::injection::MutPortInjector mutPortInjector(semantics::HIFSemantics::getInstance());
    system->acceptVisitor(mutPortInjector);

    messageInfo(
        "Wired activation port through " + std::to_string(mutPortInjector.getPortCount()) + " view(s) and " +
        std::to_string(mutPortInjector.getPortAssignCount()) + " instance(s).");

    delete system;

    hif::application_utils::restoreLogHeader();
    return 0;
}
