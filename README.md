---
name: EventHub SDK-Type Bindings with Azure Functions (Python)
description: Bind to rich SDK types when using EventHub trigger.
languages:
- python
products:
- azure
- azure-functions
- azure-eventhub
- sdk-bindings
page_type: sample
urlFragment: eventhub-sdk-type-bindings-with-azure-functions

---
<!-- YAML front-matter schema: https://review.learn.microsoft.com/en-us/help/contribute/samples/process/onboarding?branch=main#supported-metadata-fields-for-readmemd -->

# EventHub SDK-Type Bindings with Azure Functions (Python)

This sample demonstrates how to use the Azure Functions EventHub SDK-type bindings in Python. The supported SDK types includes EventData.

You can learn more about SDK-type bindings for EventHub in the [SDK-type Bindings for Python Reference](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=get-started%2Casgi%2Capplication-level&pivots=python-mode-decorators#sdk-type-bindings).

## Prerequisites

Before running the sample, you need the following:

1. **Azure Subscription**: An [Azure account](https://azure.com/free) is required.
   
2. **Azure Functions Core Tools**: Install [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Cisolated-process%2Cnode-v4%2Cpython-v2%2Chttp-trigger%2Ccontainer-apps&pivots=programming-language-python) to run and test functions locally.

3. **A Supported Version of Python**: Visit the [Supported Python versions page](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=get-started%2Casgi%2Capplication-level&pivots=python-mode-decorators#supported-python-versions) to learn more. The Azure deployments use Python 3.14, which is currently a preview runtime in Azure Functions.

4. **Azure Developer CLI**: Install the [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd) to provision and deploy the sample.

5. **Azure Storage Account**: For local testing, create a [storage account](https://learn.microsoft.com/azure/storage/common/storage-account-overview) or run Azurite and update `local.settings.json`.

## Using SDK-type Bindings for EventHub in an Azure Function App
The code in the sample folder has already been updated to support use of SDK-type bindings for EventHub. Let's walk through the changed files.

The `requirements.txt` file has an additional dependency of the `azurefunctions-extensions-bindings-eventhub` module:

```
azure-functions
azurefunctions-extensions-bindings-eventhub
```

The eventhub_samples_eventdata folder contains `function_app.py` which imports the `azurefunctions-extensions-bindings-eventhub` module.
```python
import azure.functions as func
import azurefunctions.extensions.bindings.eventhub as eventhub
```

In each `function_app.py` file, there are two functions defined: both EventHub triggers. Both of these functions specify an arg
named `event` and define the type as an SDK-type.

The eventhub_samples_eventdata directory shows the type defined as `EventData`.
```python
@app.event_hub_message_trigger(
    arg_name="event", event_hub_name="EVENTHUB_NAME", connection="EventHubConnection"
)
def eventhub_trigger(event: eh.EventData):
```

## Running the sample
### Testing Locally
1. **Clone the repository**: 
    ```
        git clone https://github.com/Azure-Samples/azure-functions-eventhub-sdk-bindings-python.git
    ```
2. **Navigate to the project directory**:
    ```
        cd eventhub_samples_eventdata
    ```
3. Create a [Python virtual environment](https://docs.python.org/3/tutorial/venv.html#creating-virtual-environments) and activate it.
4. **Install the required dependencies**:
    ```
        pip install -r requirements.txt
    ```
5. **Update `local.settings.json`**: replace `EventHubConnection` with your desired EventHub connection string.
6. **Update the EventHub name**: in `function_app.py`, replace EVENTHUB_NAME with your EventHub name.
7. **Start the function**: If you are using VS Code for development, click the "Run and Debug" button or follow [the instructions for running a function locally](https://docs.microsoft.com/azure/azure-functions/create-first-function-vs-code-python#run-the-function-locally). Outside of VS Code, follow [these instructions for using Core Tools commands directly to run the function locally](https://docs.microsoft.com/azure/azure-functions/functions-run-local?tabs=v4%2Cwindows%2Cpython%2Cportal%2Cbash#start).
   ```
       Functions:
               eventhub_trigger: eventHubTrigger
   ```
8. **Execute the function**: 
   - EventHub trigger: upload an event to the EventHub instance in any way (such as using an EventHub output function). You should see the log below printed in the terminal, where the EventHub message that was sent is printed as a string.
   ```
      Python EventHub trigger processed an event { ... }
   ```

### Deploying to Azure

The repository includes Azure Developer CLI (`azd`) configuration for the function app. From the repository root, sign in and provision the resources and application code:

```
azd auth login
azd up
```

Select a subscription and a region that supports the Flex Consumption plan when prompted. The deployment creates a Python 3.14 Linux Flex Consumption Function App, Event Hubs namespace and hub, managed identity, storage account, Log Analytics workspace, and Application Insights resource. Storage and Event Hubs access use managed identity rather than deployed connection-string secrets.

To deploy code changes without reprovisioning the infrastructure, run `azd deploy`. To delete all resources created for the environment, run `azd down`.

You can also deploy using these other tools:

* [Deploy with the VS Code Azure Functions extension](https://docs.microsoft.com/en-us/azure/azure-functions/create-first-function-vs-code-python#publish-the-project-to-azure). 
* [Deploy with the Azure CLI](https://docs.microsoft.com/en-us/azure/azure-functions/create-first-function-cli-python?tabs=azure-cli%2Cbash%2Cbrowser#create-supporting-azure-resources-for-your-function).

## Next Steps
Visit the [SDK-type bindings in Python reference documentation](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=get-started%2Casgi%2Capplication-level&pivots=python-mode-decorators#sdk-type-bindings) to learn more about how to use SDK-type bindings in a Python Function App and the [API reference documentation](https://learn.microsoft.com/en-us/python/api/azure-eventhub/azure.eventhub?view=azure-python) to learn more about what you can do with the Azure EventHub library.
