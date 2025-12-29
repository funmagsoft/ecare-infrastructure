# Naming Conventions

This document defines the naming conventions used in this repository.

## General Rules

- Lowercase only (Azure requirement for Storage Accounts, DNS names)
- Hyphens for separation (not underscores)
- Environment suffix (`-dev`, `-test`, `-stage`, `-prod`)
- Consistent prefixes per resource type
- Max length: Respect Azure limits (Storage Accounts: 24 chars, others: 63-80 chars)

## Resource Naming Patterns

See main infrastructure design document: `INFRASTRUCTURE-DESIGN.md`

## Environment Variables

- `ENV`: Environment name (dev, test, stage, prod)
- `PROJECT`: Project name (ecare)
- `LOCATION`: Azure region (westeurope)

## Examples

- Resource Group: `rg-ecare-dev`
- Virtual Network: `vnet-ecare-dev`
- Storage Account: `tfstatefmsecaredev` (state) or `stecaredev` (application data)
