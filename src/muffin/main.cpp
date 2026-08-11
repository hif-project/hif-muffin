/// @file main.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include <hif/hif.hpp>

#include "muffin/MuffinParseLine.hpp"
#include "muffin/discovery/LocationVisitor.hpp"

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

    delete system;

    hif::application_utils::restoreLogHeader();
    return 0;
}
