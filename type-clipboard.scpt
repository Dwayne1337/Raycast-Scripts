#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Type Clipboard
# @raycast.mode silent
# @raycast.packageName Helpers
# @raycast.description Waits 2 seconds then types clipboard into the focused field (fast, line-by-line).
# @raycast.author You
# @raycast.authorURL https://raycast.com

-- Settings
set openChat to false -- IMPORTANT: prevents the leading "t"
set startDelay to 2.0
set perLineDelay to 0.0
set chunkLongLines to true
set maxChunkLength to 200
set pressEnterAtEnd to false

set clipText to (the clipboard as text)

delay startDelay

tell application "System Events"
    if openChat then
        keystroke "t"
        delay 0.12
    end if

    set lineList to paragraphs of clipText

    repeat with lineIndex from 1 to (count of lineList)
        set lineText to item lineIndex of lineList

        if lineText is not "" then
            if chunkLongLines and (count of characters of lineText) > maxChunkLength then
                set lineLen to (count of characters of lineText)
                set pos to 1
                repeat while pos is less than or equal to lineLen
                    set endPos to pos + maxChunkLength - 1
                    if endPos > lineLen then set endPos to lineLen
                    keystroke (text pos thru endPos of lineText)
                    set pos to endPos + 1
                end repeat
            else
                keystroke lineText
            end if
        end if

        if lineIndex < (count of lineList) then key code 36 -- Enter

        if perLineDelay > 0 then delay perLineDelay
    end repeat

    if pressEnterAtEnd then
        key code 36 -- Enter
    end if
end tell
