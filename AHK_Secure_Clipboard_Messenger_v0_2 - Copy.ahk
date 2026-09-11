#Requires AutoHotkey v2.0+
#SingleInstance Force

; ======================================================================================================================
; AHK SECURE CLIPBOARD MESSENGER v0.2
; AutoHotkey v2 - 64-bit Windows
;
; PURPOSE
;   Encrypt a message locally -> copy ciphertext to clipboard -> manually paste it into Discord/DM/email/etc.
;   Recipient manually copies the ciphertext -> presses Decrypt Clipboard -> plaintext appears locally.
;
; SECURITY DESIGN
;   - No Discord bot
;   - No Discord API
;   - No automated Discord account control
;   - AES-256-GCM authenticated encryption through Windows CNG (bcrypt.dll)
;   - BCryptGenRandom for cryptographically secure random bytes
;   - HKDF-SHA256 derives a different directional key for A->B and B->A
;   - One independent 256-bit master secret per pair
;   - Windows DPAPI protects saved pair secrets on disk
;   - Random 128-bit message IDs
;   - 96-bit AES-GCM nonce per message
;   - Routing metadata is authenticated as AES-GCM AAD
;   - Plaintext chat messages are never written to disk by this script
;
; PAIRING MODEL
;   A <-> B has one random pair secret.
;   C <-> D has a completely unrelated pair secret.
;   Everyone may use the same .ahk program and the same Discord channel.
;   A/B cannot decrypt C/D ciphertext and C/D cannot decrypt A/B ciphertext.
;
; IMPORTANT
;   - The pairing code itself is a secret. Anyone who gets it can decrypt that pair's future messages.
;   - Exchange pairing codes out-of-band if you want Discord itself to never learn the key.
;   - This is a serious prototype, not an independently audited messenger.
;   - Because both members of a pair share one symmetric master key, either member could technically forge the other's
;     messages. A later version can add per-user signing keys to prevent that.
;
; HOTKEYS
;   Ctrl+Shift+E   Encrypt text in the message box and copy ciphertext
;   Ctrl+Shift+D   Decrypt the current clipboard
;   Shift+Esc      Exit
; ======================================================================================================================

if A_PtrSize != 8 {
    MsgBox(
        "This prototype requires 64-bit AutoHotkey v2.`n`n"
        . "Run the 64-bit build of AutoHotkey v2 and try again.",
        "AHK Secure Clipboard Messenger",
        "Iconx"
    )
    ExitApp
}

class SecureClipboardMessenger {
    static Version := "0.2"
    static Protocol := "AHKCLIP2"

    static AppDir := A_AppData "\AHKSecureClipboardMessenger"
    static ConfigFile := SecureClipboardMessenger.AppDir "\config.ini"

    static UserId := ""
    static Contacts := Map()

    static MainGui := 0
    static PeerCtrl := 0
    static MessageCtrl := 0
    static OutputCtrl := 0
    static StatusCtrl := 0
    static AutoDecryptCtrl := 0

    static LastClipboardCiphertext := ""

    static Start() {
        DirCreate(this.AppDir)

        try {
            Crypto.SelfTest()
        } catch as err {
            MsgBox(
                "The local cryptography self-test failed, so the messenger will not start.`n`n"
                . err.Message,
                "Cryptography Self-Test Failed",
                "Iconx"
            )
            ExitApp
        }

        if !this.LoadOrCreateIdentity()
            ExitApp

        this.LoadContacts()
        this.BuildGui()

        OnClipboardChange(ObjBindMethod(this, "ClipboardChanged"))

        this.SetStatus("Ready. Nothing is connected to Discord; clipboard transport only.")
    }

    static LoadOrCreateIdentity() {
        userId := IniRead(this.ConfigFile, "General", "UserId", "")

        if RegExMatch(userId, "^[A-Za-z0-9_-]{1,24}$") {
            this.UserId := userId
            return true
        }

        result := InputBox(
            "Choose this computer's messenger ID.`n`n"
            . "Use letters, numbers, underscore, or hyphen.`n"
            . "Examples: A   B   Alice   Bob-PC",
            "First-Run Setup",
            "w520 h180"
        )

        if result.Result != "OK"
            return false

        userId := Trim(result.Value)

        if !RegExMatch(userId, "^[A-Za-z0-9_-]{1,24}$") {
            MsgBox(
                "Invalid ID.`n`nUse 1-24 letters, numbers, underscore, or hyphen.",
                "Invalid ID",
                "Iconx"
            )
            return false
        }

        IniWrite(userId, this.ConfigFile, "General", "UserId")
        IniWrite("", this.ConfigFile, "General", "Peers")

        this.UserId := userId
        return true
    }

    static LoadContacts() {
        this.Contacts := Map()

        peersText := IniRead(this.ConfigFile, "General", "Peers", "")
        if peersText = ""
            return

        for _, peer in StrSplit(peersText, ",") {
            peer := Trim(peer)

            if peer = ""
                continue

            protectedPacket := IniRead(this.ConfigFile, "Contacts", peer, "")
            if protectedPacket = ""
                continue

            try {
                packet := Crypto.DpapiUnprotectFromBase64(protectedPacket)

                if packet.Size != 48
                    continue

                conversationRaw := Crypto.Slice(packet, 0, 16)
                master := Crypto.Slice(packet, 16, 32)

                this.Contacts[peer] := Map(
                    "Peer", peer,
                    "Conversation", Crypto.Base64Encode(conversationRaw),
                    "ConversationRaw", conversationRaw,
                    "Master", master
                )
            } catch {
                ; If Windows DPAPI cannot unlock a contact, ignore that entry.
            }
        }
    }

    static SaveContact(peer, packet) {
        if !RegExMatch(peer, "^[A-Za-z0-9_-]{1,24}$")
            throw Error("Invalid peer ID.")

        if packet.Size != 48
            throw Error("Invalid pairing packet.")

        protectedPacket := Crypto.DpapiProtectToBase64(packet)
        IniWrite(protectedPacket, this.ConfigFile, "Contacts", peer)

        peers := []
        current := IniRead(this.ConfigFile, "General", "Peers", "")

        if current != "" {
            for _, existing in StrSplit(current, ",") {
                existing := Trim(existing)

                if existing != "" && !this.ArrayContains(peers, existing)
                    peers.Push(existing)
            }
        }

        if !this.ArrayContains(peers, peer)
            peers.Push(peer)

        IniWrite(this.Join(peers, ","), this.ConfigFile, "General", "Peers")

        this.LoadContacts()
        this.RefreshPeerList(peer)
    }

    static RemoveContact(peer) {
        if !this.Contacts.Has(peer)
            return

        try IniDelete(this.ConfigFile, "Contacts", peer)

        peers := []
        current := IniRead(this.ConfigFile, "General", "Peers", "")

        if current != "" {
            for _, existing in StrSplit(current, ",") {
                existing := Trim(existing)

                if existing != "" && existing != peer
                    peers.Push(existing)
            }
        }

        IniWrite(this.Join(peers, ","), this.ConfigFile, "General", "Peers")
        this.LoadContacts()
        this.RefreshPeerList()
    }

    static BuildGui() {
        g := Gui("+Resize +MinSize760x610", "AHK Secure Clipboard Messenger v" this.Version)
        g.SetFont("s10", "Segoe UI")

        g.AddText("x16 y14 w700", "Local ID: " this.UserId "    |    Transport: clipboard only")

        g.AddText("x16 y50 w42", "Peer:")
        peerCtrl := g.AddDropDownList("x62 y46 w205")
        this.PeerCtrl := peerCtrl

        createBtn := g.AddButton("x280 y45 w112 h30", "Create Pair")
        importBtn := g.AddButton("x402 y45 w112 h30", "Import Pair")
        removeBtn := g.AddButton("x524 y45 w112 h30", "Remove Pair")

        g.AddText("x16 y92 w700", "Message to encrypt:")
        msg := g.AddEdit("x16 y116 w710 h125 WantTab")
        this.MessageCtrl := msg

        encryptBtn := g.AddButton("x16 y252 w230 h42 Default", "Encrypt + Copy")
        decryptBtn := g.AddButton("x258 y252 w230 h42", "Decrypt Clipboard")
        clearBtn := g.AddButton("x500 y252 w226 h42", "Clear Plaintext")

        autoCtrl := g.AddCheckBox("x16 y308 w420", "Auto-decrypt copied AHKCLIP2 messages")
        this.AutoDecryptCtrl := autoCtrl

        g.AddText("x16 y344 w700", "Decrypted message / result:")
        output := g.AddEdit("x16 y368 w710 h170 ReadOnly +VScroll")
        this.OutputCtrl := output

        status := g.AddText("x16 y556 w710", "Starting...")
        this.StatusCtrl := status

        createBtn.OnEvent("Click", ObjBindMethod(this, "CreatePair"))
        importBtn.OnEvent("Click", ObjBindMethod(this, "ImportPair"))
        removeBtn.OnEvent("Click", ObjBindMethod(this, "RemoveSelectedPair"))
        encryptBtn.OnEvent("Click", ObjBindMethod(this, "EncryptAndCopy"))
        decryptBtn.OnEvent("Click", ObjBindMethod(this, "DecryptClipboard"))
        clearBtn.OnEvent("Click", ObjBindMethod(this, "ClearPlaintext"))

        g.OnEvent("Size", ObjBindMethod(this, "OnGuiSize"))
        g.OnEvent("Close", (*) => ExitApp())

        this.MainGui := g
        this.RefreshPeerList()

        output.Value :=
            "The program is ready.`r`n`r`n"
            . "1. Create/import a pair.`r`n"
            . "2. Type a message.`r`n"
            . "3. Click Encrypt + Copy.`r`n"
            . "4. Paste the ciphertext into Discord manually.`r`n"
            . "5. Recipient copies it and clicks Decrypt Clipboard."

        g.Show("w758 h600")
    }

    static OnGuiSize(guiObj, minMax, width, height) {
        if minMax = -1
            return

        if !this.MessageCtrl
            return

        margin := 16
        usableW := width - (margin * 2)

        this.MessageCtrl.Move(margin, 116, usableW, 125)
        this.OutputCtrl.Move(margin, 368, usableW, Max(120, height - 430))
        this.StatusCtrl.Move(margin, height - 34, usableW, 22)
    }

    static RefreshPeerList(preferred := "") {
        if !this.PeerCtrl
            return

        peers := []
        for peer, _ in this.Contacts
            peers.Push(peer)

        this.PeerCtrl.Delete()

        if !peers.Length
            return

        this.PeerCtrl.Add(peers)

        chosen := 1

        if preferred != "" {
            for index, peer in peers {
                if peer = preferred {
                    chosen := index
                    break
                }
            }
        }

        this.PeerCtrl.Choose(chosen)
    }

    static CreatePair(*) {
        result := InputBox(
            "Enter the OTHER person's local messenger ID.`n`n"
            . "Example: if this computer is A, enter B.",
            "Create Private Pair",
            "w520 h160"
        )

        if result.Result != "OK"
            return

        peer := Trim(result.Value)

        if !RegExMatch(peer, "^[A-Za-z0-9_-]{1,24}$") {
            MsgBox("Invalid peer ID.", "Create Pair", "Iconx")
            return
        }

        if peer = this.UserId {
            MsgBox("The peer cannot have the same ID as this computer.", "Create Pair", "Iconx")
            return
        }

        if this.Contacts.Has(peer) {
            answer := MsgBox(
                "A pair with " peer " already exists.`n`n"
                . "Replacing it makes previous ciphertext unreadable with the new key.`n"
                . "The other person will also need the new pairing code.`n`n"
                . "Replace it?",
                "Replace Existing Pair?",
                "YesNo Icon!"
            )

            if answer != "Yes"
                return
        }

        ; 16 bytes: opaque conversation ID
        ; 32 bytes: 256-bit master secret
        packet := Crypto.Concat([
            Crypto.RandomBytes(16),
            Crypto.RandomBytes(32)
        ])

        this.SaveContact(peer, packet)

        pairCode := "AHKPAIR2:" Crypto.Base64Encode(packet)
        fingerprint := Crypto.Fingerprint(packet)

        A_Clipboard := pairCode
        SetTimer(ObjBindMethod(this, "ClearClipboardIfMatch", pairCode), -60000)

        MsgBox(
            "Private pair created for " peer ".`n`n"
            . "PAIR FINGERPRINT:`n"
            . fingerprint
            . "`n`nThe pairing code is now on your clipboard."
            . "`nThis program will clear the CURRENT clipboard copy after 60 seconds if it is still unchanged."
            . "`n`nIMPORTANT:"
            . "`n- Give the pairing code only to " peer "."
            . "`n- If you want Discord itself to never possess the decryption key, exchange this code outside Discord."
            . "`n- Compare the fingerprint on both computers after import."
            . "`n- Windows Clipboard History or third-party clipboard managers may retain copied secrets.",
            "Pair Created"
        )

        this.SetStatus("Pair created for " peer ".")
    }

    static ImportPair(*) {
        peerResult := InputBox(
            "Enter the local ID of the person who created the pairing code.",
            "Import Private Pair",
            "w520 h150"
        )

        if peerResult.Result != "OK"
            return

        peer := Trim(peerResult.Value)

        if !RegExMatch(peer, "^[A-Za-z0-9_-]{1,24}$") {
            MsgBox("Invalid peer ID.", "Import Pair", "Iconx")
            return
        }

        if peer = this.UserId {
            MsgBox("The peer ID cannot be your own local ID.", "Import Pair", "Iconx")
            return
        }

        codeResult := InputBox(
            "Paste the AHKPAIR2 pairing code.",
            "Import Pairing Code",
            "w690 h180"
        )

        if codeResult.Result != "OK"
            return

        code := Trim(codeResult.Value)

        if SubStr(code, 1, 9) != "AHKPAIR2:" {
            MsgBox("That is not an AHKPAIR2 pairing code.", "Import Pair", "Iconx")
            return
        }

        try {
            packet := Crypto.Base64Decode(SubStr(code, 10))
        } catch as err {
            MsgBox("Invalid pairing code.`n`n" err.Message, "Import Pair", "Iconx")
            return
        }

        if packet.Size != 48 {
            MsgBox("Invalid pairing packet length.", "Import Pair", "Iconx")
            return
        }

        if this.Contacts.Has(peer) {
            answer := MsgBox(
                "A pair with " peer " already exists.`n`nReplace it?",
                "Replace Existing Pair?",
                "YesNo Icon!"
            )

            if answer != "Yes"
                return
        }

        this.SaveContact(peer, packet)

        fingerprint := Crypto.Fingerprint(packet)

        MsgBox(
            "Pair imported for " peer ".`n`n"
            . "PAIR FINGERPRINT:`n"
            . fingerprint
            . "`n`nCompare this fingerprint with the one shown on the creator's computer."
            . "`nIf they differ, do not use the pairing.",
            "Pair Imported"
        )

        this.SetStatus("Pair imported for " peer ".")
    }

    static RemoveSelectedPair(*) {
        peer := this.GetSelectedPeer(false)

        if peer = ""
            return

        answer := MsgBox(
            "Remove the private pair with " peer "?`n`n"
            . "Messages encrypted with that key will no longer be decryptable on this computer.",
            "Remove Pair?",
            "YesNo Icon!"
        )

        if answer != "Yes"
            return

        this.RemoveContact(peer)
        this.SetStatus("Removed pair with " peer ".")
    }

    static EncryptAndCopy(*) {
        peer := this.GetSelectedPeer()

        if peer = ""
            return

        plaintext := this.MessageCtrl.Value

        if plaintext = "" {
            MsgBox("Type a message first.", "Nothing to Encrypt", "Icon!")
            return
        }

        ; Discord's normal message limit is finite. Keep the envelope comfortably sized.
        if StrLen(plaintext) > 1100 {
            MsgBox(
                "Keep this prototype's plaintext at 1,100 characters or fewer per message.",
                "Message Too Long",
                "Icon!"
            )
            return
        }

        try {
            ciphertext := this.BuildEnvelope(peer, plaintext)
            A_Clipboard := ciphertext
            this.LastClipboardCiphertext := ciphertext

            this.OutputCtrl.Value :=
                "Encrypted successfully for: " peer
                . "`r`n`r`nCiphertext copied to clipboard."
                . "`r`nPaste it manually into Discord, a DM, email, or another text transport."
                . "`r`n`r`nThe plaintext was not sent anywhere by this program."

            this.SetStatus("Encrypted for " peer " and copied to clipboard.")
        } catch as err {
            MsgBox(
                "Encryption failed.`n`n" err.Message,
                "Encryption Error",
                "Iconx"
            )
        }
    }

    static BuildEnvelope(peer, plaintext) {
        contact := this.Contacts[peer]

        msgId := Crypto.Base64Encode(Crypto.RandomBytes(16))
        nonce := Crypto.RandomBytes(12)
        timestamp := A_NowUTC

        conversation := contact["Conversation"]

        aadText := this.Protocol
            . "|" conversation
            . "|" this.UserId
            . "|" peer
            . "|" timestamp
            . "|" msgId

        directionInfo := this.Protocol "|" this.UserId "|" peer

        key := Crypto.HkdfSha256(
            contact["Master"],
            contact["ConversationRaw"],
            Crypto.Utf8Bytes(directionInfo),
            32
        )

        encrypted := Crypto.Aes256GcmEncrypt(
            key,
            nonce,
            Crypto.Utf8Bytes(plaintext),
            Crypto.Utf8Bytes(aadText)
        )

        return aadText
            . "|" Crypto.Base64Encode(nonce)
            . "|" Crypto.Base64Encode(encrypted["Cipher"])
            . "|" Crypto.Base64Encode(encrypted["Tag"])
    }

    static DecryptClipboard(*) {
        text := Trim(A_Clipboard)

        if text = "" {
            MsgBox("The clipboard is empty.", "Decrypt Clipboard", "Icon!")
            return
        }

        if SubStr(text, 1, StrLen(this.Protocol) + 1) != this.Protocol "|" {
            MsgBox(
                "The clipboard does not contain an " this.Protocol " message.",
                "Not an Encrypted Message",
                "Icon!"
            )
            return
        }

        this.TryDecryptEnvelope(text, true)
    }

    static TryDecryptEnvelope(content, showErrors := false) {
        parts := StrSplit(content, "|")

        ; protocol | conversation | from | to | timestamp | msgid | nonce | ciphertext | tag
        if parts.Length != 9 {
            if showErrors
                MsgBox("Malformed encrypted envelope.", "Decrypt Failed", "Iconx")
            return false
        }

        if parts[1] != this.Protocol
            return false

        conversation := parts[2]
        fromId := parts[3]
        toId := parts[4]
        timestamp := parts[5]
        msgId := parts[6]
        nonceB64 := parts[7]
        cipherB64 := parts[8]
        tagB64 := parts[9]

        if toId != this.UserId {
            if showErrors {
                MsgBox(
                    "This message is addressed to '" toId "', not '" this.UserId "'.`n`n"
                    . "If another pair encrypted it, this computer should not be able to decrypt it.",
                    "Not Addressed To You",
                    "Icon!"
                )
            }
            return false
        }

        if !RegExMatch(fromId, "^[A-Za-z0-9_-]{1,24}$") {
            if showErrors
                MsgBox("Invalid sender field.", "Decrypt Failed", "Iconx")
            return false
        }

        if !this.Contacts.Has(fromId) {
            if showErrors {
                MsgBox(
                    "No private pair exists with sender '" fromId "'.`n`n"
                    . "That is expected if this ciphertext belongs to somebody else's conversation.",
                    "No Matching Pair",
                    "Icon!"
                )
            }
            return false
        }

        contact := this.Contacts[fromId]

        if !Crypto.ConstantTimeStringEqual(conversation, contact["Conversation"]) {
            if showErrors {
                MsgBox(
                    "The conversation ID does not match your pair with " fromId ".",
                    "Wrong Pair",
                    "Iconx"
                )
            }
            return false
        }

        ; Conservative input limits before decoding arbitrary clipboard data.
        if StrLen(msgId) > 80
            return false
        if StrLen(nonceB64) > 80
            return false
        if StrLen(tagB64) > 80
            return false
        if StrLen(cipherB64) > 2200
            return false

        aadText := this.Protocol
            . "|" conversation
            . "|" fromId
            . "|" toId
            . "|" timestamp
            . "|" msgId

        try {
            nonce := Crypto.Base64Decode(nonceB64)
            cipher := Crypto.Base64Decode(cipherB64)
            tag := Crypto.Base64Decode(tagB64)

            if nonce.Size != 12
                throw Error("Invalid nonce length.")

            if tag.Size != 16
                throw Error("Invalid authentication tag length.")

            directionInfo := this.Protocol "|" fromId "|" toId

            key := Crypto.HkdfSha256(
                contact["Master"],
                contact["ConversationRaw"],
                Crypto.Utf8Bytes(directionInfo),
                32
            )

            plain := Crypto.Aes256GcmDecrypt(
                key,
                nonce,
                cipher,
                Crypto.Utf8Bytes(aadText),
                tag
            )

            plaintext := Crypto.Utf8String(plain)

            displayTime := timestamp
            if RegExMatch(timestamp, "^\d{14}$") {
                try displayTime := FormatTime(timestamp, "yyyy-MM-dd HH:mm:ss") " UTC"
            }

            this.OutputCtrl.Value :=
                "FROM: " fromId
                . "`r`nTO: " toId
                . "`r`nTIME: " displayTime
                . "`r`n`r`n"
                . plaintext

            this.SetStatus("Authenticated and decrypted message from " fromId ".")
            return true

        } catch as err {
            if showErrors {
                MsgBox(
                    "The message could not be authenticated/decrypted.`n`n"
                    . "Possible reasons:"
                    . "`n- wrong pairing key"
                    . "`n- ciphertext was modified"
                    . "`n- message is incomplete/corrupted"
                    . "`n`nNo plaintext was accepted.",
                    "Authentication Failed",
                    "Iconx"
                )
            }
            return false
        }
    }

    static ClipboardChanged(dataType) {
        if dataType != 1
            return

        if !this.AutoDecryptCtrl || this.AutoDecryptCtrl.Value != 1
            return

        text := Trim(A_Clipboard)

        if text = ""
            return

        if text = this.LastClipboardCiphertext
            return

        if SubStr(text, 1, StrLen(this.Protocol) + 1) != this.Protocol "|"
            return

        this.TryDecryptEnvelope(text, false)
    }

    static ClearPlaintext(*) {
        this.MessageCtrl.Value := ""
        this.OutputCtrl.Value := ""
        this.SetStatus("Plaintext fields cleared.")
    }

    static ClearClipboardIfMatch(secretText, *) {
        try {
            if A_Clipboard = secretText
                A_Clipboard := ""
        }
    }

    static GetSelectedPeer(showWarning := true) {
        if !this.PeerCtrl || this.PeerCtrl.Text = "" {
            if showWarning {
                MsgBox(
                    "Create or import a private pair first.",
                    "No Pair Selected",
                    "Icon!"
                )
            }
            return ""
        }

        peer := this.PeerCtrl.Text

        if !this.Contacts.Has(peer) {
            if showWarning
                MsgBox("No key exists for that peer.", "Missing Pair", "Iconx")
            return ""
        }

        return peer
    }

    static SetStatus(text) {
        if this.StatusCtrl
            this.StatusCtrl.Text := text
    }

    static ArrayContains(arr, value) {
        for _, item in arr {
            if item = value
                return true
        }
        return false
    }

    static Join(arr, delimiter) {
        out := ""

        for index, item in arr {
            if index > 1
                out .= delimiter

            out .= item
        }

        return out
    }
}

class Crypto {
    static BCRYPT_USE_SYSTEM_PREFERRED_RNG := 0x00000002
    static BCRYPT_ALG_HANDLE_HMAC_FLAG := 0x00000008
    static CRYPTPROTECT_UI_FORBIDDEN := 0x00000001

    static SelfTest() {
        random := this.RandomBytes(32)

        encoded := this.Base64Encode(random)
        decoded := this.Base64Decode(encoded)

        if !this.ConstantTimeBufferEqual(random, decoded)
            throw Error("Base64 round-trip test failed.")

        salt := this.RandomBytes(16)
        info := this.Utf8Bytes("AHKCLIP2|SELFTEST|A->B")
        key := this.HkdfSha256(random, salt, info, 32)

        nonce := this.RandomBytes(12)
        aad := this.Utf8Bytes("AHKCLIP2|SELFTEST|AAD")
        original := this.Utf8Bytes("AHK secure clipboard messenger self-test")

        encrypted := this.Aes256GcmEncrypt(
            key,
            nonce,
            original,
            aad
        )

        recovered := this.Aes256GcmDecrypt(
            key,
            nonce,
            encrypted["Cipher"],
            aad,
            encrypted["Tag"]
        )

        if !this.ConstantTimeBufferEqual(original, recovered)
            throw Error("AES-256-GCM round-trip test failed.")

        ; Confirm tampering is rejected.
        if encrypted["Cipher"].Size {
            tampered := this.Slice(
                encrypted["Cipher"],
                0,
                encrypted["Cipher"].Size
            )

            first := NumGet(tampered, 0, "UChar")
            NumPut("UChar", first ^ 0x01, tampered, 0)

            acceptedTamperedData := false

            try {
                this.Aes256GcmDecrypt(
                    key,
                    nonce,
                    tampered,
                    aad,
                    encrypted["Tag"]
                )

                acceptedTamperedData := true
            }

            if acceptedTamperedData
                throw Error("AES-GCM tamper-rejection self-test failed.")
        }
    }

    static RandomBytes(count) {
        if count < 1
            throw Error("Random byte count must be positive.")

        buf := Buffer(count, 0)

        status := DllCall(
            "bcrypt\BCryptGenRandom",
            "Ptr", 0,
            "Ptr", buf.Ptr,
            "UInt", buf.Size,
            "UInt", this.BCRYPT_USE_SYSTEM_PREFERRED_RNG,
            "Int"
        )

        if status != 0 {
            throw Error(
                "BCryptGenRandom failed. NTSTATUS="
                . Format("0x{:08X}", status & 0xFFFFFFFF)
            )
        }

        return buf
    }

    static HkdfSha256(ikm, salt, info, outputLength := 32) {
        if outputLength < 1 || outputLength > 32
            throw Error("This HKDF helper supports output lengths from 1 to 32 bytes.")

        ; RFC 5869 HKDF-Extract:
        ; PRK = HMAC-SHA256(salt, IKM)
        prk := this.HmacSha256(salt, ikm)

        ; RFC 5869 HKDF-Expand:
        ; T(1) = HMAC-SHA256(PRK, info || 0x01)
        counter := Buffer(1, 0)
        NumPut("UChar", 1, counter, 0)

        t1 := this.HmacSha256(
            prk,
            this.Concat([info, counter])
        )

        return this.Slice(t1, 0, outputLength)
    }

    static HmacSha256(key, data) {
        hAlg := 0
        hHash := 0

        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", this.BCRYPT_ALG_HANDLE_HMAC_FLAG,
            "Int"
        )

        if status != 0
            throw Error("Could not open HMAC-SHA256 provider.")

        try {
            objectLength := this.BCryptGetUIntProperty(hAlg, "ObjectLength")
            hashLength := this.BCryptGetUIntProperty(hAlg, "HashDigestLength")

            hashObject := Buffer(objectLength, 0)
            digest := Buffer(hashLength, 0)

            status := DllCall(
                "bcrypt\BCryptCreateHash",
                "Ptr", hAlg,
                "Ptr*", &hHash,
                "Ptr", hashObject.Ptr,
                "UInt", hashObject.Size,
                "Ptr", key.Ptr,
                "UInt", key.Size,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptCreateHash(HMAC-SHA256) failed.")

            status := DllCall(
                "bcrypt\BCryptHashData",
                "Ptr", hHash,
                "Ptr", data.Ptr,
                "UInt", data.Size,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptHashData(HMAC-SHA256) failed.")

            status := DllCall(
                "bcrypt\BCryptFinishHash",
                "Ptr", hHash,
                "Ptr", digest.Ptr,
                "UInt", digest.Size,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptFinishHash(HMAC-SHA256) failed.")

            return digest

        } finally {
            if hHash
                DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)

            if hAlg
                DllCall(
                    "bcrypt\BCryptCloseAlgorithmProvider",
                    "Ptr", hAlg,
                    "UInt", 0
                )
        }
    }

    static Sha256(data) {
        hAlg := 0
        hHash := 0

        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "SHA256",
            "Ptr", 0,
            "UInt", 0,
            "Int"
        )

        if status != 0
            throw Error("Could not open SHA-256 provider.")

        try {
            objectLength := this.BCryptGetUIntProperty(hAlg, "ObjectLength")
            hashLength := this.BCryptGetUIntProperty(hAlg, "HashDigestLength")

            hashObject := Buffer(objectLength, 0)
            digest := Buffer(hashLength, 0)

            status := DllCall(
                "bcrypt\BCryptCreateHash",
                "Ptr", hAlg,
                "Ptr*", &hHash,
                "Ptr", hashObject.Ptr,
                "UInt", hashObject.Size,
                "Ptr", 0,
                "UInt", 0,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptCreateHash(SHA-256) failed.")

            status := DllCall(
                "bcrypt\BCryptHashData",
                "Ptr", hHash,
                "Ptr", data.Ptr,
                "UInt", data.Size,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptHashData(SHA-256) failed.")

            status := DllCall(
                "bcrypt\BCryptFinishHash",
                "Ptr", hHash,
                "Ptr", digest.Ptr,
                "UInt", digest.Size,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptFinishHash(SHA-256) failed.")

            return digest

        } finally {
            if hHash
                DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)

            if hAlg
                DllCall(
                    "bcrypt\BCryptCloseAlgorithmProvider",
                    "Ptr", hAlg,
                    "UInt", 0
                )
        }
    }

    static Fingerprint(data) {
        hash := this.Sha256(data)
        out := ""

        Loop 8 {
            if A_Index > 1
                out .= ":"

            out .= Format(
                "{:02X}",
                NumGet(hash, A_Index - 1, "UChar")
            )
        }

        return out
    }

    static Aes256GcmEncrypt(key, nonce, plaintext, aad) {
        if key.Size != 32
            throw Error("AES-256 requires a 32-byte key.")

        if nonce.Size != 12
            throw Error("AES-GCM nonce must be 12 bytes in this protocol.")

        hAlg := 0
        hKey := 0

        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "AES",
            "Ptr", 0,
            "UInt", 0,
            "Int"
        )

        if status != 0
            throw Error("Could not open the AES provider.")

        try {
            this.SetAesGcmMode(hAlg)

            objectLength := this.BCryptGetUIntProperty(hAlg, "ObjectLength")
            keyObject := Buffer(objectLength, 0)

            status := DllCall(
                "bcrypt\BCryptGenerateSymmetricKey",
                "Ptr", hAlg,
                "Ptr*", &hKey,
                "Ptr", keyObject.Ptr,
                "UInt", keyObject.Size,
                "Ptr", key.Ptr,
                "UInt", key.Size,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptGenerateSymmetricKey(AES) failed.")

            tag := Buffer(16, 0)
            authInfo := this.MakeAuthInfo(nonce, aad, tag)

            cipher := Buffer(plaintext.Size, 0)
            written := 0

            status := DllCall(
                "bcrypt\BCryptEncrypt",
                "Ptr", hKey,
                "Ptr", plaintext.Ptr,
                "UInt", plaintext.Size,
                "Ptr", authInfo.Ptr,
                "Ptr", 0,
                "UInt", 0,
                "Ptr", cipher.Ptr,
                "UInt", cipher.Size,
                "UInt*", &written,
                "UInt", 0,
                "Int"
            )

            if status != 0 {
                throw Error(
                    "BCryptEncrypt(AES-256-GCM) failed. NTSTATUS="
                    . Format("0x{:08X}", status & 0xFFFFFFFF)
                )
            }

            if written != cipher.Size
                cipher := this.Slice(cipher, 0, written)

            return Map(
                "Cipher", cipher,
                "Tag", tag
            )

        } finally {
            if hKey
                DllCall("bcrypt\BCryptDestroyKey", "Ptr", hKey)

            if hAlg
                DllCall(
                    "bcrypt\BCryptCloseAlgorithmProvider",
                    "Ptr", hAlg,
                    "UInt", 0
                )
        }
    }

    static Aes256GcmDecrypt(key, nonce, cipher, aad, tag) {
        if key.Size != 32
            throw Error("AES-256 requires a 32-byte key.")

        if nonce.Size != 12
            throw Error("Invalid AES-GCM nonce length.")

        if tag.Size != 16
            throw Error("Invalid AES-GCM authentication tag length.")

        hAlg := 0
        hKey := 0

        status := DllCall(
            "bcrypt\BCryptOpenAlgorithmProvider",
            "Ptr*", &hAlg,
            "WStr", "AES",
            "Ptr", 0,
            "UInt", 0,
            "Int"
        )

        if status != 0
            throw Error("Could not open the AES provider.")

        try {
            this.SetAesGcmMode(hAlg)

            objectLength := this.BCryptGetUIntProperty(hAlg, "ObjectLength")
            keyObject := Buffer(objectLength, 0)

            status := DllCall(
                "bcrypt\BCryptGenerateSymmetricKey",
                "Ptr", hAlg,
                "Ptr*", &hKey,
                "Ptr", keyObject.Ptr,
                "UInt", keyObject.Size,
                "Ptr", key.Ptr,
                "UInt", key.Size,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("BCryptGenerateSymmetricKey(AES) failed.")

            authInfo := this.MakeAuthInfo(nonce, aad, tag)

            plain := Buffer(cipher.Size, 0)
            written := 0

            status := DllCall(
                "bcrypt\BCryptDecrypt",
                "Ptr", hKey,
                "Ptr", cipher.Ptr,
                "UInt", cipher.Size,
                "Ptr", authInfo.Ptr,
                "Ptr", 0,
                "UInt", 0,
                "Ptr", plain.Ptr,
                "UInt", plain.Size,
                "UInt*", &written,
                "UInt", 0,
                "Int"
            )

            if status != 0
                throw Error("Ciphertext authentication failed.")

            if written != plain.Size
                plain := this.Slice(plain, 0, written)

            return plain

        } finally {
            if hKey
                DllCall("bcrypt\BCryptDestroyKey", "Ptr", hKey)

            if hAlg
                DllCall(
                    "bcrypt\BCryptCloseAlgorithmProvider",
                    "Ptr", hAlg,
                    "UInt", 0
                )
        }
    }

    static SetAesGcmMode(hAlg) {
        modeText := "ChainingModeGCM"
        modeBuf := Buffer((StrLen(modeText) + 1) * 2, 0)
        StrPut(modeText, modeBuf, "UTF-16")

        status := DllCall(
            "bcrypt\BCryptSetProperty",
            "Ptr", hAlg,
            "WStr", "ChainingMode",
            "Ptr", modeBuf.Ptr,
            "UInt", modeBuf.Size,
            "UInt", 0,
            "Int"
        )

        if status != 0
            throw Error("Could not enable AES-GCM mode.")
    }

    static MakeAuthInfo(nonce, aad, tag) {
        ; BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO layout for 64-bit Windows.
        ; Struct size = 88 bytes.

        info := Buffer(88, 0)

        NumPut("UInt", 88, info, 0)
        NumPut("UInt", 1, info, 4)

        NumPut("Ptr", nonce.Ptr, info, 8)
        NumPut("UInt", nonce.Size, info, 16)

        if aad.Size {
            NumPut("Ptr", aad.Ptr, info, 24)
            NumPut("UInt", aad.Size, info, 32)
        }

        NumPut("Ptr", tag.Ptr, info, 40)
        NumPut("UInt", tag.Size, info, 48)

        NumPut("Ptr", 0, info, 56)
        NumPut("UInt", 0, info, 64)
        NumPut("UInt", 0, info, 68)
        NumPut("UInt64", 0, info, 72)
        NumPut("UInt", 0, info, 80)

        return info
    }

    static BCryptGetUIntProperty(handle, propertyName) {
        out := Buffer(4, 0)
        written := 0

        status := DllCall(
            "bcrypt\BCryptGetProperty",
            "Ptr", handle,
            "WStr", propertyName,
            "Ptr", out.Ptr,
            "UInt", out.Size,
            "UInt*", &written,
            "UInt", 0,
            "Int"
        )

        if status != 0
            throw Error("BCryptGetProperty(" propertyName ") failed.")

        return NumGet(out, 0, "UInt")
    }

    static DpapiProtectToBase64(data) {
        inBlob := this.MakeDataBlob(data)
        outBlob := Buffer(16, 0)

        ok := DllCall(
            "Crypt32\CryptProtectData",
            "Ptr", inBlob.Ptr,
            "WStr", "AHK Secure Clipboard Messenger",
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", this.CRYPTPROTECT_UI_FORBIDDEN,
            "Ptr", outBlob.Ptr,
            "Int"
        )

        if !ok {
            throw Error(
                "CryptProtectData failed. Windows error="
                . A_LastError
            )
        }

        outLen := NumGet(outBlob, 0, "UInt")
        outPtr := NumGet(outBlob, 8, "Ptr")

        if !outPtr || !outLen
            throw Error("CryptProtectData returned an empty result.")

        try {
            protected := Buffer(outLen, 0)

            DllCall(
                "ntdll\RtlMoveMemory",
                "Ptr", protected.Ptr,
                "Ptr", outPtr,
                "UPtr", outLen
            )

        } finally {
            DllCall("Kernel32\LocalFree", "Ptr", outPtr)
        }

        return this.Base64Encode(protected)
    }

    static DpapiUnprotectFromBase64(encoded) {
        protected := this.Base64Decode(encoded)
        inBlob := this.MakeDataBlob(protected)
        outBlob := Buffer(16, 0)

        ok := DllCall(
            "Crypt32\CryptUnprotectData",
            "Ptr", inBlob.Ptr,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", this.CRYPTPROTECT_UI_FORBIDDEN,
            "Ptr", outBlob.Ptr,
            "Int"
        )

        if !ok {
            throw Error(
                "CryptUnprotectData failed. Windows error="
                . A_LastError
            )
        }

        outLen := NumGet(outBlob, 0, "UInt")
        outPtr := NumGet(outBlob, 8, "Ptr")

        if !outPtr
            throw Error("CryptUnprotectData returned an empty pointer.")

        try {
            plain := Buffer(outLen, 0)

            if outLen {
                DllCall(
                    "ntdll\RtlMoveMemory",
                    "Ptr", plain.Ptr,
                    "Ptr", outPtr,
                    "UPtr", outLen
                )
            }

        } finally {
            DllCall("Kernel32\LocalFree", "Ptr", outPtr)
        }

        return plain
    }

    static MakeDataBlob(data) {
        ; DATA_BLOB layout on 64-bit Windows:
        ; DWORD cbData at offset 0
        ; pointer pbData at offset 8

        blob := Buffer(16, 0)
        NumPut("UInt", data.Size, blob, 0)
        NumPut("Ptr", data.Ptr, blob, 8)

        return blob
    }

    static Base64Encode(data) {
        CRYPT_STRING_BASE64 := 0x00000001
        CRYPT_STRING_NOCRLF := 0x40000000
        flags := CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF

        chars := 0

        ok := DllCall(
            "Crypt32\CryptBinaryToStringW",
            "Ptr", data.Ptr,
            "UInt", data.Size,
            "UInt", flags,
            "Ptr", 0,
            "UInt*", &chars,
            "Int"
        )

        if !ok
            throw Error("CryptBinaryToStringW size query failed.")

        out := Buffer(chars * 2, 0)

        ok := DllCall(
            "Crypt32\CryptBinaryToStringW",
            "Ptr", data.Ptr,
            "UInt", data.Size,
            "UInt", flags,
            "Ptr", out.Ptr,
            "UInt*", &chars,
            "Int"
        )

        if !ok
            throw Error("CryptBinaryToStringW failed.")

        return StrGet(out.Ptr, "UTF-16")
    }

    static Base64Decode(text) {
        CRYPT_STRING_BASE64 := 0x00000001
        bytes := 0

        ok := DllCall(
            "Crypt32\CryptStringToBinaryW",
            "WStr", text,
            "UInt", 0,
            "UInt", CRYPT_STRING_BASE64,
            "Ptr", 0,
            "UInt*", &bytes,
            "Ptr", 0,
            "Ptr", 0,
            "Int"
        )

        if !ok
            throw Error("Invalid Base64.")

        out := Buffer(bytes, 0)

        ok := DllCall(
            "Crypt32\CryptStringToBinaryW",
            "WStr", text,
            "UInt", 0,
            "UInt", CRYPT_STRING_BASE64,
            "Ptr", out.Ptr,
            "UInt*", &bytes,
            "Ptr", 0,
            "Ptr", 0,
            "Int"
        )

        if !ok
            throw Error("Base64 decoding failed.")

        if bytes != out.Size
            out := this.Slice(out, 0, bytes)

        return out
    }

    static Utf8Bytes(text) {
        requiredIncludingNull := StrPut(text, "UTF-8")
        temp := Buffer(requiredIncludingNull, 0)
        StrPut(text, temp, "UTF-8")

        actual := requiredIncludingNull - 1

        if actual <= 0
            return Buffer(0)

        return this.Slice(temp, 0, actual)
    }

    static Utf8String(data) {
        if data.Size = 0
            return ""

        return StrGet(data.Ptr, data.Size, "UTF-8")
    }

    static Slice(source, offset, length) {
        if offset < 0 || length < 0 || offset + length > source.Size
            throw Error("Invalid buffer slice.")

        out := Buffer(length, 0)

        if length {
            DllCall(
                "ntdll\RtlMoveMemory",
                "Ptr", out.Ptr,
                "Ptr", source.Ptr + offset,
                "UPtr", length
            )
        }

        return out
    }

    static Concat(buffers) {
        total := 0

        for _, buf in buffers
            total += buf.Size

        out := Buffer(total, 0)
        offset := 0

        for _, buf in buffers {
            if buf.Size {
                DllCall(
                    "ntdll\RtlMoveMemory",
                    "Ptr", out.Ptr + offset,
                    "Ptr", buf.Ptr,
                    "UPtr", buf.Size
                )
            }

            offset += buf.Size
        }

        return out
    }

    static ConstantTimeBufferEqual(a, b) {
        maxLen := Max(a.Size, b.Size)
        diff := a.Size ^ b.Size

        Loop maxLen {
            av := A_Index <= a.Size
                ? NumGet(a, A_Index - 1, "UChar")
                : 0

            bv := A_Index <= b.Size
                ? NumGet(b, A_Index - 1, "UChar")
                : 0

            diff |= av ^ bv
        }

        return diff = 0
    }

    static ConstantTimeStringEqual(a, b) {
        return this.ConstantTimeBufferEqual(
            this.Utf8Bytes(a),
            this.Utf8Bytes(b)
        )
    }
}

; ======================================================================================================================
; HOTKEYS
; ======================================================================================================================

^+e::SecureClipboardMessenger.EncryptAndCopy()
^+d::SecureClipboardMessenger.DecryptClipboard()
+Esc::ExitApp()

; ======================================================================================================================
; START
; ======================================================================================================================

SecureClipboardMessenger.Start()
