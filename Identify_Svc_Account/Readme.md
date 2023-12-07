This script fetches and displays service account information from three sources:

1. Running services that are set to start automatically.
2. Scheduled tasks that are in 'Ready' or 'Running' state.
3. Services registered within the Service Control Manager (SCM) in the system registry.

By default, the script will display service account details for all entities in these categories. However, users can specify the optional `-FilterAccount` parameter to filter the results based on a specific service account or a substring of it.


Meant to run as a scripted action in Controlup
