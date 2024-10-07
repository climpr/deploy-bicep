# Deploy Bicep

This action deploys a Bicep deployment based on a `.bicepparam`file.
It supports the use of the `deploymentconfig.json` file for advanced deployment options.

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
    uses: climpr/deploy-bicep@v0
    with:
      parameter-file-path: <Path to .bicepparam file>
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
    runs-on: ubuntu-22.04
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
        uses: climpr/get-bicep-deployments@v0
        with:
          deployments-root-directory: bicep-deployments
          pattern: sample-deployment

      - name: Run Bicep deployments
        id: deploy-bicep
        uses: climpr/deploy-bicep@v0
        with:
          parameter-file-path: bicep-deployments/sample-deployment/prod.bicepparam
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
    runs-on: ubuntu-22.04
    permissions:
      contents: read # Required for repo checkout

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Get Bicep Deployments
        id: get-bicep-deployments
        uses: climpr/get-bicep-deployments@v0
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
    runs-on: ubuntu-22.04
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
        uses: climpr/deploy-bicep@v0
        with:
          parameter-file-path: ${{ matrix.ParameterFile }}
          what-if: "false"
```
