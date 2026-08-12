/// @file MutPortInjector.cpp
/// @brief
/// Copyright (c) 2026, Electronic Systems Design (ESD) Group,
/// University of Verona.
/// This file is distributed under the BSD 2-Clause License.
/// See LICENSE.md for details.

#include "muffin/injection/MutPortInjector.hpp"

namespace muffin
{
namespace injection
{

const std::string MutPortInjector::MUT_PORT_NAME = "muffinMutPort";

MutPortInjector::MutPortInjector(hif::semantics::ILanguageSemantics *sem)
    : GuideVisitor()
    , _factory(sem)
    , _portCount(0)
    , _portAssignCount(0)
{
    // Nothing to do.
}

MutPortInjector::~MutPortInjector() = default;

int MutPortInjector::visitView(hif::View &o)
{
    const int ret = hif::GuideVisitor::visitView(o);
    if (o.getLanguageID() != hif::rtl || o.getEntity() == nullptr) {
        return ret;
    }
    o.getEntity()->ports.push_back(_factory.port(_factory.integer(), MUT_PORT_NAME, hif::dir_in));
    ++_portCount;
    return ret;
}

int MutPortInjector::visitInstance(hif::Instance &o)
{
    const int ret = hif::GuideVisitor::visitInstance(o);
    if (dynamic_cast<hif::Contents *>(o.getParent()) == nullptr) {
        return ret;
    }
    o.portAssigns.push_back(_factory.portAssign(MUT_PORT_NAME, _factory.identifier(MUT_PORT_NAME)));
    ++_portAssignCount;
    return ret;
}

std::size_t MutPortInjector::getPortCount() const { return _portCount; }

std::size_t MutPortInjector::getPortAssignCount() const { return _portAssignCount; }

} // namespace injection
} // namespace muffin
