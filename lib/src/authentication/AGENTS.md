# Working Notes for authentication
- Uses the exact same credentials for both XMPP (chat) and SMTP (email). Account creation MUST be enforce atomicity, either BOTH accounts are created or BOTH fail.
- We MUST NEVER enter a bricked state. All asynchronous failures MUST be recoverable and display errors helpfully in the UI. Any delete requests which fail must not be dequeued until they succeed.