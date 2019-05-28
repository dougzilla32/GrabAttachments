#!/bin/bash

###################################################################################################
# !!!! Create a .grabrc in your home directory.  For example:
#
# USER="me@gmail.com:mypassword"
# MSGFOLDER="MyFolder"
# FROM=someone@gmail.com
# DOWNLOAD_DIR="$HOME/Downloads/Grab"
# DOWNLOAD_DIR_TMP="$HOME/Downloads/GrabTmp"
#
# This script searches for messages from in the "Inbox" folder.  For each matching message, it
# downloads it's attachments (if any).  After downloading the attachments for all matching
# messages, the messages are moved to the DOWNLOAD_DIR folder.  The messages are moved regardless
# of whether any attachments are found.
###################################################################################################

#
# Definitions
#

# This variable should be set to your gmail username and password. If you have multi-factor authentication
# enabled for your gmail/google account then you will need to generate an application specific password
# for use by this script. If you do not have multi-factor authentication enabled, then you will need
# to turn on access for less secure apps in your google account.
USER="USERNAME:PASSWORD"

# The gmail folder where the matching messages should be moved after the attachments are downloaded.
# This folder needs to exist in your gmail account.
MSGFOLDER="Folder"

# "From" email address
FROM=myaddress@gmail.com

# These variables determine the directories where attachments are downloaded.
DOWNLOAD_DIR="$HOME/Downloads/GrabMedia"
DOWNLOAD_DIR_TMP="$HOME/Downloads/GrabMediaTmp"

GMAIL="imaps://imap.gmail.com:993/"
INBOX="${GMAIL}INBOX"

# !!!! Create a .grabrc in your home directory.
if [ -f ~/.grabrc ] ; then
    source ~/.grabrc
fi

#
# Define functions
#

ansi()            { echo -e "\033[${1}m${*:2}\033[0m"; }
ansiStart()       { echo -e "\033[${1}m${*:2}"; }
ansiEnd()         { echo -e "${*:1}\033[0m"; }
ansi2()           { echo -e "\033[${1};${2}m${*:3}\033[0m"; }
ansi2Start()      { echo -e "\033[${1};${2}m${*:3}"; }
8bit()            { echo -e "\033[38;5;${1}m${*:2}\033[0m"; }
8bit2()           { echo -e "\033[${1};38;5;${2}m${*:3}\033[0m"; }

bold()            { ansi 1 "$@"; }
italic()          { ansi 3 "$@"; }
underline()       { ansi 4 "$@"; }
strikethrough()   { ansi 9 "$@"; }
brightgreen()     { ansi 92 "$@"; }
red()             { 8bit2 1 9 "$@"; }
boldbrightgreen() { ansi2 1 92 "$@"; }
boldbrightcyan()  { ansi2 1 96 "$@"; }
highlight()       { ansi2 1 92 "$@"; }
startHighlight()  { ansi2Start 1 92 "$@"; }
endHighlight()    { ansiEnd "$@"; }

join_by() {
    local IFS="$1"
    shift
    echo "$*"
}

trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   
    echo -n "$var"
}

# Immediately exit if any error is encountered
set -e

# Wget and Mpack are installed in /usr/local/bin 
export PATH="/usr/local/bin:$PATH"

#
# Process messages
#

# Ensure Homebrew, Wget and Mpack are installed
set +e
(hash brew 2>/dev/null)
HAS_BREW=$?
(hash wget 2>/dev/null)
HAS_WGET=$?
(hash mpack 2>/dev/null)
HAS_MPACK=$?
set -e

if [ $HAS_BREW != 0 -o $HAS_MPACK != 0 -o $HAS_WGET != 0 ] ; then
    echo $(highlight "This script requires 'Homebrew' (The missing package manager for macOS), 'Wget' (for downloading files")
    echo $(highlight "from the internet) and 'Mpack' (MIME mail packing and unpacking).")
    echo ""
    echo $(highlight "The Administrator password may be requested by the 'Homebrew', 'Wget' and 'Mpack' installers.")
    echo ""
    echo "Press RETURN or SPACEBAR to proceed with installation of 'Homebrew', 'Wget' and 'Mpack'."
    read -rsn1 -p"Press any other key to abort: " RESULT;echo
    if [ "$RESULT" != "" ] ; then
        exit 0
    fi
    hash brew 2>/dev/null || { echo "Installing 'Homebrew'" ; /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" ; }
    hash wget 2>/dev/null || { echo "" ; echo "Installing 'Wget'" ; brew install wget ; }
    hash mpack 2>/dev/null || { echo "" ; echo "Installing 'Mpack'" ; brew install mpack ; }
    echo ""
fi

mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR_TMP"
cd "$DOWNLOAD_DIR_TMP"
finish() {
    rmdir "$DOWNLOAD_DIR_TMP"
}
trap finish EXIT

# Abort the script if there are leftover files.
# Commenting out because it's ok to overwrite the leftovers.
# SUFFIXES="eml EML desc DESC"
# shopt -s nullglob
# for s in $SUFFIXES ; do
#     if [ -n "$(trim *.$s)" ] ; then
#         echo Error: found files with \"$s\" suffix >&2
#         exit 1
#     fi
# done
# shopt -u nullglob

# Example: ask about capabilities
# curl --user "$USER" --url "$GMAIL" --request 'CAPABILITY'

# Example: list all folders
# curl --user "$USER" --url "$GMAIL" --request 'LIST "" "*"'  

# Example: search all UIDs
# curl --user "$USER" --url "$INBOX" --request 'UID SEARCH ALL'

# Example: fetch header fields from first message
# curl --progress-bar --user "$USER" --url "${INBOX}/;UID=1/;SECTION=HEADER.FIELDS%20(DATE%20FROM%20TO%20SUBJECT)" --output "TEST.eml"

# Example: fetch header fields from first message using a request
#    Note: this does not produce any header output because of a known curl issue
# curl --progress-bar --user "$USER" --url "$INBOX" --request "FETCH 1 BODY[HEADER.FIELDS (DATE FROM TO SUBJECT)]" --output "TEST.eml"

# Example: fetch first message
# curl --progress-bar --user "$USER" --url "${INBOX};UID=1" --output "TEST.eml"

# Example: move a list of message ids
# curl --user "$USER" --url "$INBOX" --request "MOVE 39001,39151 Test"

# Example: move a list of unique ids
# curl --user "$USER" --url "$INBOX" --request "UID MOVE 39001,39151 Test"

echo $(highlight "Searching for messages from \"$FROM\"...")

set +e
MSGIDS=$(curl --no-verbose --progress-bar --user "$USER" --url "$INBOX" --request "SEARCH FROM $FROM")
MSGSTATUS=$?
set -e
if [ $MSGSTATUS -eq 67 ] ; then
    echo $(highlight "")
    echo $(red "Error: gmail login failed for \"$USER\"")
    echo $(highlight "Check to make sure your username and password are correct.")
    echo $(highlight "")
    echo $(highlight "If you have multi-factor authentication enabled for your gmail account")
    echo $(highlight "then you will need to generate an application specific password for use")
    echo $(highlight "by this script.")
    echo $(highlight "")
    echo $(highlight "If you do not have multi-factor authentication enabled then you have")
    echo $(highlight "likely received an email message stating that a sign-in attempt was")
    echo $(highlight "blocked for your google account.  To use this script you will need to")
    echo $(highlight "turn on access for less secure apps in your google account settings here:")
    echo $(highlight "")
    echo $(boldbrightcyan "https://myaccount.google.com/lesssecureapps")
fi
if [ $MSGSTATUS -ne 0 ] ; then
    exit $MSGSTATUS
fi

MSGIDS=$(echo "$MSGIDS" | cut -f3- -d" ")
MSGIDS=$(trim "$MSGIDS")
MSGSEQUENCE=$(join_by , $MSGIDS)
SUCCESS_SEQUENCE=""

if [ -n "$MSGIDS" ] ; then
    echo $(highlight "Message IDs: $MSGIDS")
else
    echo $(highlight "No messages from $FROM found")
    exit 0
fi

# I would prefer to use unique ids, but curl does not support fetching messages using unique ids
# UNIQUEIDS=$(curl --no-verbose --progress-bar --user "$USER" --url "$INBOX" --request "UID SEARCH FROM $FROM" | cut -f3- -d" ")
# UNIQUEIDS=$(trim "$UNIQUEIDS")

for id in $MSGIDS ; do
    ERROR_ID=0
    MSG="Message${id}.eml"
    echo " "
    echo $(startHighlight "Message ${id}...")

    curl --url "$INBOX;UID=${id}" --no-verbose --progress-bar --user "$USER" --output "$MSG"
    SUBJECT=$(grep -m 1 "^Subject: " "$MSG" | perl -CS -MEncode -ne 'print decode("MIME-Header", $_)')
    echo $(endHighlight "${SUBJECT}")

    grep -m 1 "^From: " "$MSG" | while read line ; do
        FROM_HEADER=$(echo "$line" | cut -d":" -f2 | awk -F '[<>]' '{print $2}')
        FROM_HEADER=$(trim $FROM_HEADER)
        if [ "$FROM_HEADER" != "$FROM" ] ; then
            echo $(red "Mismatched \"From\" line: \"$FROM_HEADER\" vs \"$FROM\"")
            echo $(red "One or more Inbox mail messages may have been deleted during script execution.")
            echo $(red "Deleting or moving messages from the Inbox will cause the script to fail due")
            echo $(red "to a limitation with IMAP mail ids and \"curl\".")
            rm -f "$MSG"
        fi
    done

    echo Extract attachments...
    munpack -f "$MSG" 2>&1 | grep -v "tempdesc.txt: File exists"
    rm -f *.desc

    set +e
    grep "^Image-Archive-Url: " "$MSG" | while read line ; do
        URL=$(echo "$line" | cut -d';' -f1 | cut -d' ' -f2)
        URL=$(trim $URL)
        FILE=Images.zip

        wget "$URL" --no-verbose --show-progress --output-document="$FILE"
#        curl --no-verbose --progress-bar --output "$FILE" "$URL"
        STATUS=$?

        if [ $STATUS -eq 0 ] ; then
            echo "$FILE"
            unzip -o "$FILE"
        fi
        rm -f "$FILE"
        exit $STATUS
    done
    STATUS=${PIPESTATUS[1]}
    if [ $STATUS -ne 0 ] ; then
        ERROR_ID=$STATUS
    fi
    set -e

    set +e
    grep "^Remote-Attachment-Url: " "$MSG" | while read line ; do
        URL=$(echo "$line" | cut -d';' -f1 | cut -d' ' -f2)
        FILE=$(echo "$line" | cut -d';' -f2 | cut -d'=' -f2)

        wget "$URL" --no-verbose --show-progress --output-document="$FILE"
#        curl --no-verbose --progress-bar --output "$FILE" "$URL"
        STATUS=$?

        if [ $STATUS -eq 0 ] ; then
            echo "$FILE"
            case "$FILE" in
                *.zip)
                    unzip -o "$FILE"
                    ;;
                *.ZIP)
                    unzip -o "$FILE"
                    ;;
            esac
        fi
        rm -f "$FILE"
        exit $STATUS
    done
    STATUS=${PIPESTATUS[1]}
    if [ $STATUS -ne 0 ] ; then
        ERROR_ID=$STATUS
    fi
    set -e

    rm -f "$MSG"

    if [ $ERROR_ID -eq 0 ] ; then
        if [ -n "$SUCCESS_SEQUENCE" ] ; then
            SUCCESS_SEQUENCE="$SUCCESS_SEQUENCE $id"
        else
            SUCCESS_SEQUENCE="$id"
        fi
    fi
done

shopt -s nullglob
DOWNLOAD_FILES=$(trim "$DOWNLOAD_DIR_TMP"/*)
if [ -n "$DOWNLOAD_FILES" ] ; then
    echo -n Move attachments to \"$DOWNLOAD_DIR\" folder...
    mv -f "$DOWNLOAD_DIR_TMP"/* "$DOWNLOAD_DIR"
    echo " done"
fi
shopt -u nullglob

MSGIDS_AFTER=$(curl --no-verbose --progress-bar --user "$USER" --url "$INBOX" --request "SEARCH FROM $FROM" | cut -f3- -d" ")
MSGIDS_AFTER=$(trim "$MSGIDS")
MSGSEQUENCE_AFTER=$(join_by , $MSGIDS)

if [[ "$MSGSEQUENCE_AFTER" != "$MSGSEQUENCE"* ]] ; then
    echo $(red "Unable to move email messages to \"$MSGFOLDER\" folder due to mismatched")
    echo $(red "message ids (before \"$MSGSEQUENCE_AFTER\" vs after \"$MSGSEQUENCE\")")
    echo $(red "")
    echo $(red "One or more Inbox mail messages may have been deleted during script")
    echo $(red "execution.  Deleting or moving any messages from the Inbox will cause")
    echo $(red "the script to fail due to a limitation with IMAP mail ids and \"curl\".")
    exit 1
fi

set +e
if [ -n "$SUCCESS_SEQUENCE" ] ; then
    echo -n Move email messages from \"$FROM\" to folder \"$MSGFOLDER\"...
    curl --user "$USER" --url "$INBOX" --request "MOVE $SUCCESS_SEQUENCE $MSGFOLDER"
    if [ $? != 0 ] ; then
        echo $(red "Move email messages failed, likely because the email folder \"$MSGFOLDER\" does not exist.")
    else
        echo " done"
    fi
fi
set -e

echo $(highlight "Done!")
