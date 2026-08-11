/// @file main.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include <hif/hif.hpp>

#include "muffin/MuffinParseLine.hpp"

using namespace hif;

namespace
{

/// @brief Smallest useful walk over a HIF description: counts the Assign
/// nodes reachable from the root. Proves the build/link/traversal story
/// against the current hif-core before any fault-injection logic is added.
class AssignCounter : public GuideVisitor
{
public:
    AssignCounter() : GuideVisitor(), count(0) {}
    ~AssignCounter() override = default;

    int visitAssign(Assign &o) override
    {
        ++count;
        return GuideVisitor::visitAssign(o);
    }

    std::size_t count;

private:
    AssignCounter(const AssignCounter &)            = delete;
    AssignCounter &operator=(const AssignCounter &) = delete;
};

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

    AssignCounter counter;
    system->acceptVisitor(counter);

    messageInfo("Found " + std::to_string(counter.count) + " assign(s).");

    delete system;

    hif::application_utils::restoreLogHeader();
    return 0;
}
