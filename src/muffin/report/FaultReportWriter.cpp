/// @file FaultReportWriter.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include "muffin/report/FaultReportWriter.hpp"

#include <fstream>
#include <map>

#include "muffin/discovery/LocationVisitor.hpp"

namespace muffin
{
namespace report
{

namespace
{

std::string escapeJson(const std::string &s)
{
    std::string out;
    out.reserve(s.size());
    for (const char c : s) {
        switch (c) {
        case '"':
            out += "\\\"";
            break;
        case '\\':
            out += "\\\\";
            break;
        case '\n':
            out += "\\n";
            break;
        default:
            out += c;
        }
    }
    return out;
}

std::string baseName(const std::string &path)
{
    const auto pos = path.find_last_of("/\\");
    return pos == std::string::npos ? path : path.substr(pos + 1);
}

std::string signalName(hif::Value *lhs)
{
    hif::Value *v = lhs;
    while (v != nullptr) {
        if (auto *id = dynamic_cast<hif::Identifier *>(v)) {
            return id->getName();
        }
        auto *prefixed = dynamic_cast<hif::PrefixedReference *>(v);
        if (prefixed == nullptr) {
            break;
        }
        v = prefixed->getPrefix();
    }
    return "<unknown>";
}

const char *faultTypeName(faults::FaultType type) { return type == faults::FaultType::SA0 ? "stuck-at-0" : "stuck-at-1"; }

} // namespace

FaultReportWriter::FaultReportWriter() = default;

void FaultReportWriter::write(
    const std::string &path, const std::string &designName, const std::vector<hif::Assign *> &locations,
    const std::vector<faults::Fault> &faults) const
{
    std::map<std::size_t, hif::Assign *> byLocationId;
    for (auto *location : locations) {
        auto *idProperty =
            dynamic_cast<hif::IntValue *>(location->getProperty(discovery::LocationVisitor::LOCATION_ID_PROPERTY));
        if (idProperty == nullptr) {
            continue;
        }
        byLocationId[static_cast<std::size_t>(idProperty->getValue())] = location;
    }

    std::ofstream out(path);
    if (!out) {
        messageError("Could not open " + path + " for writing.", nullptr, nullptr);
    }

    out << "{\n";
    out << "  \"schema_version\": 1,\n";
    out << "  \"design\": \"" << escapeJson(designName) << "\",\n";
    out << "  \"golden_fault_id\": 0,\n";
    out << "  \"faults\": [\n";

    for (std::size_t i = 0; i < faults.size(); ++i) {
        const auto &fault  = faults[i];
        const auto found   = byLocationId.find(fault.locationId);
        const bool resolved = found != byLocationId.end();
        const std::string signal = resolved ? signalName(found->second->getLeftHandSide()) : "<unknown>";
        const std::string source = resolved ? baseName(found->second->getSourceFileName()) : "";

        out << "    {\n";
        out << "      \"id\": " << fault.id << ",\n";
        out << "      \"type\": \"" << faultTypeName(fault.type) << "\",\n";
        out << "      \"bit\": " << fault.bitIndex << ",\n";
        out << "      \"width\": " << fault.width << ",\n";
        out << "      \"signal\": \"" << escapeJson(signal) << "\",\n";
        out << "      \"source\": \"" << escapeJson(source) << "\"\n";
        out << "    }" << (i + 1 < faults.size() ? "," : "") << "\n";
    }

    out << "  ]\n";
    out << "}\n";
}

} // namespace report
} // namespace muffin
