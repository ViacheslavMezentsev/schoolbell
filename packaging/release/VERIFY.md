# Проверка выпуска / Verify a release

Скачайте SHA256SUMS, SHA256SUMS.sig, signing-key.pub, allowed-signers и перечисленные в суммах assets в одну папку. Подпись создаётся владельцем после сборки; unsigned Actions-архив ещё не является подписанным выпуском.
Download the checksum list, signature, public key, allowed-signers and listed assets into one folder. Actions output is unsigned until the owner signs it.

Доверенный отпечаток / Trusted fingerprint:
`SHA256:ekq3AjehBO2o+e63uOrpGLLKjmHc7kjnPZhIkgzLT88`

Сверьте его с инструкцией в доверенной копии репозитория, а не только с файлами из того же скачивания. / Compare against a trusted repository copy, not only files from the same download.

## Windows PowerShell 7

```powershell
ssh-keygen -lf .\signing-key.pub
((Get-Content allowed-signers -Raw).Trim() -split ' ',3)[2] | ssh-keygen -lf -
cmd /c 'ssh-keygen -Y verify -f allowed-signers -I schoolbell-release -n schoolbell-release -s SHA256SUMS.sig < SHA256SUMS'
if ($LASTEXITCODE) { throw 'Signature verification failed' }
Get-Content SHA256SUMS | ForEach-Object {
    if ($_ -notmatch '^([0-9a-f]{64})  ([A-Za-z0-9][A-Za-z0-9._-]*)$') { throw 'Invalid checksum entry' }
    $expectedHash = $Matches[1]
    $assetName = $Matches[2]
    if ((Get-FileHash -LiteralPath $assetName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) { throw "Checksum mismatch: $assetName" }
}
```

У обоих файлов ключей должен быть указанный отпечаток; при несовпадении остановитесь до команды verify. Нужен ssh-keygen с поддержкой `-Y verify` (OpenSSH 8.2+); если команда не поддерживается, обновите OpenSSH, а не пропускайте проверку. / Both key files must have the fingerprint above; stop if either differs. OpenSSH 8.2+ with `-Y verify` is required; update it rather than skipping verification.

## Linux / WSL

```sh
ssh-keygen -lf signing-key.pub
awk '{print $3, $4}' allowed-signers | ssh-keygen -lf -
ssh-keygen -Y verify -f allowed-signers -I schoolbell-release -n schoolbell-release -s SHA256SUMS.sig < SHA256SUMS && sha256sum -c SHA256SUMS
```

Успех подписи без проверки всех файлов недостаточен. Подпись сумм не является Authenticode EXE и не подтверждает аппаратную приёмку. Не изменяйте окончания строк SHA256SUMS после подписи. / A valid signature alone is insufficient: every asset hash must match. This is not EXE Authenticode or hardware acceptance. Keep checksum bytes unchanged.
