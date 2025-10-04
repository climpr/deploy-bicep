# Deploy Bicep

This action deploys a Bicep deployment or a Deployment Stack based on a deployment file. This can be either a `.bicepparam` or a `.bicep` file.
It supports the use of the `deploymentconfig.json` or `deploymentconfig.jsonc` file for advanced deployment options.

## Scenarios

This action supports a few scenarios:

### Parameter file per environment

This is the most common scenario.

For this scenario, the only thing you require is a directory for the deployment and a `.bicepparam` file with the same name as the GitHub environment to use for the deployment.
The action should then use the `.bicepparam` file for the `deployment-file-path` parameter.

In the following example, the dev and prod environments will use different parameter files for deployments, while using the same `main.bicep` template file.

```
<repo root>
  - bicep-deployments
    - <deployment name>
      - main.bicep
      - dev.bicepparam
      - prod.bicepparam
```

### Bicep file per environment

Sometimes, especially when consuming public Bicep modules, it can become complex and cumbersome to ensure parameters are passed correctly through a `*.bicep` template consuming the modules to the respective `*.bicepparam` files.
In this case, it can make sense to use `.bicep` template files directly as if they were parameter files and just hard-code the sub-module parameters.
While this can be counter-intuitive, this can be a good practice as the modules you are deploying are not reusable.
This is especially valid in scenarios where you use a `subscription` scoped deployment for managing the resource groups and consuming [Azure Verified Modules (AVM)](https://github.com/Azure/bicep-registry-modules) for the resources.

This scenario is supported in this action by referring the `deployment-file-path` parameter directly to the `.bicep` file. In this scenario, the `.bicep` file must be named according to the GitHub environment to use for the deployment.

For example:

```
<repo root>
  - bicep-deployments
    - <deployment name>
      - dev.bicep
      - prod.bicep
```

### With configuration options

Sometimes there is a need to specify additional properties or parameters for a deployment that cannot be specified through the `.bicep` or `.bicepparam` files directly. For these scenarios, the action supports one or multiple `deploymentconfig.json` files.

You can use a single `deploymentconfig.json` that will apply to all the deployments and environments in the deployment directory, **or** you can use individual `deploymentconfig.json` files per environment.

> [!TIP]
> The `deploymentconfig.json` file supports comments if you use the `.jsonc` extension.

> [!WARNING]
> In the case of conflicting `.json` and `.jsonc` files, the `.jsonc` takes precedence.

The most common reason for this is to alter the deployment scope for a deployment. By default, all deployments will be treated as `subscription` scoped deployments. If deploying directly to a resource group for example, you need to specify the resource group name in the `deploymentconfig.json` file. See the chapter for the `deploymentconfig.json` options for more information.

Example showing a single `deploymentconfig.json file` that will apply to all environment deployments.

```
<repo root>
  - bicep-deployments
    - <deployment name>
      - deploymentconfig.json
      - main.bicep
      - dev.bicepparam
      - prod.bicepparam
```

Example showing multiple `deploymentconfig.json` files that will be applied individually to each environment deployment.

```
<repo root>
  - bicep-deployments
    - <deployment name>
      - main.bicep
      - dev.deploymentconfig.json
      - dev.bicepparam
      - prod.deploymentconfig.json
      - prod.bicepparam
```

> [!TIP]
> You can mix and match these. Having a common _fallback_ file and an individual file for one or more of the environment deployments.

> [!WARNING]
> If you have multiple `deploymentconfig.json` files, they will not be merged. The most specific file will apply exclusively.

### Bicep param files per environment using only public/external modules

The action supports deployments using `.bicepparam` files directly referencing Bicep registry modules. In that case, you do not need to have a `.bicep` file.

A common scenario for this is when deploying an [Azure Verified Modules (AVM)](https://github.com/Azure/bicep-registry-modules) directly to a pre-existing resource group.

### Deployment Stacks

Azure now supports deployment stacks to manage the lifecycle of complex deployments.

This is supported in this action as well by using the `.deploymentconfig.json` file.

## Deployment Config options

Sometimes there is a need to specify additional properties or parameters for a deployment that cannot be specified through the `.bicep` or `.bicepparam` files directly. For these scenarios, the action supports one or multiple `deploymentconfig.json` files.

You can use a single `deploymentconfig.json` that will apply to all the deployments and environments in the deployment directory, **or** you can use individual `deploymentconfig.json` files per environment.

See [With configuration options](#with-configuration-options) for more information on the structure.

When creating a `deploymentconfig.json` or `deploymentconfig.jsonc` file, you should start with a schema reference to get proper schema validation and auto-complete options.

```json
{
  "$schema": "https://raw.githubusercontent.com/climpr/climpr-schemas/refs/heads/main/schemas/v1.0.0/bicep-deployment/deploymentconfig.json#"
}
```

### Options

#### Common options

These options are common for all scenarios

| Option          | Type    | Required | Description                                                                                                                                                      |
| --------------- | ------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| disabled        | boolean | false    | Setting this to true disables the deployment regardless of the triggering event.                                                                                 |
| triggers        | object  | false    | Configures settings per GitHub event trigger. See: [triggers](#triggers)                                                                                         |
| azureCliVersion | string  | false    | The Azure CLI version to use.                                                                                                                                    |
| type            | string  | false    | Specifies the execution type. Either `deployment` or `deploymentStack`. Default: `deployment`                                                                    |
| scope           | string  | false    | Specifies the scope of the deployment or deploymentStack. Valid options: `resourceGroup`, `subscription`, `managementGroup` or `tenant`. Default: `subscription` |

##### triggers

Should be an object where the property name is the triggering event name and the value is an object specifying these options:

Supported triggers:

- workflow_dispatch
- schedule
- pull_request_target
- push

| Option   | Type    | Required | Description                                                                                      |
| -------- | ------- | -------- | ------------------------------------------------------------------------------------------------ |
| disabled | boolean | false    | Setting this to true disables the deployment when triggered from this specific triggering event. |

Example:

```json
{
  "$schema": "https://raw.githubusercontent.com/climpr/climpr-schemas/refs/heads/main/schemas/v1.0.0/bicep-deployment/deploymentconfig.json#",
  "disabled": false,
  "triggers": {
    "schedule": {
      "disabled": true
    }
  }
}
```

#### Deployment options

For normal deployments, the following options can be specified:

| Option            | Type   | Required                             | Description                                                                                                                                   |
| ----------------- | ------ | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| name              | string | false                                | The deployment name. Defaults to a combination of the deployment directory name and the GitHub short hash.                                    |
| location          | string | false                                | The location to store the deployment metadata. This is optional and will use either an organization default or `westeurope` if not specified. |
| resourceGroupName | string | true (if scope is `resourceGroup`)   | Name of resource group.                                                                                                                       |
| managementGroupId | string | true (if scope is `managementGroup`) | The management group id.                                                                                                                      |

#### Deployment Stack options

For deployment stacks, the following options can be specified:

| Option                    | Type    | Required                             | Description                                                                                                                                                                                              |
| ------------------------- | ------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| name                      | string  | true                                 | The name of the deployment stack.                                                                                                                                                                        |
| location                  | string  | false                                | The location to store deployment stack. This is optional and will use either an organization default or `westeurope` if not specified.                                                                   |
| resourceGroupName         | string  | true (if scope is `resourceGroup`)   | Name of resource group.                                                                                                                                                                                  |
| managementGroupId         | string  | true (if scope is `managementGroup`) | The management group id.                                                                                                                                                                                 |
| deploymentResourceGroup   | string  | false                                | Only available for `subscription` scoped deployments. The scope at which the initial deployment should be created. If a scope is not specified, it will default to the scope of the deployment stack.    |
| deploymentSubscription    | string  | false                                | Only available for `managementGroup` scoped deployments. The scope at which the initial deployment should be created. If a scope is not specified, it will default to the scope of the deployment stack. |
| actionOnUnmanage          | object  | true                                 | Defines the behavior of resources that are not managed immediately after the stack is updated. See: [actionOnUnmanage](#actionOnUnmanage)                                                                |
| bypassStackOutOfSyncError | boolean | false                                | Flag to bypass service errors that indicate the stack resource list is not correctly synchronized. Default: 'false'.                                                                                     |
| denySettings              | object  | true                                 | Defines how resources deployed by the stack are locked. See: [denySettings](#denySettings)                                                                                                               |
| description               | string  | false                                | Deployment stack description.                                                                                                                                                                            |
| tags                      | object  | false                                | Deployment stack resource tags. Key=value format.                                                                                                                                                        |

##### actionOnUnmanage

| Option           | Type   | Required | Description                                                                                                                                                                                                                                                           |
| ---------------- | ------ | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| resources        | string | true     | Valid options: `delete` or `detatch`. Specifies the action that should be taken on the resource when the deployment stack is deleted. Delete will attempt to delete the resource from Azure. Detach will leave the resource in it's current state.                    |
| resourceGroups   | string | false    | Valid options: `delete` or `detatch`. Default: `detach`. Specifies the action that should be taken on the resource when the deployment stack is deleted. Delete will attempt to delete the resource from Azure. Detach will leave the resource in it's current state. |
| managementGroups | string | false    | Valid options: `delete` or `detatch`. Default: `detach`. Specifies the action that should be taken on the resource when the deployment stack is deleted. Delete will attempt to delete the resource from Azure. Detach will leave the resource in it's current state. |

Example:

```json
{
  "$schema": "https://raw.githubusercontent.com/climpr/climpr-schemas/refs/heads/main/schemas/v1.0.0/bicep-deployment/deploymentconfig.json#",
  "type": "deploymentStack",
  "scope": "subscription",
  "name": "stackName",
  "actionOnUnmanage": {
    "resources": "delete",
    "resourceGroups": "delete"
  }
}
```

##### denySettings

| Option             | Type    | Required | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------------------ | ------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| applyToChildScopes | boolean | false    | DenySettings will be applied to child scopes. Default: 'false'.                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| excludedActions    | array   | false    | List of role-based management operations that are excluded from the denySettings. Up to 200 actions are permitted. If the denySetting mode is set to 'denyWriteAndDelete', then the following actions are automatically appended to 'excludedActions': '\*/read' and 'Microsoft.Authorization/locks/delete'. If the denySetting mode is set to 'denyDelete', then the following actions are automatically appended to 'excludedActions': 'Microsoft.Authorization/locks/delete'. Duplicate actions will be removed. |
| excludedPrincipals | array   | false    | List of AAD principal IDs excluded from the lock. Up to 5 principals are permitted.                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| mode               | string  | false    | Valid options: `denyDelete`, `denyWriteAndDelete` and `none`. Default: `none`.                                                                                                                                                                                                                                                                                                                                                                                                                                      |

> [!NOTE]
> The denySettings object is required, even if no properties are specified.

> [!WARNING]
> If specifying `excludedPrincipals`, remember to add the Id of the deployment principal. Otherwise, the deployment will fail as the deployment principal is locked out itself.
> If the option is not specified, the deployment principal is added by default.

Example:

```json
{
  "$schema": "https://raw.githubusercontent.com/climpr/climpr-schemas/refs/heads/main/schemas/v1.0.0/bicep-deployment/deploymentconfig.json#",
  "type": "deploymentStack",
  "scope": "subscription",
  "name": "stackName",
  "denySettings": {
    "mode": "denyDelete",
    "excludedPrincipals": ["<guid>"]
  }
}
```

## How to use this action

This action can be used multiple ways.

- Single deployments
- Part of a dynamic, multi-deployment strategy using the `matrix` capabilities in Github.
- Part of a pull request event to plan changes using the `what-if: "true"` parameter.

It requires the repository to be checked out before use, and that the Github runner is logged in to the respective Azure environment.

It is called as a step like this:

```yaml
# ...
steps:
  - name: Checkout repository
    uses: actions/checkout@v4

  - name: Azure login via OIDC
    uses: azure/login@v2
    with:
      client-id: ${{ vars.APP_ID }}
      tenant-id: ${{ vars.TENANT_ID }}
      subscription-id: ${{ vars.SUBSCRIPTION_ID }}

  - name: Run Bicep deployments
    id: deploy-bicep
    uses: climpr/deploy-bicep@v1
    with:
      deployment-file-path: <Path to .bicepparam file>
      what-if: "false"
# ...
```

## Examples:

### Single deployment

```yaml
# .github/workflows/deploy-sample-deployment.yaml
name: Deploy sample-deployment

on:
  workflow_dispatch:

  schedule:
    - cron: 0 23 * * *

  push:
    branches:
      - main
    paths:
      - bicep-deployments/sample-deployment/prod.bicepparam

jobs:
  deploy-bicep:
    name: Deploy sample-deployment to prod
    runs-on: ubuntu-latest
    environment:
      name: prod
    permissions:
      id-token: write # Required for the OIDC Login
      contents: read # Required for repo checkout

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Azure login via OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ vars.APP_ID }}
          tenant-id: ${{ vars.TENANT_ID }}
          subscription-id: ${{ vars.SUBSCRIPTION_ID }}

      - name: Get Bicep Deployments
        id: get-bicep-deployments
        uses: climpr/get-bicep-deployments@v1
        with:
          deployments-root-directory: bicep-deployments
          pattern: sample-deployment

      - name: Run Bicep deployments
        id: deploy-bicep
        uses: climpr/deploy-bicep@v1
        with:
          deployment-file-path: bicep-deployments/sample-deployment/prod.bicepparam
```

### Multi-deployments

```yaml
# .github/workflows/deploy-bicep-deployments.yaml
name: Deploy Bicep deployments

on:
  schedule:
    - cron: 0 23 * * *

  push:
    branches:
      - main
    paths:
      - "**/bicep-deployments/**"

  workflow_dispatch:
    inputs:
      environment:
        type: environment
        description: Filter which environment to deploy to
      pattern:
        description: Filter deployments based on regex pattern. Matches against the deployment name (Directory name)
        required: false
        default: .*

jobs:
  get-bicep-deployments:
    runs-on: ubuntu-latest
    permissions:
      contents: read # Required for repo checkout

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Get Bicep Deployments
        id: get-bicep-deployments
        uses: climpr/get-bicep-deployments@v1
        with:
          deployments-root-directory: bicep-deployments
          event-name: ${{ github.event_name }}
          pattern: ${{ github.event.inputs.pattern }}
          environment: ${{ github.event.inputs.environment }}

    outputs:
      deployments: ${{ steps.get-bicep-deployments.outputs.deployments }}

  deploy-bicep-parallel:
    name: "[${{ matrix.Name }}][${{ matrix.Environment }}] Deploy"
    if: "${{ needs.get-bicep-deployments.outputs.deployments != '' && needs.get-bicep-deployments.outputs.deployments != '[]' }}"
    runs-on: ubuntu-latest
    needs:
      - get-bicep-deployments
    strategy:
      matrix:
        include: ${{ fromjson(needs.get-bicep-deployments.outputs.deployments) }}
      max-parallel: 10
      fail-fast: false
    environment:
      name: ${{ matrix.Environment }}
    permissions:
      id-token: write # Required for the OIDC Login
      contents: read # Required for repo checkout

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Azure login via OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ vars.APP_ID }}
          tenant-id: ${{ vars.TENANT_ID }}
          subscription-id: ${{ vars.SUBSCRIPTION_ID }}

      - name: Run Bicep deployments
        id: deploy-bicep
        uses: climpr/deploy-bicep@v1
        with:
          deployment-file-path: ${{ matrix.DeploymentFile }}
          what-if: "false"
```
