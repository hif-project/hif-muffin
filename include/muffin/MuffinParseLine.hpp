/// @file MuffinParseLine.hpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#pragma once

#include <hif/hif.hpp>

class MuffinParseLine : public hif::application_utils::CommandLineParser
{
public:
    MuffinParseLine(int argc, char **argv);
    ~MuffinParseLine() override;

private:
    void _validateArguments();

    MuffinParseLine(const MuffinParseLine &)            = delete;
    MuffinParseLine &operator=(const MuffinParseLine &) = delete;
};
