targetScope = 'subscription'

module submodule 'br/public:avm/res/resources/resource-group:0.2.3' = {
  name: '${deployment().name}-rg'
  params: {
    name: 'resourceGroupName'
  }
}
