/// @file MuffinParseLine.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <hif/hif.hpp>
#include <string>

class MuffinParseLine : public hif::application_utils::CommandLineParser
{
public:
    MuffinParseLine(int argc, char **argv);
    ~MuffinParseLine() override;

    /// @brief True if `--list-faults` was given: enumerate faults and write
    /// them as JSON, without instrumenting the design.
    bool isListFaults() const;

    /// @brief Path given to `--list-faults`.
    const std::string &getFaultsListPath() const;

    /// @brief True if `--instrument` was given: instrument the design for
    /// fault injection and write it via `--output`.
    bool isInstrument() const;

private:
    void _validateArguments();

    MuffinParseLine(const MuffinParseLine &)            = delete;
    MuffinParseLine &operator=(const MuffinParseLine &) = delete;
};
