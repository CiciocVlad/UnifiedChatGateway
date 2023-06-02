# ChatGateway

Main responsibilities of Chat Gateway are:
 * Handling and managing customer connection requests
 * Augment customer messages with internal information about the session
 * Strip internal information from replies sent to the customer client
 * Manage the connection with Cirrus
 * Handling contents such as images, audio, ..
 * Manage the agent chat thread connection
 * Maintain the persistence of the chat session to provide protection against temporary disconnections by the agent/customer
 * Create the Chat transaction document enabling customer data from the chat channel to be exchanged with other media channels
 * Produce chat transcripts
 * Provide an API to download chat forms

To start your Chat Gatewat:

  * Install dependencies with `mix deps.get` or simple run `make` (install deps and compile source code)
  * Start Chat Gateway endpoint with dev mode `./start-dev.sh`

Ready to run in production?
  * For normal rpm, please run `make -C package rpm RELEASE_NUMBER={RELEASE_NUMBER}`
  * For docker rpm, please run `make -C package docker-rpm RELEASE_NUMBER={RELEASE_NUMBER}`

## Learn more

  * Chat Gateway Specs: https://pt-hcc.atlassian.net/wiki/spaces/CHAT/pages/1072988250/Chat+gateway
  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
