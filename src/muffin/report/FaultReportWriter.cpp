/// @file FaultReportWriter.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include "muffin/report/FaultReportWriter.hpp"

#include <json/json.hpp>
#include <map>

#include "muffin/discovery/LocationVisitor.hpp"

namespace muffin
{
namespace report
{

namespace
{

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

    // The library defaults to single-quoted strings, which is not valid
    // JSON; force standard double quotes so consumers like Python's `json`
    // module can parse the output.
    json::config::string_delimiter_character = '"';

    json::jnode_t root;
    root.set_type(json::JTYPE_OBJECT);
    root["schema_version"] << 2;
    root["design"] << designName;
    root["golden_fault_id"] << 0;

    json::jnode_t &faultsNode = root["faults"];
    faultsNode.set_type(json::JTYPE_ARRAY);
    faultsNode.resize(faults.size());

    for (std::size_t i = 0; i < faults.size(); ++i) {
        const auto &fault   = faults[i];
        const auto found    = byLocationId.find(fault.locationId);
        const bool resolved = found != byLocationId.end();
        const std::string signal = resolved ? signalName(found->second->getLeftHandSide()) : "<unknown>";
        const std::string source = resolved ? baseName(found->second->getSourceFileName()) : "";
        const unsigned int line  = resolved ? found->second->getSourceLineNumber() : 0;

        json::jnode_t &entry = faultsNode[i];
        entry.set_type(json::JTYPE_OBJECT);
        entry["id"] << fault.id;
        entry["type"] << faultTypeName(fault.type);
        entry["bit"] << fault.bitIndex;
        entry["width"] << fault.width;
        entry["signal"] << signal;
        entry["source"] << source;
        entry["line"] << line;
    }

    if (!json::parser::write_file(path, root)) {
        messageError("Could not write fault report to " + path + ".", nullptr, nullptr);
    }
}

} // namespace report
} // namespace muffin
