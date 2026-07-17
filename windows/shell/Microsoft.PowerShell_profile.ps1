# FriendlyTerminal shell integration for PowerShell.
# Emits OSC 133 markers so the app can split output into per-command blocks
# and read the working directory. See docs/behavior-spec/shell-integration.md.

$global:__ftEsc = [char]27

function global:__ftOsc($body) {
    [Console]::Write("$global:__ftEsc]$body$global:__ftEsc\")
}

$global:__ftOriginalPrompt = $function:prompt
$global:__ftRan = $false

function global:prompt {
    # $? must be read first: it reflects the user's command, and any statement in
    # this function would overwrite it. Cmdlet failures don't set $LASTEXITCODE,
    # so a false $? with no native exit code is reported as exit 1.
    $ok = $?
    $code = $global:LASTEXITCODE
    if ($global:__ftRan) {
        $exit = if ($ok) { 0 } elseif ($code) { $code } else { 1 }
        __ftOsc "133;D;$exit"
    }
    __ftOsc "133;A"
    __ftOsc "9;9;$((Get-Location).Path)"
    $text = & $global:__ftOriginalPrompt
    __ftOsc "133;B"
    $global:__ftRan = $false
    # Restore the user's exit code so the integration stays transparent to scripts
    # and prompts that read $LASTEXITCODE.
    $global:LASTEXITCODE = $code
    return $text
}

if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        # Report the command line (base64, OSC 633;E) so the app can label the block.
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($line) {
            $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($line))
            __ftOsc "633;E;$b64"
        }
        __ftOsc "133;C"
        $global:__ftRan = $true
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}
