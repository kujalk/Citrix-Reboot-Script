# Citrix-Reboot-Script
Script to reboot citrix (xen) servers



Take all the servers that are allocated in the given workergroup and apply the "ProhibitNewLogOnsUntilRestart" Login mode to all servers. Wait for 12 hours and check for any user sessions, if no any user sessions are found the Citrix servers will be rebooted and it will be logged to Reboot.txt. If there are any active sessions found in the Citrix servers, all the details will be logged to Active.txt file. Here Active sessions > 24 hrs and < 24 hrs are logged seperately. If there are any disconnected sessions found with less than 3 hrs, then all the details will be logged to Disconnect.txt file. If the disconnected sessions are more than 3 hrs, then the Citrix servers will be rebooted and logged to Reboot.txt. After that a table (In .html web page) will be prepared showing a summary of which servers are rebooted successfully, servers with Active sessions, servers with Disconnected sessions and servers still with "ProhibitNewLogOnsUntilRestart". All these logs and html web page will be sent to Citrix team members email address finally.
