#Requires AutoHotkey v2.0

state := 0
tabInterval := 1000

tabSound := CreateSound(600, 120)
tapSound := CreateSound(1200, 180)

OnExit Cleanup

Esc::
{
    global state, tabInterval

    if (state = 0)
    {
        state := 1
        SetTimer PressTab, tabInterval
        PressTab()
    }
    else if (state = 1)
    {
        state := 2
        SetTimer PressTab, 0

        Send "{Enter}"
        PlaySound(tapSound)
    }
    else
    {
        state := 1
        SetTimer PressTab, tabInterval
        PressTab()
    }
}

PressTab()
{
    global tabSound

    Send "{Tab}"
    PlaySound(tabSound)
}

CreateSound(frequency, duration)
{
    sampleRate := 44100
    samples := Round(sampleRate * duration / 1000)
    dataSize := samples * 2

    ; WAVEFORMATEX
    format := Buffer(18, 0)

    NumPut("UShort", 1, format, 0)              ; PCM
    NumPut("UShort", 1, format, 2)              ; Mono
    NumPut("UInt", sampleRate, format, 4)
    NumPut("UInt", sampleRate * 2, format, 8)
    NumPut("UShort", 2, format, 12)
    NumPut("UShort", 16, format, 14)
    NumPut("UShort", 0, format, 16)

    ; PCM data
    data := Buffer(dataSize, 0)
    amplitude := 12000

    Loop samples
    {
        t := (A_Index - 1) / sampleRate

        ; Small fade-in/out to avoid clicks
        fadeSamples := Round(sampleRate * 0.005)
        envelope := 1.0

        if (A_Index <= fadeSamples)
            envelope := A_Index / fadeSamples
        else if (A_Index > samples - fadeSamples)
            envelope := (samples - A_Index) / fadeSamples

        value := Round(
            amplitude
            * envelope
            * Sin(2 * 3.14159265358979 * frequency * t)
        )

        NumPut("Short", value, data, (A_Index - 1) * 2)
    }

    ; WAVEHDR
    header := Buffer(48, 0)

    NumPut("Ptr", data.Ptr, header, 0)
    NumPut("UInt", dataSize, header, 8)

    waveOut := 0

    result := DllCall(
        "winmm\waveOutOpen",
        "Ptr*", &waveOut,
        "UInt", 0xFFFFFFFF,
        "Ptr", format.Ptr,
        "Ptr", 0,
        "Ptr", 0,
        "UInt", 0
    )

    if (result != 0)
        throw Error("waveOutOpen failed: " result)

    result := DllCall(
        "winmm\waveOutPrepareHeader",
        "Ptr", waveOut,
        "Ptr", header.Ptr,
        "UInt", header.Size
    )

    if (result != 0)
        throw Error("waveOutPrepareHeader failed: " result)

    return {
        waveOut: waveOut,
        data: data,
        header: header
    }
}

PlaySound(sound)
{
    ; Reset only if the previous playback has finished.
    flags := NumGet(sound.header, 16, "UInt")

    if (flags & 0x00000001)
        return

    DllCall(
        "winmm\waveOutWrite",
        "Ptr", sound.waveOut,
        "Ptr", sound.header.Ptr,
        "UInt", sound.header.Size
    )
}

Cleanup(*)
{
    global tabSound, tapSound

    CleanupSound(tabSound)
    CleanupSound(tapSound)
}

CleanupSound(sound)
{
    if !IsObject(sound)
        return

    DllCall(
        "winmm\waveOutReset",
        "Ptr", sound.waveOut
    )

    DllCall(
        "winmm\waveOutUnprepareHeader",
        "Ptr", sound.waveOut,
        "Ptr", sound.header.Ptr,
        "UInt", sound.header.Size
    )

    DllCall(
        "winmm\waveOutClose",
        "Ptr", sound.waveOut
    )
}