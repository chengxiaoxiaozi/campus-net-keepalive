#Requires AutoHotkey v2.0
#SingleInstance Force

scriptDir := A_ScriptDir
configPath := scriptDir "\config.ini"
logPath := scriptDir "\keepalive.log"
lockPath := scriptDir "\keepalive.lock"
lastAttemptPath := scriptDir "\last_attempt.txt"

Log(message) {
    global logPath
    FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " message "`n", logPath, "UTF-8")
}

ReadSetting(section, key, defaultValue := "") {
    global configPath
    try {
        value := IniRead(configPath, section, key, defaultValue)
        return Trim(value)
    } catch Error {
        return defaultValue
    }
}

SplitCsv(value) {
    items := []
    for part in StrSplit(value, ",") {
        part := Trim(part)
        if part != ""
            items.Push(part)
    }
    return items
}

IsOnline(urls, timeoutMs) {
    for url in urls {
        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
            req.Open("GET", url, false)
            req.SetRequestHeader("Cache-Control", "no-cache")
            req.Send()
            status := req.Status
            if (status >= 200 && status < 400) {
                return true
            }
        } catch Error as e {
            ; Try the next probe URL.
        }
    }
    return false
}

UnixNow() {
    return DateDiff(A_NowUTC, "19700101000000", "Seconds")
}

InCooldown(cooldownSeconds) {
    global lastAttemptPath
    if !FileExist(lastAttemptPath)
        return false
    try {
        last := Integer(Trim(FileRead(lastAttemptPath, "UTF-8")))
        return (UnixNow() - last) < cooldownSeconds
    } catch Error {
        return false
    }
}

WriteAttemptTime() {
    global lastAttemptPath
    try FileDelete(lastAttemptPath)
    FileAppend(String(UnixNow()), lastAttemptPath, "UTF-8")
}

ResolvePath(pathValue) {
    global scriptDir
    if InStr(pathValue, ":\") || SubStr(pathValue, 1, 2) = "\\"
        return pathValue
    return scriptDir "\" pathValue
}

ClickSigninButton(buttonImg, variation, pageWaitMs, afterClickWaitMs, authUrl) {
    existing := WinGetList("ahk_exe msedge.exe")

    Run('msedge.exe --new-window "' authUrl '"')
    Sleep pageWaitMs

    newEdgeHwnd := 0
    allNow := WinGetList("ahk_exe msedge.exe")
    for hwnd in allNow {
        found := false
        for old in existing {
            if (hwnd = old) {
                found := true
                break
            }
        }
        if !found {
            newEdgeHwnd := hwnd
            break
        }
    }

    if !newEdgeHwnd {
        Log("Edge window not found.")
        return false
    }

    WinActivate(newEdgeHwnd)
    Sleep 1200

    CoordMode("Pixel", "Screen")
    CoordMode("Mouse", "Screen")

    left := Round(A_ScreenWidth * 0.15)
    top := Round(A_ScreenHeight * 0.15)
    right := Round(A_ScreenWidth * 0.85)
    bottom := Round(A_ScreenHeight * 0.9)

    try {
        if ImageSearch(&x, &y, left, top, right, bottom, "*" variation " " buttonImg) {
            Click x + 50, y + 18
            Log("Signin button clicked.")
            Sleep afterClickWaitMs
            try WinClose(newEdgeHwnd)
            return true
        }
        Log("Signin button image not found.")
    } catch Error as e {
        Log("ImageSearch error: " e.Message)
    }

    try WinClose(newEdgeHwnd)
    return false
}

if !FileExist(configPath) {
    Log("Missing config.ini. Copy config.example.ini to config.ini first.")
    ExitApp
}

if FileExist(lockPath) {
    try {
        ageSeconds := DateDiff(A_Now, FileGetTime(lockPath, "M"), "Seconds")
        if ageSeconds < 300 {
            Log("Another instance is running. Exit.")
            ExitApp
        }
    } catch Error {
        ; Stale or unreadable lock. Continue and replace it.
    }
}

try FileDelete(lockPath)
FileAppend(String(A_Pid), lockPath, "UTF-8")
try {
    authUrl := ReadSetting("auth", "url")
    probeUrls := SplitCsv(ReadSetting("probe", "urls", "https://www.baidu.com/"))
    timeoutMs := Integer(ReadSetting("probe", "timeout_ms", "3000"))
    buttonImg := ResolvePath(ReadSetting("ui", "button_image", "signin_button.png"))
    pageWaitMs := Integer(ReadSetting("ui", "page_wait_ms", "10000"))
    afterClickWaitMs := Integer(ReadSetting("ui", "after_click_wait_ms", "5000"))
    variation := Integer(ReadSetting("ui", "image_variation", "35"))
    cooldownSeconds := Integer(ReadSetting("guard", "cooldown_seconds", "120"))

    if authUrl = "" {
        Log("Missing [auth] url.")
        ExitApp
    }

    if !FileExist(buttonImg) {
        Log("Missing button image: " buttonImg)
        ExitApp
    }

    if IsOnline(probeUrls, timeoutMs) {
        Log("Online. Nothing to do.")
        ExitApp
    }

    if InCooldown(cooldownSeconds) {
        Log("Offline, but still in cooldown. Exit.")
        ExitApp
    }

    WriteAttemptTime()
    Log("Offline detected. Start browser signin.")
    ClickSigninButton(buttonImg, variation, pageWaitMs, afterClickWaitMs, authUrl)
} finally {
    try FileDelete(lockPath)
}

ExitApp
