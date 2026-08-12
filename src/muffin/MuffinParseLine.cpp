/// @file MuffinParseLine.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include "muffin/MuffinParseLine.hpp"

MuffinParseLine::MuffinParseLine(int argc, char **argv)
    : CommandLineParser()
{
    addToolInfos(
        // Tool name.
        "muffin",
        // Copyright.
        "Copyright (c) 2026, Electronic Systems Design (ESD) Group, University of Verona. "
        "This file is distributed under the BSD 2-Clause License.",
        // description
        "Discovers and injects stuck-at faults into a HIF description.",
        // synopsys
        "muffin [OPTIONS] <HIF FILE>",
        // notes
        "Site: https://github.com/esd-univr/hif-muffin");

    addHelp();
    addVersion();
    addVerbose();
    addOutputFile();
    addOption('l', "list-faults", true, true, "Enumerates faults and writes them as JSON to the given path.");
    addOption('i', "instrument", false, true, "Instruments the design for fault injection; requires --output.");

    parse(argc, argv);

    _validateArguments();
}

MuffinParseLine::~MuffinParseLine() = default;

bool MuffinParseLine::isListFaults() const { return isOptionFlagSet('l'); }

const std::string &MuffinParseLine::getFaultsListPath() const { return getOption('l'); }

bool MuffinParseLine::isInstrument() const { return isOptionFlagSet('i'); }

void MuffinParseLine::_validateArguments()
{
    if (isOptionFlagSet('h')) {
        printHelp();
    }
    if (isOptionFlagSet('v')) {
        printVersion();
    }

    if (getFiles().empty()) {
        messageError("HIF input file missing.\nTry 'muffin --help' for more information", nullptr, nullptr);
    }

    if (getFiles().size() != 1) {
        messageError("Required exactly one input file.\nTry 'muffin --help' for more information", nullptr, nullptr);
    }

    if (isListFaults() == isInstrument()) {
        messageError(
            "Specify exactly one of --list-faults or --instrument.\nTry 'muffin --help' for more information",
            nullptr, nullptr);
    }

    if (isInstrument() && getOutputFile().empty()) {
        messageError(
            "--instrument requires --output <file>.\nTry 'muffin --help' for more information", nullptr, nullptr);
    }
}
