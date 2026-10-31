# ``OpenRouterLanguageModel``

## Topics

### Creating a model

- <doc:GettingStarted>
- ``init(_:fallbacks:serverTools:routing:options:cacheControl:responseCache:app:session:idleTimeout:auth:)``
- ``init(_:)``

### Describing the model

- ``details``
- ``capabilities``
- ``reasoningLevel(_:)``
- ``supportsDataAttachmentType(_:)``
- ``supportsDataEntryType(_:)``

### Reading model info

- <doc:ModelAndProviderInfo>
- ``providers()``
- ``currentDetails()``
- ``currentPricing()``

### Choosing models and hosts

- ``fallbacks``
- ``routing``

### Setting requests

- ``serverTools``
- ``options``
- ``cacheControl``
- ``responseCache``

### Sending requests

- ``auth``
- ``OpenRouterAuthentication``
- ``app``
- ``session``
- ``idleTimeout``
- ``executorConfiguration``
- ``RequestExecutor``
