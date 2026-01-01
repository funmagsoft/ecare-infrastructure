# Abc Module

Short description of Abc module.

## Resources Created

- **Resource 1** - Description 1
- **Resource 2** - Description 2

## Features

- Feature 1
- Feature 2

## Usage

```hcl
module "abc" {
  ...
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | description | `string` | - | yes |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| name | description | yes |

## Module-Specific Configuration

Text.

## Naming Convention

Resources follow this naming pattern:

- **NSG**: `nsg-bastion-{project_name}-{environment}`

## Security Features

- **Feature 1**: Description 1
- **Feature 2**: Description 2

## Examples

### Development Environment

```hcl
module "abc" {
  ...
}
```

### Production Environment

```hcl
module "abc" {
  ...
}
```

## Integration with Other Modules

Text.

## Prerequisites

Text.

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
- TLS Provider ~> 4.0 (for SSH key generation)
