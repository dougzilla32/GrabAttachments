# Grab Attachments

This script searches for messages in your gmail "Inbox" folder.  For each matching message, it
downloads it's attachments (if any).  After downloading the attachments for all matching
messages, the messages are moved to the DOWNLOAD_DIR folder.  The messages are moved regardless
of whether any attachments are found.

This script has been tested on Mac OS and uses Homebrew.  It can likely be used on other
platforms with a few modifications but will not work as-is.
