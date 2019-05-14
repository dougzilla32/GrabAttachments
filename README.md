![badge-platforms](https://img.shields.io/badge/platform-osx-blue.svg)
![badge-languages](https://img.shields.io/badge/languages-bash-orange.svg)
![badge-requirements](https://img.shields.io/badge/requirements-Homebrew,%20curl,%20wget%20%26%20mpack-green.svg)

# Grab Attachments

This script searches for messages in your gmail "Inbox" folder.  For each matching message, it
downloads it's attachments (if any).  After downloading the attachments for all matching
messages, the messages are moved to the DOWNLOAD_DIR folder.  The messages are moved regardless
of whether any attachments are found.

This script has been tested on Mac OS and uses Homebrew.  It can likely be used on other
platforms with a few modifications but will not work as-is.
